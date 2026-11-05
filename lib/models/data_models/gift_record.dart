import 'dart:convert';

import '../../utils/text_utils.dart';
import '../ui_models/gift_status.dart';

/// Một phong bì tiền mừng. `id` cũng là `client_request_id` (UUID sinh ở app)
/// để backend upsert idempotent (BR07).
class GiftRecord {
  GiftRecord({
    required this.id,
    required this.eventId,
    this.guestName = '',
    this.relationship,
    this.amountVnd = 0,
    this.note,
    this.status = GiftStatus.confirmed,
    this.side = GiftSide.mine,
    this.source = GiftSource.manual,
    this.transcript,
    this.warnings = const [],
    this.errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.synced = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String eventId;
  final String guestName;
  final String? relationship;
  final int amountVnd;
  final String? note;
  final GiftStatus status;
  final String side;
  final GiftSource source;
  final String? transcript;
  final List<String> warnings;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool synced;

  bool get isDeleted => deletedAt != null;
  bool get isConfirmed => status == GiftStatus.confirmed && !isDeleted;
  bool get hasDuplicateWarning => warnings.contains('possible_duplicate');

  GiftRecord copyWith({
    String? guestName,
    Object? relationship = _keep,
    int? amountVnd,
    Object? note = _keep,
    GiftStatus? status,
    String? side,
    String? transcript,
    List<String>? warnings,
    Object? errorMessage = _keep,
    DateTime? updatedAt,
    Object? deletedAt = _keep,
    bool? synced,
  }) => GiftRecord(
    id: id,
    eventId: eventId,
    guestName: guestName ?? this.guestName,
    relationship: identical(relationship, _keep)
        ? this.relationship
        : relationship as String?,
    amountVnd: amountVnd ?? this.amountVnd,
    note: identical(note, _keep) ? this.note : note as String?,
    status: status ?? this.status,
    side: side ?? this.side,
    source: source,
    transcript: transcript ?? this.transcript,
    warnings: warnings ?? this.warnings,
    errorMessage: identical(errorMessage, _keep)
        ? this.errorMessage
        : errorMessage as String?,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
    deletedAt: identical(deletedAt, _keep)
        ? this.deletedAt
        : deletedAt as DateTime?,
    synced: synced ?? false,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'event_id': eventId,
    'guest_name': guestName,
    'relationship': relationship,
    'amount_vnd': amountVnd,
    'note': note,
    'status': status.wire,
    'side': side,
    'source': source.wire,
    'transcript': transcript,
    'warnings': jsonEncode(warnings),
    'error_message': errorMessage,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'deleted_at': deletedAt?.millisecondsSinceEpoch,
    'synced': synced ? 1 : 0,
    // Cột tìm kiếm không dấu (BR: search chuẩn hoá Unicode tiếng Việt).
    'search_key': TextUtils.fold(
      '$guestName ${relationship ?? ''} ${note ?? ''}',
    ),
  };

  factory GiftRecord.fromMap(Map<String, Object?> m) {
    List<String> warns = const [];
    try {
      final w = m['warnings'] as String?;
      if (w != null && w.isNotEmpty) {
        warns = (jsonDecode(w) as List).cast<String>();
      }
    } catch (_) {}
    return GiftRecord(
      id: m['id'] as String,
      eventId: m['event_id'] as String,
      guestName: (m['guest_name'] as String?) ?? '',
      relationship: m['relationship'] as String?,
      amountVnd: (m['amount_vnd'] as int?) ?? 0,
      note: m['note'] as String?,
      status: GiftStatus.fromWire(m['status'] as String?),
      side: GiftSide.normalize(m['side'] as String?),
      source: GiftSource.fromWire(m['source'] as String?),
      transcript: m['transcript'] as String?,
      warnings: warns,
      errorMessage: m['error_message'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
      deletedAt: m['deleted_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(m['deleted_at'] as int),
      synced: (m['synced'] as int? ?? 0) == 1,
    );
  }

  /// Body gửi lên backend (`PUT /v1/gifts/:id`).
  Map<String, Object?> toApi() => {
    'event_id': eventId,
    'guest_name': guestName,
    'relationship_label': relationship,
    'amount_vnd': amountVnd,
    'note': note,
    'status': status.wire,
    'side': side,
    'source': source.wire,
    'transcript': transcript,
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

const Object _keep = Object();
