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

/// Gom kết quả partial/final của một lượt nói thành các câu hoàn chỉnh.
///
/// - partial: chỉ cập nhật chữ đang hiện ([onLive]), KHÔNG gửi đi.
/// - final: gửi đúng một lần ([onUtterance]).
/// - Một số máy không bao giờ báo final: [flush] gửi câu partial gần nhất.
/// - Chống gửi trùng khi callback bị gọi lặp, hoặc final tới sau khi đã flush.
class UtteranceTracker {
  UtteranceTracker({
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

  String _partial = '';
  String _lastSent = '';
  DateTime _lastSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _results = 0;

  /// Câu partial chưa gửi (rỗng nếu không có).
  String get pending => _partial;

  /// Số lần callback kết quả đã nhận (để hiển thị/chẩn đoán).
  int get resultCount => _results;

  void onResult(String words, {required bool isFinal}) {
    _results++;
    final text = words.trim();
    if (isFinal) {
      _partial = '';
      onLive('');
      _send(text);
    } else {
      _partial = text;
      onLive(text);
    }
  }

  /// Gửi câu partial gần nhất (người nói đã dừng / hết lượt nhưng không có final).
  void flush() {
    final t = _partial;
    _partial = '';
    onLive('');
    if (t.isNotEmpty) _send(t);
  }

  /// Bắt đầu lượt nghe mới: bỏ mọi partial còn sót, giữ chống-trùng.
  void reset() {
    _partial = '';
    onLive('');
  }

  void _send(String text) {
    if (text.replaceAll(RegExp(r'\s'), '').length < minLetters) return;
    final recent = _clock().difference(_lastSentAt) < dedupeWindow;
    if (recent &&
        _lastSent.isNotEmpty &&
        (text == _lastSent ||
            text.startsWith(_lastSent) ||
            _lastSent.startsWith(text))) {
      return;
    }
    _lastSent = text;
    _lastSentAt = _clock();
    onUtterance(text);
  }
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
