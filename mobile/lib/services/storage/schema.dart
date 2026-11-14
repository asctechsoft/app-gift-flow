/// Toàn bộ SQL tạo bảng / index / migration nằm ở đây.
class Schema {
  Schema._();

  static const int version = 2;

  static const String createEvents = '''
CREATE TABLE events (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'wedding',
  event_date TEXT NOT NULL,
  location TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  synced INTEGER NOT NULL DEFAULT 0
)''';

  static const String createGifts = '''
CREATE TABLE gifts (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  guest_name TEXT NOT NULL DEFAULT '',
  relationship TEXT,
  amount_vnd INTEGER NOT NULL DEFAULT 0,
  note TEXT,
  status TEXT NOT NULL,
  source TEXT NOT NULL,
  transcript TEXT,
  warnings TEXT,
  error_message TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  synced INTEGER NOT NULL DEFAULT 0,
  search_key TEXT NOT NULL DEFAULT '',
  side TEXT NOT NULL DEFAULT 'mine'
)''';

  static const String idxGiftsEvent =
      'CREATE INDEX idx_gifts_event_status ON gifts(event_id, status)';
  static const String idxGiftsCreated =
      'CREATE INDEX idx_gifts_created ON gifts(event_id, created_at DESC)';

  /// Hàng đợi đồng bộ (outbox): mọi thay đổi ghi local trước, đẩy lên sau.
  static const String createOutbox = '''
CREATE TABLE outbox (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  action TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT
)''';

  static const String migrateV2AddSide =
      "ALTER TABLE gifts ADD COLUMN side TEXT NOT NULL DEFAULT 'mine'";

  static const String idxOutboxEntity =
      'CREATE UNIQUE INDEX idx_outbox_entity ON outbox(entity, entity_id)';
}
