import '../../utils/text_utils.dart';

/// Trạng thái một lời mời.
class InviteState {
  InviteState._();
  static const upcoming = 'upcoming'; // sắp tới
  static const attended = 'attended'; // đã đi / đã mừng
  static const skipped = 'skipped'; // không đi

  static const List<String> all = [upcoming, attended, skipped];

  static String labelKey(String s) => switch (s) {
    attended => 'invt_attended',
    skipped => 'invt_skipped',
    _ => 'invt_upcoming',
  };

  static String normalize(String? s) => all.contains(s) ? s! : upcoming;
}

/// Lịch đi mừng: sự kiện (thường là đám cưới) CỦA NGƯỜI KHÁC mà mình được mời -
/// ngày giờ, địa điểm, dự chi và đã mừng bao nhiêu cho người đó.
/// Hoàn toàn tách khỏi tiền mừng nhận được.
class Invitation {
  Invitation({
    required this.id,
    required this.personName,
    required this.eventDate,
    this.relationship,
    this.occasion = 'wedding',
    this.eventTime,
    this.location,
    this.plannedVnd = 0,
    this.givenVnd = 0,
    this.status = InviteState.upcoming,
    this.note,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.synced = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String personName;
  final String? relationship;

  /// wedding | engagement | birthday | housewarming | baby_month | other
  final String occasion;

  /// yyyy-MM-dd
  final String eventDate;

  /// HH:mm (24h) hoặc null = chưa rõ giờ.
  final String? eventTime;
  final String? location;

  /// Dự định mừng (VND).
  final int plannedVnd;

  /// Đã mừng thực tế (VND).
  final int givenVnd;
  final String status;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool synced;

  /// Thời điểm diễn ra (ngày + giờ; không có giờ thì lấy 00:00).
  DateTime? get when {
    final d = DateTime.tryParse(eventDate);
    if (d == null) return null;
    final t = eventTime;
    if (t != null && RegExp(r'^\d{2}:\d{2}$').hasMatch(t)) {
      return DateTime(
        d.year,
        d.month,
        d.day,
        int.parse(t.substring(0, 2)),
        int.parse(t.substring(3, 5)),
      );
    }
    return DateTime(d.year, d.month, d.day);
  }

  /// Số ngày tới ngày diễn ra theo lịch (0 = hôm nay, âm = đã qua).
  int? daysUntil(DateTime now) {
    final d = DateTime.tryParse(eventDate);
    if (d == null) return null;
    final a = DateTime(d.year, d.month, d.day);
    final b = DateTime(now.year, now.month, now.day);
    return a.difference(b).inDays;
  }

  bool get isUpcoming => status == InviteState.upcoming;

  /// Còn phải mừng (không âm).
  int get remainingVnd => (plannedVnd - givenVnd).clamp(0, 1 << 62);

  Invitation copyWith({
    String? personName,
    Object? relationship = _keep,
    String? occasion,
    String? eventDate,
    Object? eventTime = _keep,
    Object? location = _keep,
    int? plannedVnd,
    int? givenVnd,
    String? status,
    Object? note = _keep,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? synced,
  }) => Invitation(
    id: id,
    personName: personName ?? this.personName,
    relationship: identical(relationship, _keep)
        ? this.relationship
        : relationship as String?,
    occasion: occasion ?? this.occasion,
    eventDate: eventDate ?? this.eventDate,
    eventTime: identical(eventTime, _keep) ? this.eventTime : eventTime as String?,
    location: identical(location, _keep) ? this.location : location as String?,
    plannedVnd: plannedVnd ?? this.plannedVnd,
    givenVnd: givenVnd ?? this.givenVnd,
    status: status ?? this.status,
    note: identical(note, _keep) ? this.note : note as String?,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
    deletedAt: deletedAt ?? this.deletedAt,
    synced: synced ?? false,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'person_name': personName,
    'relationship': relationship,
    'occasion': occasion,
    'event_date': eventDate,
    'event_time': eventTime,
    'location': location,
    'planned_vnd': plannedVnd,
    'given_vnd': givenVnd,
    'status': status,
    'note': note,
    'search_key': TextUtils.fold(
      '$personName ${relationship ?? ''} ${location ?? ''}',
    ),
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'deleted_at': deletedAt?.millisecondsSinceEpoch,
    'synced': synced ? 1 : 0,
  };

  factory Invitation.fromMap(Map<String, Object?> m) => Invitation(
    id: m['id'] as String,
    personName: (m['person_name'] as String?) ?? '',
    relationship: m['relationship'] as String?,
    occasion: (m['occasion'] as String?) ?? 'wedding',
    eventDate: m['event_date'] as String,
    eventTime: m['event_time'] as String?,
    location: m['location'] as String?,
    plannedVnd: (m['planned_vnd'] as int?) ?? 0,
    givenVnd: (m['given_vnd'] as int?) ?? 0,
    status: InviteState.normalize(m['status'] as String?),
    note: m['note'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
    deletedAt: m['deleted_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['deleted_at'] as int),
    synced: (m['synced'] as int? ?? 0) == 1,
  );

  /// Body `PUT /v1/invitations/:id`.
  Map<String, Object?> toApi() => {
    'person_name': personName,
    'relationship': relationship,
    'occasion': occasion,
    'event_date': eventDate,
    'event_time': eventTime,
    'location': location,
    'planned_vnd': plannedVnd,
    'given_vnd': givenVnd,
    'status': status,
    'note': note,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory Invitation.fromApi(Map<String, dynamic> j) => Invitation(
    id: j['id'] as String,
    personName: (j['person_name'] as String?) ?? '',
    relationship: j['relationship'] as String?,
    occasion: (j['occasion'] as String?) ?? 'wedding',
    eventDate: j['event_date'] as String,
    eventTime: j['event_time'] as String?,
    location: j['location'] as String?,
    plannedVnd: (j['planned_vnd'] as num?)?.toInt() ?? 0,
    givenVnd: (j['given_vnd'] as num?)?.toInt() ?? 0,
    status: InviteState.normalize(j['status'] as String?),
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

/// Phân tích lịch đi mừng (tính cục bộ).
class InvitationStats {
  InvitationStats({
    required this.upcomingCount,
    required this.upcomingPlannedVnd,
    required this.next30PlannedVnd,
    required this.next30Count,
    required this.attendedCount,
    required this.givenTotalVnd,
    required this.byMonth,
    this.next,
  });

  final int upcomingCount;

  /// Tổng dự chi của các lời mời SẮP TỚI.
  final int upcomingPlannedVnd;

  /// Dự chi trong 30 ngày tới.
  final int next30PlannedVnd;
  final int next30Count;
  final int attendedCount;

  /// Tổng đã mừng thực tế.
  final int givenTotalVnd;

  /// "yyyy-MM" -> tổng dự chi của các lời mời sắp tới trong tháng đó (sắp theo tháng).
  final Map<String, int> byMonth;

  /// Lời mời sắp tới gần nhất (từ hôm nay trở đi).
  final Invitation? next;

  int get averageGivenVnd =>
      attendedCount == 0 ? 0 : (givenTotalVnd / attendedCount).round();

  static InvitationStats compute(List<Invitation> all, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = all
        .where((i) => i.isUpcoming && (i.daysUntil(now) ?? -1) >= 0)
        .toList()
      ..sort((a, b) => (a.when ?? today).compareTo(b.when ?? today));
    var planned = 0;
    var n30 = 0;
    var c30 = 0;
    final months = <String, int>{};
    for (final i in upcoming) {
      planned += i.plannedVnd;
      final d = i.daysUntil(now)!;
      if (d <= 30) {
        n30 += i.plannedVnd;
        c30++;
      }
      final key = i.eventDate.substring(0, 7);
      months[key] = (months[key] ?? 0) + i.plannedVnd;
    }
    final attended = all.where((i) => i.status == InviteState.attended);
    var given = 0;
    var cnt = 0;
    for (final i in attended) {
      given += i.givenVnd;
      cnt++;
    }
    final sorted = Map.fromEntries(
      months.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return InvitationStats(
      upcomingCount: upcoming.length,
      upcomingPlannedVnd: planned,
      next30PlannedVnd: n30,
      next30Count: c30,
      attendedCount: cnt,
      givenTotalVnd: given,
      byMonth: sorted,
      next: upcoming.isEmpty ? null : upcoming.first,
    );
  }
}
