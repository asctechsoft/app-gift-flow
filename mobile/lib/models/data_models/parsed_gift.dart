/// Kết quả backend `POST /v1/ai/parse-gift` (chỉ phân tích, chưa lưu).
class ParsedGift {
  ParsedGift({
    required this.requestId,
    required this.transcript,
    this.guestName,
    this.relationship,
    this.amount,
    this.needsReview = true,
    this.possibleDuplicate = false,
    this.warnings = const [],
  });

  final String requestId;
  final String transcript;
  final String? guestName;
  final String? relationship;

  /// VND nguyên; null nếu không rõ.
  final int? amount;
  final bool needsReview;
  final bool possibleDuplicate;
  final List<String> warnings;

  factory ParsedGift.fromJson(Map<String, dynamic> j) {
    final d = (j['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    String? clean(Object? v) {
      final s = (v as String?)?.trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return ParsedGift(
      requestId: j['request_id'] as String? ?? '',
      transcript: j['transcript'] as String? ?? '',
      guestName: clean(d['guest_name']),
      relationship: clean(d['relationship']),
      amount: (d['amount'] as num?)?.toInt(),
      // Thiếu trường => coi là cần kiểm tra (không bao giờ tự tin khi dữ liệu lạ).
      needsReview: j['needs_review'] as bool? ?? true,
      possibleDuplicate: j['possible_duplicate'] as bool? ?? false,
      warnings:
          ((j['warnings'] as List?) ?? const []).whereType<String>().toList(),
    );
  }
}

enum SaveDecision {
  /// Rõ ràng + auto-save bật: lưu thành bản ghi đã xác nhận.
  autoSave,

  /// Thiếu/mơ hồ/nghi trùng/auto-save tắt: giữ ở "chờ xác nhận", KHÔNG cộng vào tổng.
  review,
}

/// Business rules phía client (BR04/05/06): không bao giờ tự xác nhận khi không chắc.
SaveDecision decideSave(
  ParsedGift p, {
  required bool autoSaveEnabled,
  int maxAmountVnd = 1000000000,
}) {
  if (!autoSaveEnabled) return SaveDecision.review;
  if (p.needsReview || p.possibleDuplicate) return SaveDecision.review;
  if ((p.guestName ?? '').isEmpty) return SaveDecision.review;
  final a = p.amount;
  if (a == null || a <= 0 || a > maxAmountVnd) return SaveDecision.review;
  return SaveDecision.autoSave;
}
