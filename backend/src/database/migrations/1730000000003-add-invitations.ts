import { MigrationInterface, QueryRunner } from 'typeorm';

/** Lịch đi mừng: sự kiện của người khác mà mình được mời (ngày giờ, dự chi, đã mừng). */
export class AddInvitations1730000000003 implements MigrationInterface {
  name = 'AddInvitations1730000000003';

  public async up(q: QueryRunner): Promise<void> {
    await q.query(`
      CREATE TABLE invitations (
        id varchar(36) PRIMARY KEY,
        owner_id varchar(36) NOT NULL,
        person_name varchar(200) NOT NULL,
        relationship varchar(100),
        occasion varchar(30) NOT NULL DEFAULT 'wedding',
        event_date varchar(10) NOT NULL,
        event_time varchar(5),
        location varchar(300),
        planned_vnd integer NOT NULL DEFAULT 0,
        given_vnd integer NOT NULL DEFAULT 0,
        status varchar(12) NOT NULL DEFAULT 'upcoming',
        note varchar(1000),
        search_key varchar(400) NOT NULL DEFAULT '',
        created_at timestamp NOT NULL,
        updated_at timestamp NOT NULL,
        deleted_at timestamp
      )`);
    await q.query('CREATE INDEX idx_invitations_owner_date ON invitations (owner_id, event_date)');
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query('DROP TABLE invitations');
  }
}
