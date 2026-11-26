import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

/// Singleton mở SQLite + chạy migration.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'gift_flow.db');
    return openDatabase(
      path,
      version: Schema.version,
      onUpgrade: (d, from, to) async {
        if (from < 2) await d.execute(Schema.migrateV2AddSide);
        if (from < 3) {
          await d.execute(Schema.migrateV3AddBudget);
          await d.execute(Schema.createPlanItems);
          await d.execute(Schema.idxPlanItems);
          await d.execute(Schema.createPlanGuests);
          await d.execute(Schema.idxPlanGuests);
        }
      },
      onCreate: (d, v) async {
        await d.execute(Schema.createEvents);
        await d.execute(Schema.createGifts);
        await d.execute(Schema.idxGiftsEvent);
        await d.execute(Schema.idxGiftsCreated);
        await d.execute(Schema.createPlanItems);
        await d.execute(Schema.idxPlanItems);
        await d.execute(Schema.createPlanGuests);
        await d.execute(Schema.idxPlanGuests);
        await d.execute(Schema.createOutbox);
        await d.execute(Schema.idxOutboxEntity);
      },
    );
  }

  Future<void> clearAll() async {
    final d = await db;
    await d.delete('gifts');
    await d.delete('plan_items');
    await d.delete('plan_guests');
    await d.delete('events');
    await d.delete('outbox');
  }
}
