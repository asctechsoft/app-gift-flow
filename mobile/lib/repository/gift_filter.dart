import '../models/data_models/gift_record.dart';
import '../models/ui_models/gift_status.dart';

enum GiftSort { newest, oldest, amountDesc, amountAsc, nameAsc }

/// Bộ lọc danh sách tiền mừng (màn Danh sách + bottom sheet Bộ lọc).
class GiftFilter {
  const GiftFilter({
    this.query = '',
    this.eventId,
    this.eventType,
    this.side,
    this.relationship,
    this.status,
    this.from,
    this.to,
    this.minAmount,
    this.maxAmount,
    this.sort = GiftSort.newest,
  });

  final String query;

  /// Lọc theo một sự kiện cụ thể (màn chi tiết sự kiện).
  final String? eventId;

  /// wedding | engagement | birthday | housewarming | baby_month | other
  final String? eventType;
  final String? side;

  /// '' = chưa rõ quan hệ.
  final String? relationship;
  final GiftStatus? status;
  final DateTime? from;
  final DateTime? to;
  final int? minAmount;
  final int? maxAmount;
  final GiftSort sort;

  static const _unset = Object();

  GiftFilter copyWith({
    String? query,
    Object? eventId = _unset,
    Object? eventType = _unset,
    Object? side = _unset,
    Object? relationship = _unset,
    Object? status = _unset,
    Object? from = _unset,
    Object? to = _unset,
    Object? minAmount = _unset,
    Object? maxAmount = _unset,
    GiftSort? sort,
  }) => GiftFilter(
    query: query ?? this.query,
    eventId: identical(eventId, _unset) ? this.eventId : eventId as String?,
    eventType: identical(eventType, _unset)
        ? this.eventType
        : eventType as String?,
    side: identical(side, _unset) ? this.side : side as String?,
    relationship: identical(relationship, _unset)
        ? this.relationship
        : relationship as String?,
    status: identical(status, _unset) ? this.status : status as GiftStatus?,
    from: identical(from, _unset) ? this.from : from as DateTime?,
    to: identical(to, _unset) ? this.to : to as DateTime?,
    minAmount: identical(minAmount, _unset)
        ? this.minAmount
        : minAmount as int?,
    maxAmount: identical(maxAmount, _unset)
        ? this.maxAmount
        : maxAmount as int?,
    sort: sort ?? this.sort,
  );

  /// Số điều kiện đang áp dụng trong bottom sheet Bộ lọc (không tính ô tìm kiếm).
  int get sheetActiveCount =>
      (eventType != null ? 1 : 0) +
      (from != null || to != null ? 1 : 0) +
      (minAmount != null || maxAmount != null ? 1 : 0);

  bool get hasAny =>
      query.isNotEmpty ||
      eventType != null ||
      side != null ||
      relationship != null ||
      status != null ||
      from != null ||
      to != null ||
      minAmount != null ||
      maxAmount != null;
}

/// Bản ghi kèm thông tin sự kiện (danh sách toàn bộ sự kiện).
class GiftWithEvent {
  GiftWithEvent(this.gift, this.eventName, this.eventType);
  final GiftRecord gift;
  final String eventName;
  final String eventType;
}

/// Tổng hợp theo khách (gộp theo tên không dấu, không phân biệt hoa thường).
class GuestSummary {
  GuestSummary({
    required this.name,
    required this.totalVnd,
    required this.count,
    this.relationship,
    this.pending = 0,
  });
  final String name;
  final int totalVnd;
  final int count;
  final String? relationship;
  final int pending;
}

/// Điểm của biểu đồ xu hướng: tổng tiền cộng dồn tới hết ngày [day].
class TrendPoint {
  TrendPoint(this.day, this.dayVnd, this.cumulativeVnd);
  final DateTime day;
  final int dayVnd;
  final int cumulativeVnd;
}
