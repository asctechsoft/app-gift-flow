/// Trạng thái bản ghi tiền mừng (BR04). Chỉ [confirmed] vào tổng chính.
/// Xoá mềm dùng `deletedAt` riêng nên không nằm trong enum.
enum GiftStatus {
  processing('processing'),
  pendingReview('pending_review'),
  confirmed('confirmed'),
  failed('failed');

  const GiftStatus(this.wire);

  /// Giá trị gửi/nhận qua API và lưu SQLite.
  final String wire;

  static GiftStatus fromWire(String? v) => GiftStatus.values.firstWhere(
        (s) => s.wire == v,
        orElse: () => GiftStatus.pendingReview,
      );
}

enum GiftSource {
  voice('voice'),
  manual('manual');

  const GiftSource(this.wire);
  final String wire;

  static GiftSource fromWire(String? v) =>
      GiftSource.values.firstWhere((s) => s.wire == v, orElse: () => manual);
}

/// Các nhóm quan hệ gợi ý (người dùng vẫn nhập tự do).
const List<String> kRelationshipPresets = [
  'Bạn bè',
  'Gia đình',
  'Đồng nghiệp',
  'Họ hàng',
  'Bạn thân',
  'Hàng xóm',
];

/// Nhóm khách: khách của mình (bạn bè, đồng nghiệp...) hay khách của bố mẹ.
class GiftSide {
  GiftSide._();
  static const String mine = 'mine';
  static const String parents = 'parents';
  static const List<String> all = [mine, parents];

  static String normalize(String? v) => all.contains(v) ? v! : mine;
  static String labelKey(String side) =>
      side == parents ? 'side_parents' : 'side_mine';
}
