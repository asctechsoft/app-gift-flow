import 'dart:async';

import 'package:asc_common/asc_common.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';

import '../configs/app_config.dart';
import '../models/data_models/gift_event.dart';
import '../models/data_models/gift_record.dart';
import '../models/data_models/parsed_gift.dart';
import '../models/ui_models/gift_status.dart';
import '../repository/gift_repository.dart';
import '../services/application/api_client.dart';
import '../services/application/speech_logic.dart';
import 'event_controller.dart';
import 'gift_controller.dart';
import 'settings_controller.dart';

enum RecState { idle, starting, listening, denied, stopping, error }

/// Phiên ghi nhận bằng giọng nói (S05).
///
/// Luồng: nhận dạng giọng nói TRÊN THIẾT BỊ (chữ hiện ngay khi nói) -> câu hoàn
/// chỉnh -> backend `POST /v1/ai/parse-gift` (GPT, chỉ phân tích) -> business
/// rules -> lưu bản ghi (đã xác nhận / chờ xác nhận) vào DB local + đồng bộ.
/// KHÔNG upload audio. Mic chỉ chạy khi màn ghi âm đang mở.
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

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  String _locale = 'vi_VN';

  final Rx<RecState> state = RecState.idle.obs;
  final RxList<GiftRecord> items = <GiftRecord>[].obs;
  final RxDouble level = 0.0.obs; // 0..1 cho hiệu ứng sóng âm
  final RxnString banner = RxnString();
  final RxBool speaking = false.obs;

  /// Chữ đang nhận dạng (partial) - hiện ngay trên màn ghi âm.
  final RxString liveText = ''.obs;

  /// Dòng trạng thái nhỏ (ngôn ngữ nhận dạng, số lần nghe...) để chẩn đoán.
  final RxString sttInfo = ''.obs;

  /// Nhóm khách áp cho các phong bì của phiên (đổi được giữa chừng).
  final RxString side = GiftSide.mine.obs;

  /// Sự kiện cố định cho cả phiên (BR08): không ghi nhầm khi đổi event.
  GiftEvent? _event;
  GiftEvent? get event => _event;

  late final UtteranceTracker _tracker = UtteranceTracker(
    onLive: (t) => liveText.value = t,
    onUtterance: _submitText,
  );
  final TurnPolicy _policy = TurnPolicy();

  /// Phiên đang mở (màn ghi âm đang hiển thị). Khi false: tuyệt đối không bật mic.
  bool _sessionOpen = false;
  bool _turnHadUtterance = false;
  bool _turnEnding = false;
  Timer? _flushTimer;
  int _generation = 0; // bỏ qua callback của lượt nghe cũ

  // Hàng đợi gọi AI tuần tự (giữ thứ tự, không nhầm transcript giữa các lượt).
  Future<void> _queue = Future.value();
  int _inFlight = 0;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    abort();
    super.onClose();
  }

  /// App xuống nền / có cuộc gọi: tắt mic ngay (không ghi nền), giữ dữ liệu.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive) {
      if (_sessionOpen) _pauseListening();
    }
  }

  // ------------------------------------------------------------ session

  Future<void> start() async {
    _event = _events.active.value;
    if (_event == null || _event!.isClosed) {
      state.value = RecState.error;
      return;
    }
    _sessionOpen = true;
    banner.value = null;
    state.value = RecState.starting;
    final status = await Permission.microphone.request();
    if (!_sessionOpen) return; // người dùng đã rời màn hình trong lúc hỏi quyền
    if (!status.isGranted) {
      state.value = RecState.denied; // X04
      return;
    }
    if (!await _initSpeech()) {
      if (_sessionOpen) state.value = RecState.error;
      return;
    }
    _policy.userStartedTurn();
    await _listenTurn();
  }

  Future<void> openAppSettingsForMic() => openAppSettings();

  Future<bool> _initSpeech() async {
    if (_speechReady) return true;
    try {
      final ok = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );
      if (!ok) {
        banner.value = 'rec_err_no_service'.tr;
        sttInfo.value = '';
        return false;
      }
      final locales = await _speech.locales();
      final id = pickVietnameseLocale(locales.map((l) => l.localeId));
      if (id == null) {
        banner.value = 'rec_err_no_vi'.tr;
        sttInfo.value = '';
        return false;
      }
      _locale = id;
      sttInfo.value = 'speech: $id';
      _speechReady = true;
      return true;
    } catch (e, st) {
      _log.error('speech init failed', e, st);
      banner.value = 'rec_err_no_service'.tr;
      return false;
    }
  }

  /// Một lượt nghe = một phong bì. Chỉ tự gọi lại sau lượt CÓ câu hợp lệ.
  Future<void> _listenTurn() async {
    if (!_sessionOpen || !_speechReady || _speech.isListening) return;
    final gen = ++_generation;
    _turnHadUtterance = false;
    _turnEnding = false;
    _tracker.reset();
    banner.value = null;
    state.value = RecState.listening;
    try {
      await _speech.listen(
        onResult: (r) => _onResult(r, gen),
        onSoundLevelChange: _onSound,
        listenOptions: stt.SpeechListenOptions(
          localeId: _locale,
          listenFor: const Duration(seconds: 60),
          pauseFor: Duration(milliseconds: _settings.silenceMs.value),
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (e, st) {
      _log.error('speech listen failed', e, st);
      banner.value = 'rec_err_listen'.tr;
      state.value = RecState.idle;
    }
  }

  void _onSound(double v) {
    // dB của recognizer: khoảng -2 (im) .. 10 (to)
    level.value = ((v + 2) / 12).clamp(0.0, 1.0);
    speaking.value = v > 1;
  }

  void _onResult(SpeechRecognitionResult r, int gen) {
    if (gen != _generation) return; // callback muộn của lượt cũ
    _tracker.onResult(r.recognizedWords, isFinal: r.finalResult);
    sttInfo.value = 'speech: $_locale · ${_tracker.resultCount}';
    _flushTimer?.cancel();
    if (!r.finalResult) {
      // Máy không gửi final: tự chốt câu khi người nói dừng.
      _flushTimer = Timer(
        Duration(milliseconds: _settings.silenceMs.value + 900),
        () {
          _tracker.flush();
          _speech.stop();
        },
      );
    }
  }

  void _onStatus(String status) {
    if (status != 'done' && status != 'notListening') return;
    if (!_sessionOpen || _turnEnding) return;
    _turnEnding = true;
    final gen = _generation;
    // Chờ kết quả cuối (nếu có) rồi mới quyết định nghe tiếp.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (gen != _generation || !_sessionOpen) return;
      _flushTimer?.cancel();
      _tracker.flush();
      level.value = 0;
      speaking.value = false;
      final again = _policy.shouldAutoRestart(
        turnHadUtterance: _turnHadUtterance,
      );
      if (again) {
        Future.delayed(const Duration(milliseconds: 300), _listenTurn);
      } else if (state.value == RecState.listening) {
        state.value = RecState.idle; // chờ người dùng chạm mic
      }
    });
  }

  void _onError(SpeechRecognitionError e) {
    _log.warning('speech error ${e.errorMsg}');
    if (!_sessionOpen) return;
    final m = e.errorMsg;
    if (m.contains('permission')) {
      state.value = RecState.denied;
      return;
    }
    if (m == 'error_no_match' || m == 'error_speech_timeout') {
      return; // lượt rỗng: onStatus sẽ chuyển sang "sẵn sàng", không tự lặp
    }
    if (m.contains('network')) {
      banner.value = 'rec_err_network_stt'.tr;
    } else if (m.contains('busy') || m.contains('client')) {
      banner.value = 'rec_err_listen'.tr;
    } else if (m.contains('language')) {
      banner.value = 'rec_err_no_vi'.tr;
    }
    // Lỗi khác: onStatus sẽ kết thúc lượt; KHÔNG tự khởi động lại.
  }

  /// Nút mic: đang nghe -> chốt câu hiện tại; đang rảnh -> bắt đầu lượt mới.
  Future<void> cutSegment() async {
    if (!_sessionOpen) return;
    if (_speech.isListening) {
      await _speech.stop(); // final tới ngay; onStatus xử lý tiếp
      return;
    }
    if (state.value == RecState.idle || state.value == RecState.error) {
      if (!_speechReady && !await _initSpeech()) return;
      _policy.userStartedTurn();
      await _listenTurn();
    }
  }

  void _pauseListening() {
    _generation++;
    _flushTimer?.cancel();
    _speech.cancel();
    level.value = 0;
    speaking.value = false;
    if (state.value == RecState.listening) state.value = RecState.idle;
  }

  /// Rời màn hình: tắt mic ngay, không chờ gì.
  void abort() {
    _sessionOpen = false;
    _generation++;
    _flushTimer?.cancel();
    try {
      _speech.cancel();
    } catch (_) {}
    liveText.value = '';
    level.value = 0;
    speaking.value = false;
    if (state.value != RecState.denied) state.value = RecState.idle;
  }

  /// Kết thúc phiên: chốt câu đang nói, chờ các lượt đang xử lý rồi trả về.
  Future<void> stopSession({bool auto = false}) async {
    if (state.value == RecState.stopping) return;
    state.value = RecState.stopping;
    _flushTimer?.cancel();
    try {
      if (_speech.isListening) {
        await _speech.stop();
        await Future.delayed(const Duration(milliseconds: 700));
      }
      _tracker.flush();
    } catch (e, st) {
      _log.error('stop failed', e, st);
    }
    _sessionOpen = false;
    _generation++;
    liveText.value = '';
    level.value = 0;
    speaking.value = false;
    // Chờ AI xử lý nốt (tối đa 40s) để màn kết quả có số liệu đầy đủ.
    await _queue.timeout(const Duration(seconds: 40), onTimeout: () {});
    state.value = RecState.idle;
  }

  // --------------------------------------------------------- AI + lưu

  /// Câu hoàn chỉnh từ nhận dạng giọng nói -> một phong bì mới (đang xử lý).
  Future<void> _submitText(String text) async {
    final ev = _event;
    if (ev == null) return;
    _turnHadUtterance = true;
    final g = GiftRecord(
      id: _uuid.v4(), // = request_id (idempotent) = id bản ghi
      eventId: ev.id,
      status: GiftStatus.processing,
      source: GiftSource.voice,
      side: side.value,
      transcript: text, // giữ nguyên transcript kể cả khi backend lỗi
    );
    await _repo.save(g, enqueue: false); // chưa tính vào tổng, chưa đồng bộ
    items.insert(0, g);
    _enqueue(g.id);
  }

  void _enqueue(String id) {
    _inFlight++;
    _queue = _queue.then((_) => _process(id)).whenComplete(() => _inFlight--);
  }

  Future<void> _process(String id) async {
    final idx = items.indexWhere((x) => x.id == id);
    if (idx < 0) return;
    final g = items[idx];
    final text = (g.transcript ?? '').trim();
    if (text.isEmpty) return;
    if (!await AscConnectivity.isOnline()) {
      await _fail(g, 'err_offline'.tr);
      banner.value = 'err_offline'.tr;
      return;
    }
    ParsedGift parsed;
    try {
      parsed = await _api.parseGift(
        eventId: g.eventId,
        requestId: id,
        text: text,
      );
      banner.value = null;
    } on NetworkException {
      await _fail(g, 'err_network'.tr);
      banner.value = 'err_network'.tr;
      return;
    } on ApiException catch (e) {
      if (e.isQuota) {
        banner.value = 'err_quota'.tr;
        await _fail(g, 'err_quota'.tr);
      } else {
        await _fail(g, e.message);
      }
      return;
    } catch (e, st) {
      _log.error('parse failed', e, st);
      await _fail(g, 'err_generic'.tr);
      return;
    }
    try {
      await _apply(g, parsed);
    } catch (e, st) {
      // AI xong nhưng lưu local lỗi: không cộng tiền, cho thử lại cùng request_id.
      _log.error('save after parse failed', e, st);
      await _fail(g, 'err_generic'.tr);
    }
  }

  Future<void> _apply(GiftRecord g, ParsedGift p) async {
    final decision = decideSave(
      p,
      autoSaveEnabled: _settings.autoSave.value,
      maxAmountVnd: AppConfig.maxAmountVnd,
    );
    final warnings = [...p.warnings];
    if (p.possibleDuplicate && !warnings.contains('possible_duplicate')) {
      warnings.add('possible_duplicate');
    }
    final updated = g.copyWith(
      guestName: p.guestName ?? '',
      relationship: p.relationship,
      amountVnd: p.amount ?? 0,
      status: decision == SaveDecision.autoSave
          ? GiftStatus.confirmed
          : GiftStatus.pendingReview,
      warnings: warnings,
      errorMessage: null,
    );
    // enqueue=true: đồng bộ lên server qua PUT /v1/gifts/:id (id = request_id).
    await _repo.save(updated);
    _replace(updated);
    await _gifts.reload();
  }

  Future<void> _fail(GiftRecord g, String msg) async {
    final f = g.copyWith(status: GiftStatus.failed, errorMessage: msg);
    await _repo.save(f, enqueue: false); // lỗi: không đồng bộ, không cộng tiền
    _replace(f);
  }

  void _replace(GiftRecord g) {
    final i = items.indexWhere((x) => x.id == g.id);
    if (i >= 0) items[i] = g;
    items.refresh();
  }

  /// Còn transcript thì thử lại được, kể cả khi đã rời màn hình ghi âm.
  bool canRetry(GiftRecord g) =>
      g.status == GiftStatus.failed && (g.transcript ?? '').trim().isNotEmpty;

  /// Thử lại với CÙNG request_id -> backend không gọi AI/tạo bản ghi lần 2.
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

  /// Ai mừng nhiều nhất trong phiên này (cộng dồn theo tên, chỉ confirmed).
  List<({String name, int amount})> get topGivers {
    final m = <String, ({String name, int amount})>{};
    for (final g in items.where((x) => x.status == GiftStatus.confirmed)) {
      final k = g.guestName.trim().toLowerCase();
      if (k.isEmpty) continue;
      final cur = m[k];
      m[k] = (
        name: cur?.name ?? g.guestName.trim(),
        amount: (cur?.amount ?? 0) + g.amountVnd,
      );
    }
    final l = m.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
    return l.take(5).toList();
  }

  /// Trạng thái hiển thị cho người dùng: Sẵn sàng / Đang nghe / Đang xử lý AI /
  /// Đã lưu / Cần kiểm tra / Lỗi.
  String get statusKey {
    if (state.value == RecState.error || state.value == RecState.denied) {
      return 'rec_status_error';
    }
    if (state.value == RecState.listening) return 'rec_status_listening';
    if (processingCount > 0) return 'rec_status_processing';
    if (items.isNotEmpty) {
      switch (items.first.status) {
        case GiftStatus.confirmed:
          return 'rec_status_saved';
        case GiftStatus.pendingReview:
          return 'rec_status_review';
        case GiftStatus.failed:
          return 'rec_status_error';
        case GiftStatus.processing:
          return 'rec_status_processing';
      }
    }
    return 'rec_status_ready';
  }
}
