import 'dart:async';
import 'dart:io';

import 'package:asc_common/asc_common.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../configs/app_config.dart';
import '../models/data_models/gift_event.dart';
import '../models/data_models/gift_record.dart';
import '../models/ui_models/gift_status.dart';
import '../repository/gift_repository.dart';
import '../services/application/api_client.dart';
import 'event_controller.dart';
import 'gift_controller.dart';
import 'settings_controller.dart';

enum RecState { idle, starting, listening, denied, stopping, error }

/// Phiên ghi âm liên tục (S05). Mỗi lượt nói = 1 phong bì:
/// cắt segment (im lặng / bấm mic) -> tạo bản ghi `processing` ngay -> upload
/// nền qua backend (STT -> LLM -> validate) -> cập nhật thành confirmed /
/// pending_review / failed. Mic chỉ chạy khi app foreground (không ghi nền).
class RecordingController extends GetxController with WidgetsBindingObserver {
  RecordingController(
    this._api,
    this._repo,
    this._events,
    this._gifts,
    this._settings,
  );

  final ApiClient _api;
  final GiftRepository _repo;
  final EventController _events;
  final GiftController _gifts;
  final SettingsController _settings;
  static const _uuid = Uuid();
  static final AscLogger _log = AscLogger();

  final AudioRecorder _rec = AudioRecorder();

  final Rx<RecState> state = RecState.idle.obs;
  final RxList<GiftRecord> items = <GiftRecord>[].obs;
  final RxDouble level = 0.0.obs; // 0..1 cho animation mic
  final RxnString banner = RxnString(); // X05 lỗi mạng/quota
  final RxBool speaking = false.obs;

  /// Nhóm khách áp cho các phong bì của phiên (đổi được giữa chừng).
  final RxString side = GiftSide.mine.obs;

  /// Sự kiện cố định cho cả phiên (BR08): không ghi nhầm khi đổi event.
  GiftEvent? _event;
  GiftEvent? get event => _event;

  StreamSubscription<Amplitude>? _ampSub;
  String? _segPath;
  DateTime _segStart = DateTime.now();
  DateTime _lastVoice = DateTime.now();
  bool _hadSpeech = false;
  bool _cutting = false;
  bool _active = false;

  // Hàng đợi upload tuần tự; giữ file để thử lại cùng request_id.
  Future<void> _queue = Future.value();
  final Map<String, _Pending> _audio = {};
  int _inFlight = 0;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _teardown();
    _rec.dispose();
    for (final p in _audio.values) {
      _deleteFile(p.path);
    }
    super.onClose();
  }

  /// App xuống nền / có cuộc gọi: dừng mic an toàn, không mất dữ liệu.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive) {
      if (_active) stopSession(auto: true);
    }
  }

  // ------------------------------------------------------------ session

  Future<void> start() async {
    _event = _events.active.value;
    if (_event == null || _event!.isClosed) {
      state.value = RecState.error;
      return;
    }
    state.value = RecState.starting;
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      state.value = RecState.denied; // X04
      return;
    }
    await _beginSegment();
  }

  Future<void> openAppSettingsForMic() => openAppSettings();

  Future<void> _beginSegment() async {
    try {
      final dir = await getTemporaryDirectory();
      _segPath = '${dir.path}/seg_${_uuid.v4()}.m4a';
      await _rec.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 48000,
          noiseSuppress: true,
          echoCancel: true,
        ),
        path: _segPath!,
      );
      _segStart = DateTime.now();
      _lastVoice = _segStart;
      _hadSpeech = false;
      _active = true;
      state.value = RecState.listening;
      await _ampSub?.cancel();
      _ampSub = _rec
          .onAmplitudeChanged(const Duration(milliseconds: 120))
          .listen(_onAmp);
    } catch (e, st) {
      _log.error('begin segment failed', e, st);
      banner.value = 'rec_error_start'.tr;
      state.value = RecState.error;
      _active = false;
    }
  }

  void _onAmp(Amplitude a) {
    if (!_active || _cutting) return;
    final db = a.current; // dBFS, ~ -160..0
    level.value = ((db + 55) / 55).clamp(0.0, 1.0);
    final now = DateTime.now();
    if (db > AppConfig.speechThresholdDb) {
      _hadSpeech = true;
      _lastVoice = now;
      speaking.value = true;
    } else {
      speaking.value = false;
    }
    final elapsed = now.difference(_segStart).inMilliseconds;
    if (_hadSpeech &&
        _settings.autoSilenceCut.value &&
        now.difference(_lastVoice).inMilliseconds >= _settings.silenceMs.value &&
        elapsed >= AppConfig.minSegmentMs) {
      cutSegment();
    } else if (elapsed >= AppConfig.maxSegmentMs) {
      cutSegment();
    }
  }

  /// Chốt phong bì hiện tại (tự động khi im lặng, hoặc người dùng bấm mic).
  Future<void> cutSegment() async {
    if (!_active || _cutting) return;
    _cutting = true;
    try {
      final path = await _rec.stop();
      await _ampSub?.cancel();
      _ampSub = null;
      final durMs = DateTime.now().difference(_segStart).inMilliseconds;
      final usable =
          path != null && _hadSpeech && durMs >= AppConfig.minSegmentMs;
      if (usable) {
        await _submit(path, durMs);
      } else if (path != null) {
        _deleteFile(path); // chỉ có tiếng ồn / quá ngắn
      }
      if (_active) await _beginSegment();
    } catch (e, st) {
      _log.error('cut segment failed', e, st);
    } finally {
      _cutting = false;
    }
  }

  /// Dừng phiên; chờ các lượt đang xử lý rồi trả về.
  Future<void> stopSession({bool auto = false}) async {
    if (state.value == RecState.stopping) return;
    final wasActive = _active;
    state.value = RecState.stopping;
    _active = false;
    try {
      await _ampSub?.cancel();
      _ampSub = null;
      if (wasActive && !_cutting) {
        final path = await _rec.stop();
        final durMs = DateTime.now().difference(_segStart).inMilliseconds;
        if (path != null && _hadSpeech && durMs >= AppConfig.minSegmentMs) {
          await _submit(path, durMs);
        } else if (path != null) {
          _deleteFile(path);
        }
      }
    } catch (e, st) {
      _log.error('stop failed', e, st);
    }
    level.value = 0;
    speaking.value = false;
    // Chờ upload còn dang dở (tối đa 40s) để màn kết quả có số liệu đầy đủ.
    await _queue.timeout(const Duration(seconds: 40), onTimeout: () {});
    state.value = RecState.idle;
  }

  void _teardown() {
    _active = false;
    _ampSub?.cancel();
    _rec.stop().catchError((_) => null);
  }

  // ------------------------------------------------------------- upload

  Future<void> _submit(String path, int durMs) async {
    final ev = _event!;
    final id = _uuid.v4(); // = client_request_id (idempotent)
    var g = GiftRecord(
      id: id,
      eventId: ev.id,
      status: GiftStatus.processing,
      source: GiftSource.voice,
      side: side.value,
    );
    await _repo.save(g, enqueue: false); // chưa đẩy lên server
    items.insert(0, g);
    _audio[id] = _Pending(path, durMs);
    _enqueue(id);
  }

  void _enqueue(String id) {
    _inFlight++;
    _queue = _queue.then((_) => _process(id)).whenComplete(() => _inFlight--);
  }

  Future<void> _process(String id) async {
    final pend = _audio[id];
    if (pend == null) return;
    final idx = items.indexWhere((x) => x.id == id);
    if (idx < 0) return;
    var g = items[idx];
    if (!await AscConnectivity.isOnline()) {
      await _fail(g, 'err_offline'.tr, keepAudio: true);
      banner.value = 'err_offline'.tr;
      return;
    }
    try {
      final r = await _api.uploadVoiceSegment(
        filePath: pend.path,
        eventId: g.eventId,
        requestId: id,
        durationMs: pend.durationMs,
        side: g.side,
      );
      banner.value = null;
      await _apply(g, r);
      _audio.remove(id);
      _deleteFile(pend.path); // mặc định không giữ audio lâu dài
    } on NetworkException {
      await _fail(g, 'err_network'.tr, keepAudio: true);
      banner.value = 'err_network'.tr;
    } on ApiException catch (e) {
      if (e.isQuota) {
        banner.value = 'err_quota'.tr;
        await _fail(g, 'err_quota'.tr, keepAudio: true);
      } else {
        await _fail(g, e.message, keepAudio: e.status >= 500);
        if (e.status < 500) {
          _audio.remove(id);
          _deleteFile(pend.path);
        }
      }
    } catch (e, st) {
      _log.error('process failed', e, st);
      await _fail(g, 'err_generic'.tr, keepAudio: true);
    }
  }

  Future<void> _apply(GiftRecord g, VoiceSegmentResult r) async {
    final name = (r.guestName ?? '').trim();
    final amount = r.amountVnd ?? 0;
    final warnings = [...r.warnings];
    var status = GiftStatus.fromWire(r.state);
    if (r.state == 'failed') status = GiftStatus.failed;

    // Phòng thủ phía client: không bao giờ tự confirm khi mơ hồ (BR04/05/06).
    if (status == GiftStatus.confirmed) {
      final dup = r.duplicateGiftIds.isNotEmpty ||
          warnings.contains('possible_duplicate');
      final bad = name.isEmpty ||
          amount <= 0 ||
          amount > AppConfig.maxAmountVnd ||
          warnings.contains('needs_review');
      if (dup || bad) status = GiftStatus.pendingReview;
    }
    if (status == GiftStatus.pendingReview && amount <= 0) {
      warnings.add('amount_unclear');
    }

    final updated = g.copyWith(
      guestName: name.isEmpty ? '' : name,
      relationship: (r.relationship ?? '').trim().isEmpty
          ? null
          : r.relationship!.trim(),
      amountVnd: amount,
      status: status,
      transcript: r.transcript,
      warnings: warnings,
      errorMessage: status == GiftStatus.failed ? 'err_no_speech'.tr : null,
    );
    // Server đã lưu bản ghi này (idempotent) -> chỉ đánh dấu synced, không
    // cần đẩy lại; local ghi enqueue=false để khỏi PUT trùng.
    await _repo.save(updated, enqueue: false);
    await _repo.markSynced(updated.id, updated.updatedAt);
    _replace(updated);
    await _gifts.reload();
  }

  Future<void> _fail(GiftRecord g, String msg, {bool keepAudio = false}) async {
    final f = g.copyWith(status: GiftStatus.failed, errorMessage: msg);
    await _repo.save(f, enqueue: false);
    _replace(f);
    if (!keepAudio) _audio.remove(g.id);
  }

  void _replace(GiftRecord g) {
    final i = items.indexWhere((x) => x.id == g.id);
    if (i >= 0) items[i] = g;
    items.refresh();
  }

  bool canRetry(GiftRecord g) =>
      g.status == GiftStatus.failed && _audio.containsKey(g.id);

  /// Thử lại với CÙNG request_id -> backend không tạo bản ghi thứ 2.
  Future<void> retry(GiftRecord g) async {
    if (!canRetry(g)) return;
    final p = g.copyWith(status: GiftStatus.processing, errorMessage: null);
    await _repo.save(p, enqueue: false);
    _replace(p);
    _enqueue(g.id);
  }

  // ---------------------------------------------------- list operations

  /// Xác nhận / sửa rồi xác nhận (ReviewSheet).
  Future<void> confirmItem(
    GiftRecord g, {
    required String name,
    required int amount,
    String? relationship,
  }) async {
    await _gifts.confirm(
      g,
      name: name,
      amount: amount,
      relationship: relationship,
    );
    final fresh = await _repo.get(g.id);
    if (fresh != null) _replace(fresh);
  }

  /// BR13: hoàn tác bản ghi vừa thêm (an toàn cả khi sync đang chờ).
  Future<void> undoItem(GiftRecord g) async {
    await _gifts.delete(g.id);
    items.removeWhere((x) => x.id == g.id);
    _audio.remove(g.id);
  }

  // ------------------------------------------------------------ summary

  int get confirmedCount =>
      items.where((x) => x.status == GiftStatus.confirmed).length;
  int get pendingCount =>
      items.where((x) => x.status == GiftStatus.pendingReview).length;
  int get failedCount =>
      items.where((x) => x.status == GiftStatus.failed).length;
  int get processingCount =>
      items.where((x) => x.status == GiftStatus.processing).length;
  int get confirmedTotal => items
      .where((x) => x.status == GiftStatus.confirmed)
      .fold(0, (a, b) => a + b.amountVnd);
  int get inFlight => _inFlight;

  void _deleteFile(String path) {
    try {
      File(path).deleteSync();
    } catch (_) {}
  }
}

class _Pending {
  _Pending(this.path, this.durationMs);
  final String path;
  final int durationMs;
}
