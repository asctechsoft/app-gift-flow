import 'package:sqflite/sqflite.dart';

import '../models/data_models/plan_models.dart';
import '../services/storage/database_helper.dart';
import '../utils/text_utils.dart';
import 'outbox_repository.dart';

/// Khoản chi + khách mời dự kiến. Local-first, đẩy lên server qua outbox
/// (entity `plan_item` / `plan_guest`).
class PlanRepository {
  PlanRepository(this._outbox);

  final OutboxRepository _outbox;
  Future<Database> get _db => DatabaseHelper.instance.db;

  // ------------------------------------------------------------- khoản chi

  Future<List<PlanItem>> items(String eventId) async {
    final rows = await (await _db).query(
      'plan_items',
      where: 'event_id = ? AND deleted_at IS NULL',
      whereArgs: [eventId],
      orderBy: 'category ASC, created_at ASC',
    );
    return rows.map(PlanItem.fromMap).toList();
  }

  Future<void> saveItem(PlanItem i, {bool enqueue = true}) async {
    final d = await _db;
    await d.transaction((txn) async {
      await txn.insert(
        'plan_items',
        i.copyWith(synced: false).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (enqueue) await _outbox.enqueue('plan_item', i.id, 'upsert', txn: txn);
    });
  }

  /// Thêm nhiều khoản cùng lúc (mẫu kế hoạch) trong một transaction.
  Future<void> saveItems(List<PlanItem> list) async {
    final d = await _db;
    await d.transaction((txn) async {
      for (final i in list) {
        await txn.insert(
          'plan_items',
          i.copyWith(synced: false).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _outbox.enqueue('plan_item', i.id, 'upsert', txn: txn);
      }
    });
  }

  Future<void> deleteItem(String id) async {
    final d = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await d.transaction((txn) async {
      await txn.update(
        'plan_items',
        {'deleted_at': now, 'updated_at': now, 'synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _outbox.enqueue('plan_item', id, 'delete', txn: txn);
    });
  }

  Future<void> restoreItem(String id) async {
    final d = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await d.transaction((txn) async {
      await txn.update(
        'plan_items',
        {'deleted_at': null, 'updated_at': now, 'synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _outbox.enqueue('plan_item', id, 'upsert', txn: txn);
    });
  }

  Future<PlanItem?> getItemRaw(String id) async {
    final rows = await (await _db).query(
      'plan_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : PlanItem.fromMap(rows.first);
  }

  Future<void> markItemSynced(String id, DateTime updatedAt) async =>
      (await _db).update(
        'plan_items',
        {'synced': 1},
        where: 'id = ? AND updated_at = ?',
        whereArgs: [id, updatedAt.millisecondsSinceEpoch],
      );

  Future<void> upsertItemFromServer(PlanItem i) async {
    final cur = await getItemRaw(i.id);
    if (cur != null && cur.updatedAt.isAfter(i.updatedAt)) return;
    await (await _db).insert(
      'plan_items',
      i.toMap()..['synced'] = 1,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ------------------------------------------------------------------ khách

  Future<List<PlanGuest>> guests(
    String eventId, {
    String query = '',
    String? side,
    String? status,
  }) async {
    final where = <String>['event_id = ?', 'deleted_at IS NULL'];
    final args = <Object?>[eventId];
    final q = TextUtils.fold(query);
    if (q.isNotEmpty) {
      where.add('search_key LIKE ?');
      args.add('%$q%');
    }
    if (side != null) {
      where.add('side = ?');
      args.add(side);
    }
    if (status != null) {
      where.add('invite_status = ?');
      args.add(status);
    }
    final rows = await (await _db).query(
      'plan_guests',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(PlanGuest.fromMap).toList();
  }

  Future<void> saveGuest(PlanGuest g) async {
    final d = await _db;
    await d.transaction((txn) async {
      await txn.insert(
        'plan_guests',
        g.copyWith(synced: false).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _outbox.enqueue('plan_guest', g.id, 'upsert', txn: txn);
    });
  }

  Future<void> saveGuests(List<PlanGuest> list) async {
    final d = await _db;
    await d.transaction((txn) async {
      for (final g in list) {
        await txn.insert(
          'plan_guests',
          g.copyWith(synced: false).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _outbox.enqueue('plan_guest', g.id, 'upsert', txn: txn);
      }
    });
  }

  Future<void> deleteGuest(String id) async {
    final d = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await d.transaction((txn) async {
      await txn.update(
        'plan_guests',
        {'deleted_at': now, 'updated_at': now, 'synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _outbox.enqueue('plan_guest', id, 'delete', txn: txn);
    });
  }

  Future<void> restoreGuest(String id) async {
    final d = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await d.transaction((txn) async {
      await txn.update(
        'plan_guests',
        {'deleted_at': null, 'updated_at': now, 'synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _outbox.enqueue('plan_guest', id, 'upsert', txn: txn);
    });
  }

  Future<PlanGuest?> getGuestRaw(String id) async {
    final rows = await (await _db).query(
      'plan_guests',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : PlanGuest.fromMap(rows.first);
  }

  Future<void> markGuestSynced(String id, DateTime updatedAt) async =>
      (await _db).update(
        'plan_guests',
        {'synced': 1},
        where: 'id = ? AND updated_at = ?',
        whereArgs: [id, updatedAt.millisecondsSinceEpoch],
      );

  Future<void> upsertGuestFromServer(PlanGuest g) async {
    final cur = await getGuestRaw(g.id);
    if (cur != null && cur.updatedAt.isAfter(g.updatedAt)) return;
    await (await _db).insert(
      'plan_guests',
      g.toMap()..['synced'] = 1,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
