import 'package:sqflite/sqflite.dart';

import '../models/data_models/invitation.dart';
import '../services/storage/database_helper.dart';
import 'outbox_repository.dart';

/// Lịch đi mừng (local-first, đẩy lên server qua outbox entity `invitation`).
class InvitationRepository {
  InvitationRepository(this._outbox);

  final OutboxRepository _outbox;
  Future<Database> get _db => DatabaseHelper.instance.db;

  /// Chưa xoá, theo ngày giờ tăng dần.
  Future<List<Invitation>> all() async {
    final rows = await (await _db).query(
      'invitations',
      where: 'deleted_at IS NULL',
      orderBy: "event_date ASC, COALESCE(event_time, '') ASC, created_at ASC",
    );
    return rows.map(Invitation.fromMap).toList();
  }

  Future<void> save(Invitation i) async {
    final d = await _db;
    await d.transaction((txn) async {
      await txn.insert(
        'invitations',
        i.copyWith(synced: false).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _outbox.enqueue('invitation', i.id, 'upsert', txn: txn);
    });
  }

  Future<void> delete(String id) async {
    final d = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await d.transaction((txn) async {
      await txn.update(
        'invitations',
        {'deleted_at': now, 'updated_at': now, 'synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _outbox.enqueue('invitation', id, 'delete', txn: txn);
    });
  }

  Future<void> restore(String id) async {
    final d = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await d.transaction((txn) async {
      await txn.update(
        'invitations',
        {'deleted_at': null, 'updated_at': now, 'synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _outbox.enqueue('invitation', id, 'upsert', txn: txn);
    });
  }

  Future<Invitation?> getRaw(String id) async {
    final rows = await (await _db).query(
      'invitations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Invitation.fromMap(rows.first);
  }

  Future<void> markSynced(String id, DateTime updatedAt) async =>
      (await _db).update(
        'invitations',
        {'synced': 1},
        where: 'id = ? AND updated_at = ?',
        whereArgs: [id, updatedAt.millisecondsSinceEpoch],
      );

  Future<void> upsertFromServer(Invitation i) async {
    final cur = await getRaw(i.id);
    if (cur != null && cur.updatedAt.isAfter(i.updatedAt)) return;
    await (await _db).insert(
      'invitations',
      i.toMap()..['synced'] = 1,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
