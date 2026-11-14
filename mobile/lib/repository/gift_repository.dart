import 'package:sqflite/sqflite.dart';

import '../configs/app_config.dart';
import '../models/data_models/gift_record.dart';
import '../models/ui_models/gift_status.dart';
import '../services/storage/database_helper.dart';
import '../utils/text_utils.dart';
import 'outbox_repository.dart';

class RelationshipStat {
  RelationshipStat(this.label, this.count, this.totalVnd);
  final String label;
  final int count;
  final int totalVnd;
}

class GuestStat {
  GuestStat(this.name, this.totalVnd, this.count);
  final String name;
  final int totalVnd;
  final int count;
}

class SideStat {
  SideStat(this.side, this.count, this.totalVnd);
  final String side;
  final int count;
  final int totalVnd;
}

class EventStats {
  EventStats({
    required this.totalVnd,
    required this.envelopes,
    required this.guests,
    required this.pendingCount,
    required this.pendingVnd,
    required this.byRelationship,
    this.bySide = const [],
    this.topGuests = const [],
  });

  /// BR10: SUM(amount) của confirmed, chưa xoá.
  final int totalVnd;
  final int envelopes;
  final int guests;
  final int pendingCount;
  final int pendingVnd;
  final List<RelationshipStat> byRelationship;
  final List<SideStat> bySide;

  /// Khách mừng nhiều nhất (cộng dồn theo tên, chỉ confirmed).
  final List<GuestStat> topGuests;

  static EventStats empty() => EventStats(
    totalVnd: 0,
    envelopes: 0,
    guests: 0,
    pendingCount: 0,
    pendingVnd: 0,
    byRelationship: const [],
  );
}

class GiftRepository {
  GiftRepository(this._outbox);

  final OutboxRepository _outbox;
  Future<Database> get _db => DatabaseHelper.instance.db;

  Future<void> save(GiftRecord g, {bool enqueue = true}) async {
    final d = await _db;
    await d.transaction((txn) async {
      await txn.insert(
        'gifts',
        g.copyWith(synced: false, updatedAt: g.updatedAt).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (enqueue) await _outbox.enqueue('gift', g.id, 'upsert', txn: txn);
    });
  }

  Future<GiftRecord?> get(String id) async {
    final rows = await (await _db).query(
      'gifts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : GiftRecord.fromMap(rows.first);
  }

  /// BR09: xoá mềm + xếp hàng đồng bộ.
  Future<void> softDelete(String id) async {
    final d = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await d.transaction((txn) async {
      await txn.update(
        'gifts',
        {'deleted_at': now, 'updated_at': now, 'synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _outbox.enqueue('gift', id, 'delete', txn: txn);
    });
  }

  /// Hoàn tác xoá mềm (trong thời gian ngắn).
  Future<void> restore(String id) async {
    final d = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await d.transaction((txn) async {
      await txn.update(
        'gifts',
        {'deleted_at': null, 'updated_at': now, 'synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _outbox.enqueue('gift', id, 'upsert', txn: txn);
    });
  }

  Future<void> markSynced(String id, DateTime updatedAt) async =>
      (await _db).update(
        'gifts',
        {'synced': 1},
        where: 'id = ? AND updated_at = ?',
        whereArgs: [id, updatedAt.millisecondsSinceEpoch],
      );

  /// Danh sách (không gồm đã xoá). [status]: null = tất cả.
  Future<List<GiftRecord>> list(
    String eventId, {
    String query = '',
    String? relationship,
    String? side,
    List<GiftStatus>? statuses,
    int limit = 500,
    int offset = 0,
  }) async {
    final where = <String>['event_id = ?', 'deleted_at IS NULL'];
    final args = <Object?>[eventId];
    final q = TextUtils.fold(query);
    if (q.isNotEmpty) {
      where.add('search_key LIKE ?');
      args.add('%$q%');
    }
    if (relationship != null) {
      if (relationship.isEmpty) {
        where.add("(relationship IS NULL OR TRIM(relationship) = '')");
      } else {
        where.add('relationship = ?');
        args.add(relationship);
      }
    }
    if (side != null) {
      where.add('side = ?');
      args.add(side);
    }
    if (statuses != null && statuses.isNotEmpty) {
      where.add('status IN (${statuses.map((_) => '?').join(',')})');
      args.addAll(statuses.map((s) => s.wire));
    }
    final rows = await (await _db).query(
      'gifts',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(GiftRecord.fromMap).toList();
  }

  Future<List<GiftRecord>> forExport(
    String eventId, {
    DateTime? from,
    DateTime? to,
    String? side,
    required bool includePending,
  }) async {
    final where = <String>['event_id = ?', 'deleted_at IS NULL'];
    final args = <Object?>[eventId];
    if (!includePending) {
      where.add("status = 'confirmed'");
    } else {
      where.add("status IN ('confirmed','pending_review')");
    }
    if (side != null) {
      where.add('side = ?');
      args.add(side);
    }
    if (from != null) {
      where.add('created_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('created_at < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    final rows = await (await _db).query(
      'gifts',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at ASC, id ASC',
    );
    return rows.map(GiftRecord.fromMap).toList();
  }

  /// Nhóm quan hệ đang có (cho chip lọc), kèm số lượng.
  Future<List<RelationshipStat>> relationshipCounts(
    String eventId, {
    String? side,
  }) async {
    final rows = await (await _db).rawQuery(
      '''SELECT COALESCE(NULLIF(TRIM(relationship), ''), '') AS rel,
                COUNT(*) AS c, COALESCE(SUM(amount_vnd),0) AS s
         FROM gifts
         WHERE event_id = ? AND deleted_at IS NULL
           AND status IN ('confirmed','pending_review')
           ${side != null ? 'AND side = ?' : ''}
         GROUP BY rel ORDER BY c DESC''',
      [eventId, if (side != null) side],
    );
    return rows
        .map(
          (r) => RelationshipStat(
            r['rel'] as String,
            r['c'] as int,
            (r['s'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  Future<EventStats> stats(String eventId) async {
    final d = await _db;
    final conf = await d.rawQuery(
      '''SELECT COUNT(*) c, COALESCE(SUM(amount_vnd),0) s,
                COUNT(DISTINCT LOWER(TRIM(guest_name))) g
         FROM gifts
         WHERE event_id = ? AND deleted_at IS NULL AND status = 'confirmed' ''',
      [eventId],
    );
    final pend = await d.rawQuery(
      '''SELECT COUNT(*) c, COALESCE(SUM(amount_vnd),0) s
         FROM gifts
         WHERE event_id = ? AND deleted_at IS NULL AND status = 'pending_review' ''',
      [eventId],
    );
    final rel = await d.rawQuery(
      '''SELECT COALESCE(NULLIF(TRIM(relationship), ''), '') AS rel,
                COUNT(*) AS c, COALESCE(SUM(amount_vnd),0) AS s
         FROM gifts
         WHERE event_id = ? AND deleted_at IS NULL AND status = 'confirmed'
         GROUP BY rel ORDER BY s DESC''',
      [eventId],
    );
    final sides = await d.rawQuery(
      '''SELECT side, COUNT(*) AS c, COALESCE(SUM(amount_vnd),0) AS s
         FROM gifts
         WHERE event_id = ? AND deleted_at IS NULL AND status = 'confirmed'
         GROUP BY side''',
      [eventId],
    );
    final top = await d.rawQuery(
      '''SELECT MIN(TRIM(guest_name)) AS n, COUNT(*) AS c, COALESCE(SUM(amount_vnd),0) AS s
         FROM gifts
         WHERE event_id = ? AND deleted_at IS NULL AND status = 'confirmed'
               AND TRIM(guest_name) <> ''
         GROUP BY LOWER(TRIM(guest_name)) ORDER BY s DESC LIMIT 5''',
      [eventId],
    );
    return EventStats(
      topGuests: top
          .map((r) => GuestStat(r['n'] as String, (r['s'] as int?) ?? 0, r['c'] as int))
          .toList(),
      bySide: sides
          .map(
            (r) => SideStat(
              GiftSide.normalize(r['side'] as String?),
              r['c'] as int,
              (r['s'] as int?) ?? 0,
            ),
          )
          .toList(),
      totalVnd: (conf.first['s'] as int?) ?? 0,
      envelopes: (conf.first['c'] as int?) ?? 0,
      guests: (conf.first['g'] as int?) ?? 0,
      pendingCount: (pend.first['c'] as int?) ?? 0,
      pendingVnd: (pend.first['s'] as int?) ?? 0,
      byRelationship: rel
          .map(
            (r) => RelationshipStat(
              r['rel'] as String,
              r['c'] as int,
              (r['s'] as int?) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// BR06: cùng event + tên + số tiền trong ngưỡng thời gian.
  Future<List<GiftRecord>> findDuplicates(
    String eventId,
    String guestName,
    int amountVnd, {
    String? excludeId,
  }) async {
    final since = DateTime.now()
        .subtract(AppConfig.duplicateWindow)
        .millisecondsSinceEpoch;
    final rows = await (await _db).query(
      'gifts',
      where:
          'event_id = ? AND deleted_at IS NULL AND amount_vnd = ? '
          'AND created_at >= ? AND status IN (\'confirmed\',\'pending_review\')'
          '${excludeId != null ? ' AND id != ?' : ''}',
      whereArgs: [
        eventId,
        amountVnd,
        since,
        if (excludeId != null) excludeId,
      ],
    );
    final key = TextUtils.fold(guestName);
    return rows
        .map(GiftRecord.fromMap)
        .where((g) => TextUtils.fold(g.guestName) == key && key.isNotEmpty)
        .toList();
  }

  /// Upsert từ server (khôi phục) - không xếp hàng đồng bộ lại.
  Future<void> upsertFromServer(GiftRecord g) async {
    final d = await _db;
    final cur = await get(g.id);
    if (cur != null && cur.updatedAt.isAfter(g.updatedAt)) return;
    final m = g.toMap()
      ..['synced'] = 1
      ..['updated_at'] = g.updatedAt.millisecondsSinceEpoch;
    await d.insert('gifts', m, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<GiftRecord?> getRaw(String id) => get(id);
}
