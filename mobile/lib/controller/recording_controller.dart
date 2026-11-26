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

  late final TurnBuffer _buffer = TurnBuffer(
    onLive: (t) => liveText.value = t,
    onUtterance: _submitText,
  );
  final TurnPolicy _policy = TurnPolicy();

  /// Phiên đang mở (màn ghi âm đang hiển thị). Khi false: tuyệt đối không bật mic.
  bool _sessionOpen = false;

  /// Đang trong một lượt nói (từ lúc bắt đầu nghe tới lúc gửi/bỏ).
  bool _turnOpen = false;
  bool _turnSent = false;
  DateTime _turnStart = DateTime.now();
  DateTime _lastActivity = DateTime.now();
  double _maxLevel = -2;
  Timer? _ticker;
  int _generation = 0; // bỏ qua callback của lần nghe cũ

  /// Nhắc người dùng khi nói quá nhỏ / không nhận ra (null = không nhắc).
  final Rxn<VoiceHint> hint = Rxn<VoiceHint>();

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
    await _beginTurn();
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

  // ----------------------------------------------------------- một lượt

  /// Bắt đầu một lượt nói (= một phong bì).
  Future<void> _beginTurn() async {
    if (!_sessionOpen || !_speechReady || _turnOpen) return;
    _turnOpen = true;
    _turnSent = false;
    _turnStart = DateTime.now();
    _lastActivity = _turnStart;
    _maxLevel = -2;
    _buffer.reset();
    banner.value = null;
    hint.value = null;
    state.value = RecState.listening;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 400), (_) => _tick());
    await _startRecognizer();
  }

  /// Bật bộ nhận dạng của hệ thống (có thể gọi lại nhiều lần trong một lượt).
  Future<void> _startRecognizer() async {
    if (!_sessionOpen || !_turnOpen || _speech.isListening) return;
    final gen = ++_generation;
    try {
      await _speech.listen(
        onResult: (r) => _onResult(r, gen),
        onSoundLevelChange: _onSound,
        listenOptions: stt.SpeechListenOptions(
          localeId: _locale,
          listenFor: const Duration(seconds: 60),
          // Người dùng được ngập ngừng: thời gian chốt do _tick() quyết định.
          pauseFor: Duration(milliseconds: _settings.silenceMs.value + 3000),
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (e, st) {
      _log.error('speech listen failed', e, st);
      banner.value = 'rec_err_listen'.tr;
      _closeTurn(send: false);
    }
  }

  void _onSound(double v) {
    // dB của recognizer: khoảng -2 (im) .. 10 (to)
    level.value = ((v + 2) / 12).clamp(0.0, 1.0);
    speaking.value = v > 1;
    if (v > _maxLevel) _maxLevel = v;
    if (v > 1) _lastActivity = DateTime.now(); // đang nói: chưa tính im lặng
  }

  void _onResult(SpeechRecognitionResult r, int gen) {
    if (gen != _generation || !_turnOpen) return; // callback muộn của lần nghe cũ
    _buffer.onResult(r.recognizedWords, isFinal: r.finalResult);
    sttInfo.value = 'speech: $_locale · ${_buffer.resultCount}';
    _lastActivity = DateTime.now();
    if (hint.value != null) hint.value = null;
  }

  /// Chạy mỗi 0,4s trong lượt: tự gửi khi im đủ lâu, nhắc khi nói quá nhỏ.
  void _tick() {
    if (!_turnOpen) return;
    final now = DateTime.now();
    if (_buffer.hasText) {
      final quiet = now.difference(_lastActivity).inMilliseconds;
      if (_settings.autoSilenceCut.value && quiet >= _settings.silenceMs.value) {
        _closeTurn(send: true); // im lặng đủ lâu (mặc định 5s) -> gửi
      }
      return;
    }
    final h = voiceHint(
      elapsed: now.difference(_turnStart),
      hasText: false,
      maxLevel: _maxLevel,
    );
    if (h != VoiceHint.none && hint.value != h) hint.value = h;
    // Lượt rỗng quá lâu: dừng ở "Sẵn sàng", không giữ mic mãi.
    if (now.difference(_turnStart).inSeconds >= 20) _closeTurn(send: false);
  }

  void _onStatus(String status) {
    if (status != 'done' && status != 'notListening') return;
    if (!_sessionOpen || !_turnOpen) return;
    final gen = _generation;
    // Hệ thống tự ngắt phiên nhận dạng sau ~2s im lặng: chờ final rồi nghe tiếp
    // để người dùng còn được ngập ngừng; _tick() mới là nơi quyết định gửi.
    Future.delayed(const Duration(milliseconds: 350), () {
      if (gen != _generation || !_sessionOpen || !_turnOpen) return;
      _buffer.commitPartial();
      level.value = 0;
      speaking.value = false;
      if (_buffer.hasText) {
        final quiet = DateTime.now().difference(_lastActivity).inMilliseconds;
        if (!_settings.autoSilenceCut.value ||
            quiet < _settings.silenceMs.value) {
          _startRecognizer(); // tiếp tục gom câu của lượt này
        } else {
          _closeTurn(send: true);
        }
      } else if (DateTime.now().difference(_turnStart).inSeconds < 20 &&
          _maxLevel < 1) {
        // Chưa có chữ, chưa nghe tiếng: tiếp tục chờ trong lúc nhắc "nói to hơn".
        _startRecognizer();
      } else {
        _closeTurn(send: false);
      }
    });
  }

  void _onError(SpeechRecognitionError e) {
    _log.warning('speech error ${e.errorMsg}');
    if (!_sessionOpen) return;
    final m = e.errorMsg;
    if (m.contains('permission')) {
      _closeTurn(send: false);
      state.value = RecState.denied;
      return;
    }
    if (m == 'error_no_match' || m == 'error_speech_timeout') {
      return; // lượt rỗng: onStatus quyết định tiếp (không tự lặp vô hạn)
    }
    if (m.contains('network')) {
      banner.value = 'rec_err_network_stt'.tr;
    } else if (m.contains('busy') || m.contains('client')) {
      banner.value = 'rec_err_listen'.tr;
    } else if (m.contains('language')) {
      banner.value = 'rec_err_no_vi'.tr;
    } else {
      return;
    }
    _closeTurn(send: false);
  }

  /// Kết thúc lượt: gửi câu đã gom (nếu [send]) rồi nghe tiếp theo chính sách.
  void _closeTurn({required bool send}) {
    if (!_turnOpen) return;
    _turnOpen = false;
    _ticker?.cancel();
    _generation++;
    try {
      _speech.cancel();
    } catch (_) {}
    level.value = 0;
    speaking.value = false;
    _buffer.commitPartial();
    var sent = false;
    if (send) sent = _buffer.send();
    _turnSent = sent;
    if (!sent) {
      _buffer.reset();
      // Lượt rỗng: nhắc người dùng vì sao (nói nhỏ / không nhận ra).
      if (_sessionOpen && hint.value == null && !send) {
        final h = voiceHint(
          elapsed: DateTime.now().difference(_turnStart),
          hasText: false,
          maxLevel: _maxLevel,
          grace: Duration.zero,
        );
        if (h != VoiceHint.none) hint.value = h;
      }
    }
    if (!_sessionOpen) return;
    if (_policy.shouldAutoRestart(turnHadUtterance: _turnSent)) {
      Future.delayed(const Duration(milliseconds: 400), _beginTurn);
    } else {
      state.value = RecState.idle; // chờ người dùng chạm mic
    }
  }

  /// Nút mic: đang nghe -> gửi ngay câu hiện tại; đang rảnh -> bắt đầu lượt mới.
  Future<void> cutSegment() async {
    if (!_sessionOpen) return;
    if (_turnOpen) {
      try {
        await _speech.stop(); // final (nếu có) tới ngay
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));
      _closeTurn(send: true);
      return;
    }
    if (state.value == RecState.idle || state.value == RecState.error) {
      if (!_speechReady && !await _initSpeech()) return;
      _policy.userStartedTurn();
      await _beginTurn();
    }
  }

  void _pauseListening() {
    _turnOpen = false;
    _ticker?.cancel();
    _generation++;
    _speech.cancel();
    _buffer.reset();
    level.value = 0;
    speaking.value = false;
    if (state.value == RecState.listening) state.value = RecState.idle;
  }

  /// Rời màn hình: tắt mic ngay, không chờ gì.
  void abort() {
    _sessionOpen = false;
    _turnOpen = false;
    _ticker?.cancel();
    _generation++;
    try {
      _speech.cancel();
    } catch (_) {}
    liveText.value = '';
    hint.value = null;
    level.value = 0;
    speaking.value = false;
    if (state.value != RecState.denied) state.value = RecState.idle;
  }

  /// Kết thúc phiên: gửi nốt câu đang nói, chờ các lượt đang xử lý rồi trả về.
  Future<void> stopSession({bool auto = false}) async {
    if (state.value == RecState.stopping) return;
    state.value = RecState.stopping;
    try {
      if (_turnOpen) {
        try {
          await _speech.stop();
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 600));
        _sessionOpen = false; // không tự nghe tiếp sau khi gửi
        _closeTurn(send: true);
      }
    } catch (e, st) {
      _log.error('stop failed', e, st);
    }
    _sessionOpen = false;
    _turnOpen = false;
    _ticker?.cancel();
    _generation++;
    liveText.value = '';
    hint.value = null;
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
