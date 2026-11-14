import 'package:sqflite/sqflite.dart';

import '../models/data_models/gift_event.dart';
import '../services/storage/database_helper.dart';
import 'outbox_repository.dart';

class EventRepository {
  EventRepository(this._outbox);

  final OutboxRepository _outbox;
  Future<Database> get _db => DatabaseHelper.instance.db;

  Future<List<GiftEvent>> list() async {
    final rows = await (await _db).query(
      'events',
      where: 'deleted_at IS NULL',
      orderBy: 'event_date DESC, created_at DESC',
    );
    return rows.map(GiftEvent.fromMap).toList();
  }

  Future<GiftEvent?> get(String id) async {
    final rows = await (await _db).query(
      'events',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : GiftEvent.fromMap(rows.first);
  }

  /// Ghi local trước + xếp hàng đồng bộ trong cùng 1 transaction.
  Future<void> save(GiftEvent e) async {
    final d = await _db;
    await d.transaction((txn) async {
      await txn.insert(
        'events',
        e.copyWith(synced: false).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _outbox.enqueue('event', e.id, 'upsert', txn: txn);
    });
  }

  Future<void> softDelete(String id) async {
    final d = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await d.transaction((txn) async {
      await txn.update(
        'events',
        {'deleted_at': now, 'updated_at': now, 'synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _outbox.enqueue('event', id, 'delete', txn: txn);
    });
  }

  Future<void> markSynced(String id, DateTime updatedAt) async =>
      (await _db).update(
        'events',
        {'synced': 1},
        where: 'id = ? AND updated_at = ?',
        whereArgs: [id, updatedAt.millisecondsSinceEpoch],
      );

  /// Dữ liệu thô (kể cả đã xoá) để đẩy lên server.
  Future<GiftEvent?> getRaw(String id) async {
    final rows = await (await _db).query(
      'events',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : GiftEvent.fromMap(rows.first);
  }

  /// Upsert từ server (khôi phục) - KHÔNG xếp hàng đồng bộ lại.
  Future<void> upsertFromServer(GiftEvent e) async {
    final d = await _db;
    final cur = await getRaw(e.id);
    if (cur != null && cur.updatedAt.isAfter(e.updatedAt)) return;
    await d.insert(
      'events',
      e.copyWith(updatedAt: e.updatedAt, synced: true).toMap()
        ..['synced'] = 1
        ..['updated_at'] = e.updatedAt.millisecondsSinceEpoch,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
