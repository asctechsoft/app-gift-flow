/// Sự kiện (đám cưới, lễ ăn hỏi...). Tiền mừng luôn thuộc đúng 1 sự kiện.
class GiftEvent {
  GiftEvent({
    required this.id,
    required this.name,
    this.type = 'wedding',
    required this.eventDate,
    this.location,
    this.status = 'active',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.synced = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;

  /// wedding | engagement | housewarming | other
  final String type;

  /// yyyy-MM-dd
  final String eventDate;
  final String? location;

  /// active | closed
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool synced;

  bool get isClosed => status == 'closed';

  GiftEvent copyWith({
    String? name,
    String? type,
    String? eventDate,
    String? location,
    String? status,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? synced,
  }) =>
      GiftEvent(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        eventDate: eventDate ?? this.eventDate,
        location: location ?? this.location,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        deletedAt: deletedAt ?? this.deletedAt,
        synced: synced ?? false,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'event_date': eventDate,
        'location': location,
        'status': status,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'deleted_at': deletedAt?.millisecondsSinceEpoch,
        'synced': synced ? 1 : 0,
      };

  factory GiftEvent.fromMap(Map<String, Object?> m) => GiftEvent(
        id: m['id'] as String,
        name: m['name'] as String,
        type: (m['type'] as String?) ?? 'wedding',
        eventDate: m['event_date'] as String,
        location: m['location'] as String?,
        status: (m['status'] as String?) ?? 'active',
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
        deletedAt: m['deleted_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['deleted_at'] as int),
        synced: (m['synced'] as int? ?? 0) == 1,
      );

  /// Body gửi lên backend (`PUT /v1/events/:id`).
  Map<String, Object?> toApi() => {
        'name': name,
        'type': type,
        'event_date': eventDate,
        'location': location,
        'status': status,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}
