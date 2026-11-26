/// Toàn bộ SQL tạo bảng / index / migration nằm ở đây.
class Schema {
  Schema._();

  static const int version = 4;

  static const String createEvents = '''
CREATE TABLE events (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'wedding',
  event_date TEXT NOT NULL,
  location TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  budget_vnd INTEGER,
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

  /// v3: kế hoạch sự kiện - ngân sách tổng, khoản chi, khách mời dự kiến.
  static const String migrateV3AddBudget =
      'ALTER TABLE events ADD COLUMN budget_vnd INTEGER';

  static const String createPlanItems = '''
CREATE TABLE plan_items (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  category TEXT NOT NULL,
  name TEXT NOT NULL,
  planned_vnd INTEGER NOT NULL DEFAULT 0,
  paid_vnd INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'planned',
  vendor TEXT,
  due_date TEXT,
  note TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  synced INTEGER NOT NULL DEFAULT 0
)''';

  static const String idxPlanItems =
      'CREATE INDEX idx_plan_items_event ON plan_items(event_id, category)';

  static const String createPlanGuests = '''
CREATE TABLE plan_guests (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  name TEXT NOT NULL,
  relationship TEXT,
  side TEXT NOT NULL DEFAULT 'mine',
  party_size INTEGER NOT NULL DEFAULT 1,
  invite_status TEXT NOT NULL DEFAULT 'planned',
  phone TEXT,
  note TEXT,
  search_key TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  synced INTEGER NOT NULL DEFAULT 0
)''';

  static const String idxPlanGuests =
      'CREATE INDEX idx_plan_guests_event ON plan_guests(event_id, invite_status)';

  /// v4: lịch đi mừng (sự kiện của người khác mình được mời).
  static const String createInvitations = '''
CREATE TABLE invitations (
  id TEXT PRIMARY KEY,
  person_name TEXT NOT NULL,
  relationship TEXT,
  occasion TEXT NOT NULL DEFAULT 'wedding',
  event_date TEXT NOT NULL,
  event_time TEXT,
  location TEXT,
  planned_vnd INTEGER NOT NULL DEFAULT 0,
  given_vnd INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'upcoming',
  note TEXT,
  search_key TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  synced INTEGER NOT NULL DEFAULT 0
)''';

  static const String idxInvitations =
      'CREATE INDEX idx_invitations_date ON invitations(event_date)';

  static const String idxOutboxEntity =
      'CREATE UNIQUE INDEX idx_outbox_entity ON outbox(entity, entity_id)';
}
