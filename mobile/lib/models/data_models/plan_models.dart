import '../../utils/text_utils.dart';

/// Danh mục chi tiêu của kế hoạch cưới.
class PlanCategory {
  const PlanCategory(this.key, this.labelKey, this.emoji);
  final String key;
  final String labelKey;
  final String emoji;

  static const venue = PlanCategory('venue', 'pcat_venue', '🏛️');
  static const catering = PlanCategory('catering', 'pcat_catering', '🍽️');
  static const attire = PlanCategory('attire', 'pcat_attire', '👗');
  static const makeup = PlanCategory('makeup', 'pcat_makeup', '💄');
  static const photo = PlanCategory('photo', 'pcat_photo', '📸');
  static const decor = PlanCategory('decor', 'pcat_decor', '💐');
  static const invitation = PlanCategory('invitation', 'pcat_invitation', '💌');
  static const ceremony = PlanCategory('ceremony', 'pcat_ceremony', '🎎');
  static const ring = PlanCategory('ring', 'pcat_ring', '💍');
  static const transport = PlanCategory('transport', 'pcat_transport', '🚗');
  static const entertainment = PlanCategory(
    'entertainment',
    'pcat_entertainment',
    '🎤',
  );
  static const honeymoon = PlanCategory('honeymoon', 'pcat_honeymoon', '🏝️');
  static const other = PlanCategory('other', 'pcat_other', '📦');

  static const List<PlanCategory> all = [
    venue,
    catering,
    attire,
    makeup,
    photo,
    decor,
    invitation,
    ceremony,
    ring,
    transport,
    entertainment,
    honeymoon,
    other,
  ];

  static PlanCategory of(String? key) =>
      all.firstWhere((c) => c.key == key, orElse: () => other);
}

/// Mẫu kế hoạch cưới: các khoản thường gặp để người dùng điền chi phí.
class PlanTemplate {
  PlanTemplate._();

  /// (danh mục, tên khoản) - tên hiển thị lấy từ chuỗi đa ngôn ngữ `ptpl_<key>`.
  static const List<(String, String)> wedding = [
    ('venue', 'ptpl_hall'),
    ('catering', 'ptpl_banquet'),
    ('catering', 'ptpl_drinks'),
    ('attire', 'ptpl_dress'),
    ('attire', 'ptpl_suit'),
    ('makeup', 'ptpl_makeup'),
    ('photo', 'ptpl_photo'),
    ('photo', 'ptpl_video'),
    ('decor', 'ptpl_flowers'),
    ('decor', 'ptpl_stage'),
    ('invitation', 'ptpl_cards'),
    ('ceremony', 'ptpl_tray'),
    ('ring', 'ptpl_rings'),
    ('transport', 'ptpl_cars'),
    ('entertainment', 'ptpl_mc'),
    ('honeymoon', 'ptpl_trip'),
  ];
}

/// Trạng thái thanh toán của một khoản chi.
class PayStatus {
  PayStatus._();
  static const planned = 'planned';
  static const deposit = 'deposit';
  static const paid = 'paid';

  static String derive(int planned_, int paid_) {
    if (paid_ <= 0) return planned;
    return paid_ >= planned_ && planned_ > 0 ? paid : deposit;
  }
}

/// Một khoản chi trong kế hoạch (không liên quan tiền mừng).
class PlanItem {
  PlanItem({
    required this.id,
    required this.eventId,
    required this.category,
    required this.name,
    this.plannedVnd = 0,
    this.paidVnd = 0,
    this.status = PayStatus.planned,
    this.vendor,
    this.dueDate,
    this.note,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.synced = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String eventId;
  final String category;
  final String name;
  final int plannedVnd;
  final int paidVnd;
  final String status;
  final String? vendor;

  /// yyyy-MM-dd
  final String? dueDate;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool synced;

  /// Còn phải trả (không âm).
  int get remainingVnd => (plannedVnd - paidVnd).clamp(0, 1 << 62);

  PlanItem copyWith({
    String? category,
    String? name,
    int? plannedVnd,
    int? paidVnd,
    String? status,
    Object? vendor = _keep,
    Object? dueDate = _keep,
    Object? note = _keep,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? synced,
  }) => PlanItem(
    id: id,
    eventId: eventId,
    category: category ?? this.category,
    name: name ?? this.name,
    plannedVnd: plannedVnd ?? this.plannedVnd,
    paidVnd: paidVnd ?? this.paidVnd,
    status: status ?? this.status,
    vendor: identical(vendor, _keep) ? this.vendor : vendor as String?,
    dueDate: identical(dueDate, _keep) ? this.dueDate : dueDate as String?,
    note: identical(note, _keep) ? this.note : note as String?,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
    deletedAt: deletedAt ?? this.deletedAt,
    synced: synced ?? false,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'event_id': eventId,
    'category': category,
    'name': name,
    'planned_vnd': plannedVnd,
    'paid_vnd': paidVnd,
    'status': status,
    'vendor': vendor,
    'due_date': dueDate,
    'note': note,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'deleted_at': deletedAt?.millisecondsSinceEpoch,
    'synced': synced ? 1 : 0,
  };

  factory PlanItem.fromMap(Map<String, Object?> m) => PlanItem(
    id: m['id'] as String,
    eventId: m['event_id'] as String,
    category: (m['category'] as String?) ?? 'other',
    name: (m['name'] as String?) ?? '',
    plannedVnd: (m['planned_vnd'] as int?) ?? 0,
    paidVnd: (m['paid_vnd'] as int?) ?? 0,
    status: (m['status'] as String?) ?? PayStatus.planned,
    vendor: m['vendor'] as String?,
    dueDate: m['due_date'] as String?,
    note: m['note'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
    deletedAt: m['deleted_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['deleted_at'] as int),
    synced: (m['synced'] as int? ?? 0) == 1,
  );

  /// Body `PUT /v1/plan/items/:id`.
  Map<String, Object?> toApi() => {
    'event_id': eventId,
    'category': category,
    'name': name,
    'planned_vnd': plannedVnd,
    'paid_vnd': paidVnd,
    'status': status,
    'vendor': vendor,
    'due_date': dueDate,
    'note': note,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory PlanItem.fromApi(Map<String, dynamic> j) => PlanItem(
    id: j['id'] as String,
    eventId: j['event_id'] as String,
    category: (j['category'] as String?) ?? 'other',
    name: (j['name'] as String?) ?? '',
    plannedVnd: (j['planned_vnd'] as num?)?.toInt() ?? 0,
    paidVnd: (j['paid_vnd'] as num?)?.toInt() ?? 0,
    status: (j['status'] as String?) ?? PayStatus.planned,
    vendor: j['vendor'] as String?,
    dueDate: j['due_date'] as String?,
    note: j['note'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
    deletedAt: j['deleted_at'] == null
        ? null
        : DateTime.parse(j['deleted_at'] as String).toLocal(),
    synced: true,
  );
}

/// Trạng thái mời của khách dự kiến.
class InviteStatus {
  InviteStatus._();
  static const planned = 'planned'; // chưa mời
  static const invited = 'invited'; // đã mời
  static const confirmed = 'confirmed'; // xác nhận tham dự
  static const declined = 'declined'; // từ chối

  static const List<String> all = [planned, invited, confirmed, declined];

  static String labelKey(String s) => switch (s) {
    invited => 'inv_invited',
    confirmed => 'inv_confirmed',
    declined => 'inv_declined',
    _ => 'inv_planned',
  };

  static String normalize(String? s) => all.contains(s) ? s! : planned;
}

/// Khách mời DỰ KIẾN trong kế hoạch (không có tiền mừng).
class PlanGuest {
  PlanGuest({
    required this.id,
    required this.eventId,
    required this.name,
    this.relationship,
    this.side = 'mine',
    this.partySize = 1,
    this.inviteStatus = InviteStatus.planned,
    this.phone,
    this.note,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.synced = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String eventId;
  final String name;
  final String? relationship;

  /// mine | parents
  final String side;

  /// Số người đi cùng, tính cả khách (>= 1).
  final int partySize;
  final String inviteStatus;
  final String? phone;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool synced;

  PlanGuest copyWith({
    String? name,
    Object? relationship = _keep,
    String? side,
    int? partySize,
    String? inviteStatus,
    Object? phone = _keep,
    Object? note = _keep,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? synced,
  }) => PlanGuest(
    id: id,
    eventId: eventId,
    name: name ?? this.name,
    relationship: identical(relationship, _keep)
        ? this.relationship
        : relationship as String?,
    side: side ?? this.side,
    partySize: partySize ?? this.partySize,
    inviteStatus: inviteStatus ?? this.inviteStatus,
    phone: identical(phone, _keep) ? this.phone : phone as String?,
    note: identical(note, _keep) ? this.note : note as String?,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
    deletedAt: deletedAt ?? this.deletedAt,
    synced: synced ?? false,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'event_id': eventId,
    'name': name,
    'relationship': relationship,
    'side': side,
    'party_size': partySize,
    'invite_status': inviteStatus,
    'phone': phone,
    'note': note,
    'search_key': TextUtils.fold('$name ${relationship ?? ''} ${phone ?? ''}'),
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'deleted_at': deletedAt?.millisecondsSinceEpoch,
    'synced': synced ? 1 : 0,
  };

  factory PlanGuest.fromMap(Map<String, Object?> m) => PlanGuest(
    id: m['id'] as String,
    eventId: m['event_id'] as String,
    name: (m['name'] as String?) ?? '',
    relationship: m['relationship'] as String?,
    side: (m['side'] as String?) ?? 'mine',
    partySize: (m['party_size'] as int?) ?? 1,
    inviteStatus: InviteStatus.normalize(m['invite_status'] as String?),
    phone: m['phone'] as String?,
    note: m['note'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
    deletedAt: m['deleted_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['deleted_at'] as int),
    synced: (m['synced'] as int? ?? 0) == 1,
  );

  /// Body `PUT /v1/plan/guests/:id`.
  Map<String, Object?> toApi() => {
    'event_id': eventId,
    'name': name,
    'relationship': relationship,
    'side': side,
    'party_size': partySize,
    'invite_status': inviteStatus,
    'phone': phone,
    'note': note,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory PlanGuest.fromApi(Map<String, dynamic> j) => PlanGuest(
    id: j['id'] as String,
    eventId: j['event_id'] as String,
    name: (j['name'] as String?) ?? '',
    relationship: j['relationship'] as String?,
    side: (j['side'] as String?) ?? 'mine',
    partySize: (j['party_size'] as num?)?.toInt() ?? 1,
    inviteStatus: InviteStatus.normalize(j['invite_status'] as String?),
    phone: j['phone'] as String?,
    note: j['note'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
    deletedAt: j['deleted_at'] == null
        ? null
        : DateTime.parse(j['deleted_at'] as String).toLocal(),
    synced: true,
  );
}

const Object _keep = Object();

/// Tổng hợp kế hoạch tính cục bộ (offline-first).
class PlanSummary {
  PlanSummary({
    required this.budgetVnd,
    required this.plannedVnd,
    required this.paidVnd,
    required this.byCategory,
    required this.guestCount,
    required this.headcount,
    required this.headcountExpected,
    required this.byStatus,
  });

  final int? budgetVnd;
  final int plannedVnd;
  final int paidVnd;
  final List<CategoryTotal> byCategory;
  final int guestCount;
  final int headcount;

  /// Số người dự kiến đến (không tính khách đã từ chối).
  final int headcountExpected;
  final Map<String, int> byStatus;

  int get remainingToPayVnd => (plannedVnd - paidVnd).clamp(0, 1 << 62);
  int? get budgetLeftVnd => budgetVnd == null ? null : budgetVnd! - plannedVnd;
  bool get overBudget => budgetVnd != null && plannedVnd > budgetVnd!;

  /// Tỉ lệ dự kiến chi / ngân sách (0..n), null nếu chưa đặt ngân sách.
  double? get budgetUsedRatio => (budgetVnd == null || budgetVnd == 0)
      ? null
      : plannedVnd / budgetVnd!;

  static PlanSummary compute({
    required int? budgetVnd,
    required List<PlanItem> items,
    required List<PlanGuest> guests,
  }) {
    final cats = <String, CategoryTotal>{};
    var planned = 0;
    var paid = 0;
    for (final i in items) {
      planned += i.plannedVnd;
      paid += i.paidVnd;
      final c = cats.putIfAbsent(i.category, () => CategoryTotal(i.category));
      c.plannedVnd += i.plannedVnd;
      c.paidVnd += i.paidVnd;
      c.count++;
    }
    final byStatus = {for (final s in InviteStatus.all) s: 0};
    var head = 0;
    var headExpected = 0;
    for (final g in guests) {
      byStatus[g.inviteStatus] = (byStatus[g.inviteStatus] ?? 0) + 1;
      head += g.partySize;
      if (g.inviteStatus != InviteStatus.declined) headExpected += g.partySize;
    }
    final list = cats.values.toList()
      ..sort((a, b) => b.plannedVnd.compareTo(a.plannedVnd));
    return PlanSummary(
      budgetVnd: budgetVnd,
      plannedVnd: planned,
      paidVnd: paid,
      byCategory: list,
      guestCount: guests.length,
      headcount: head,
      headcountExpected: headExpected,
      byStatus: byStatus,
    );
  }
}

class CategoryTotal {
  CategoryTotal(this.category);
  final String category;
  int plannedVnd = 0;
  int paidVnd = 0;
  int count = 0;
}
