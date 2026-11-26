import { MigrationInterface, QueryRunner } from 'typeorm';

/** Kế hoạch sự kiện: ngân sách (plan_items), khách mời dự kiến (plan_guests), events.budget_vnd. */
export class AddPlanning1730000000002 implements MigrationInterface {
  name = 'AddPlanning1730000000002';

  public async up(q: QueryRunner): Promise<void> {
    await q.query('ALTER TABLE events ADD COLUMN budget_vnd integer');
    await q.query(`
      CREATE TABLE plan_items (
        id varchar(36) PRIMARY KEY,
        event_id varchar(36) NOT NULL,
        owner_id varchar(36) NOT NULL,
        category varchar(30) NOT NULL,
        name varchar(200) NOT NULL,
        planned_vnd integer NOT NULL DEFAULT 0,
        paid_vnd integer NOT NULL DEFAULT 0,
        status varchar(12) NOT NULL DEFAULT 'planned',
        vendor varchar(200),
        due_date varchar(10),
        note varchar(1000),
        created_at timestamp NOT NULL,
        updated_at timestamp NOT NULL,
        deleted_at timestamp
      )`);
    await q.query('CREATE INDEX idx_plan_items_event ON plan_items (event_id, category)');
    await q.query(`
      CREATE TABLE plan_guests (
        id varchar(36) PRIMARY KEY,
        event_id varchar(36) NOT NULL,
        owner_id varchar(36) NOT NULL,
        name varchar(200) NOT NULL,
        relationship varchar(100),
        side varchar(10) NOT NULL DEFAULT 'mine',
        party_size integer NOT NULL DEFAULT 1,
        invite_status varchar(12) NOT NULL DEFAULT 'planned',
        phone varchar(30),
        note varchar(1000),
        search_key varchar(400) NOT NULL DEFAULT '',
        created_at timestamp NOT NULL,
        updated_at timestamp NOT NULL,
        deleted_at timestamp
      )`);
    await q.query('CREATE INDEX idx_plan_guests_event ON plan_guests (event_id, invite_status)');
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query('DROP TABLE plan_guests');
    await q.query('DROP TABLE plan_items');
    await q.query('ALTER TABLE events DROP COLUMN budget_vnd');
  }
}
