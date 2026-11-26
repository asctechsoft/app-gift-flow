/// Logic thuần Dart cho nhận dạng giọng nói trên máy (test được, không phụ thuộc plugin).
library;

/// Chọn locale tiếng Việt từ danh sách hệ thống hỗ trợ: ưu tiên `vi_VN`,
/// sau đó bất kỳ `vi*`. Trả về `null` nếu máy không hỗ trợ tiếng Việt.
String? pickVietnameseLocale(Iterable<String> ids) {
  String norm(String id) => id.toLowerCase().replaceAll('-', '_');
  String? anyVi;
  for (final id in ids) {
    final n = norm(id);
    if (n == 'vi_vn') return id;
    if (anyVi == null && (n == 'vi' || n.startsWith('vi_'))) anyVi = id;
  }
  return anyVi;
}

/// Bộ đệm một LƯỢT nói (= một phong bì).
///
/// Bộ nhận dạng của hệ thống tự kết thúc sau ~2 giây im lặng; để người dùng được
/// ngập ngừng, bộ đệm GOM các phiên nhận dạng liên tiếp của cùng một lượt và chỉ
/// gửi đi khi đủ thời gian im lặng ([send]) hoặc người dùng chạm mic.
///
/// - partial: chỉ hiện chữ ([onLive]), KHÔNG gửi.
/// - final: được chốt vào câu của lượt; callback final lặp lại bị bỏ.
/// - [commitPartial]: máy không gửi final khi hết phiên -> chốt partial còn sót.
/// - [send]: gửi cả câu đúng một lần; chống gửi trùng khi retry/callback muộn.
class TurnBuffer {
  TurnBuffer({
    required this.onLive,
    required this.onUtterance,
    DateTime Function()? clock,
    this.dedupeWindow = const Duration(seconds: 5),
    this.minLetters = 3,
  }) : _clock = clock ?? DateTime.now;

  final void Function(String text) onLive;
  final void Function(String text) onUtterance;
  final Duration dedupeWindow;
  final int minLetters;
  final DateTime Function() _clock;

  String _committed = '';
  String _partial = '';
  String _lastFinal = '';
  String _lastSent = '';
  DateTime _lastSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _results = 0;

  static String _join(String a, String b) =>
      a.isEmpty ? b : (b.isEmpty ? a : '$a $b');

  /// Toàn bộ chữ của lượt hiện tại (đã chốt + đang nói).
  String get text => _join(_committed, _partial);
  bool get hasText => text.isNotEmpty;

  /// Số lần callback kết quả đã nhận (để hiển thị/chẩn đoán).
  int get resultCount => _results;

  void onResult(String words, {required bool isFinal}) {
    _results++;
    final w = words.trim();
    if (isFinal) {
      _partial = '';
      if (w.isNotEmpty && w != _lastFinal) {
        _committed = _join(_committed, w);
        _lastFinal = w;
      }
    } else {
      _partial = w;
    }
    onLive(text);
  }

  /// Hết một phiên nhận dạng mà không có final: giữ lại partial cuối cùng.
  void commitPartial() {
    if (_partial.isNotEmpty) {
      _committed = _join(_committed, _partial);
      _lastFinal = _partial;
      _partial = '';
    }
    onLive(text);
  }

  /// Gửi cả câu của lượt. Trả về true nếu thực sự gửi.
  bool send() {
    final t = text;
    _committed = '';
    _partial = '';
    _lastFinal = '';
    onLive('');
    return _emit(t);
  }

  /// Bắt đầu lượt mới: bỏ mọi chữ còn sót, giữ chống-trùng giữa các lượt.
  void reset() {
    _committed = '';
    _partial = '';
    _lastFinal = '';
    onLive('');
  }

  bool _emit(String t) {
    if (t.replaceAll(RegExp(r'\s'), '').length < minLetters) return false;
    final recent = _clock().difference(_lastSentAt) < dedupeWindow;
    if (recent &&
        _lastSent.isNotEmpty &&
        (t == _lastSent || t.startsWith(_lastSent) || _lastSent.startsWith(t))) {
      return false;
    }
    _lastSent = t;
    _lastSentAt = _clock();
    onUtterance(t);
    return true;
  }
}

/// Mức âm thanh để báo người dùng nói quá nhỏ.
/// [maxLevel] là mức lớn nhất (dB của bộ nhận dạng, khoảng -2 im .. 10 to) trong lượt.
enum VoiceHint {
  /// Đang ổn / chưa cần nhắc.
  none,

  /// Không nghe thấy gì (mic gần như im): nói to hơn / lại gần micro.
  tooQuiet,

  /// Có tiếng nhưng không nhận ra chữ: nói rõ hơn.
  notRecognized,
}

VoiceHint voiceHint({
  required Duration elapsed,
  required bool hasText,
  required double maxLevel,
  Duration grace = const Duration(seconds: 4),
  double quietLevel = 1.0,
}) {
  if (hasText || elapsed < grace) return VoiceHint.none;
  return maxLevel < quietLevel ? VoiceHint.tooQuiet : VoiceHint.notRecognized;
}

/// Chính sách nghe liên tiếp, KHÔNG cho phép vòng lặp mở mic vô hạn:
/// chỉ tự nghe tiếp sau một lượt có câu hợp lệ. Lượt rỗng (im lặng/không nhận
/// ra gì) thì dừng ở trạng thái sẵn sàng, chờ người dùng chạm mic.
class TurnPolicy {
  /// Trần an toàn số lượt tự khởi động liên tiếp trong một phiên.
  static const int maxAutoTurns = 100;

  int _autoTurns = 0;

  bool shouldAutoRestart({required bool turnHadUtterance}) {
    if (!turnHadUtterance) return false;
    if (_autoTurns >= maxAutoTurns) return false;
    _autoTurns++;
    return true;
  }

  /// Người dùng chủ động chạm mic: bắt đầu lại bộ đếm.
  void userStartedTurn() => _autoTurns = 0;
}
