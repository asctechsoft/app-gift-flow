// Nâng cấp DB đang có trên máy người dùng (v2 -> v3): dữ liệu cũ phải còn nguyên,
// có thêm cột ngân sách + bảng kế hoạch. Dùng SQLite thật qua ffi.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gift_flow/models/data_models/plan_models.dart';
import 'package:gift_flow/repository/outbox_repository.dart';
import 'package:gift_flow/repository/plan_repository.dart';
import 'package:gift_flow/services/storage/database_helper.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v2 -> v3: giữ nguyên sự kiện/phong bì cũ, thêm kế hoạch', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = Directory.systemTemp.createTempSync('giftflow_mig');
    await databaseFactory.setDatabasesPath(dir.path);
    final path = p.join(dir.path, 'gift_flow.db');

    // --- dựng DB phiên bản 2 đúng như bản app trước (không có budget_vnd, không có bảng kế hoạch)
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (d, v) async {
          await d.execute('''CREATE TABLE events (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL DEFAULT 'wedding',
  event_date TEXT NOT NULL, location TEXT, status TEXT NOT NULL DEFAULT 'active',
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER,
  synced INTEGER NOT NULL DEFAULT 0)''');
          await d.execute('''CREATE TABLE gifts (
  id TEXT PRIMARY KEY, event_id TEXT NOT NULL, guest_name TEXT NOT NULL DEFAULT '',
  relationship TEXT, amount_vnd INTEGER NOT NULL DEFAULT 0, note TEXT, status TEXT NOT NULL,
  source TEXT NOT NULL, transcript TEXT, warnings TEXT, error_message TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER,
  synced INTEGER NOT NULL DEFAULT 0, search_key TEXT NOT NULL DEFAULT '', side TEXT NOT NULL DEFAULT 'mine')''');
          await d.execute('''CREATE TABLE outbox (
  id INTEGER PRIMARY KEY AUTOINCREMENT, entity TEXT NOT NULL, entity_id TEXT NOT NULL,
  action TEXT NOT NULL, created_at INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, last_error TEXT)''');
          await d.execute('CREATE UNIQUE INDEX idx_outbox_entity ON outbox(entity, entity_id)');
        },
      ),
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await old.insert('events', {
      'id': 'e1', 'name': 'Đám cưới cũ', 'type': 'wedding', 'event_date': '2026-05-24',
      'status': 'active', 'created_at': now, 'updated_at': now, 'synced': 1,
    });
    await old.insert('gifts', {
      'id': 'g1', 'event_id': 'e1', 'guest_name': 'Anh Long', 'amount_vnd': 2000000,
      'status': 'confirmed', 'source': 'voice', 'created_at': now, 'updated_at': now,
      'synced': 1, 'search_key': 'anh long', 'side': 'parents',
    });
    await old.close();

    // --- mở bằng DatabaseHelper (schema mới v3) -> chạy onUpgrade
    final db = await DatabaseHelper.instance.db;
    expect(await db.getVersion(), 3);
    final ev = await db.query('events');
    expect(ev.single['name'], 'Đám cưới cũ');
    expect(ev.single.containsKey('budget_vnd'), isTrue);
    expect(ev.single['budget_vnd'], isNull);
    final g = await db.query('gifts');
    expect(g.single['guest_name'], 'Anh Long');
    expect(g.single['amount_vnd'], 2000000);
    expect(g.single['side'], 'parents');

    // bảng kế hoạch dùng được ngay
    final repo = PlanRepository(OutboxRepository());
    await repo.saveItem(
      PlanItem(id: 'i1', eventId: 'e1', category: 'venue', name: 'Nhà hàng', plannedVnd: 1000),
    );
    await repo.saveGuest(PlanGuest(id: 'pg1', eventId: 'e1', name: 'Chị Mai', partySize: 2));
    expect((await repo.items('e1')).single.name, 'Nhà hàng');
    expect((await repo.guests('e1')).single.partySize, 2);
    // lưu ngân sách vào cột mới
    await db.update('events', {'budget_vnd': 300000000}, where: 'id = ?', whereArgs: ['e1']);
    expect((await db.query('events')).single['budget_vnd'], 300000000);
    // hàng đợi đồng bộ có cả mục kế hoạch
    final ob = await db.query('outbox');
    expect(ob.map((r) => r['entity']).toSet(), containsAll(['plan_item', 'plan_guest']));
  });
}
