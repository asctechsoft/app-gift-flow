import 'package:sqflite/sqflite.dart';

import '../services/storage/database_helper.dart';

class OutboxItem {
  OutboxItem({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.action,
    required this.attempts,
  });

  final int id;
  final String entity; // event | gift
  final String entityId;
  final String action; // upsert | delete
  final int attempts;
}

/// Hàng đợi đồng bộ - mỗi (entity, id) chỉ có tối đa 1 dòng (trạng thái cuối).
class OutboxRepository {
  Future<Database> get _db => DatabaseHelper.instance.db;

  Future<void> enqueue(
    String entity,
    String entityId,
    String action, {
    DatabaseExecutor? txn,
  }) async {
    final ex = txn ?? await _db;
    await ex.insert(
        'outbox',
        {
          'entity': entity,
          'entity_id': entityId,
          'action': action,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'attempts': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Sự kiện đẩy trước (gift tham chiếu event), rồi theo thứ tự thời gian.
  Future<List<OutboxItem>> pending(
      {int limit = 50, int maxAttempts = 6}) async {
    final rows = await (await _db).query(
      'outbox',
      where: 'attempts < ?',
      whereArgs: [maxAttempts],
      orderBy: "CASE entity WHEN 'event' THEN 0 ELSE 1 END, id ASC",
      limit: limit,
    );
    return rows
        .map(
          (r) => OutboxItem(
            id: r['id'] as int,
            entity: r['entity'] as String,
            entityId: r['entity_id'] as String,
            action: r['action'] as String,
            attempts: r['attempts'] as int,
          ),
        )
        .toList();
  }

  Future<int> count() async {
    final r = await (await _db).rawQuery('SELECT COUNT(*) c FROM outbox');
    return (r.first['c'] as int?) ?? 0;
  }

  Future<void> remove(int id) async =>
      (await _db).delete('outbox', where: 'id = ?', whereArgs: [id]);

  Future<void> markFailed(int id, String error) async => (await _db).rawUpdate(
        'UPDATE outbox SET attempts = attempts + 1, last_error = ? WHERE id = ?',
        [error, id],
      );

  /// Cho phép thử lại những dòng đã vượt ngưỡng (nút "Đồng bộ ngay").
  Future<void> resetAttempts() async =>
      (await _db).update('outbox', {'attempts': 0});
}
