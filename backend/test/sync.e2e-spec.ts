import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { randomUUID } from 'crypto';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/app.setup';
import { loadConfig } from '../src/config/config';
import { GoogleTokenVerifier } from '../src/modules/auth/google-verifier';

describe('Đồng bộ tài khoản Google + Lịch đi mừng (e2e)', () => {
  let app: INestApplication;
  let http: any;

  beforeAll(async () => {
    process.env.THROTTLE_GUEST_LIMIT = '1000';
    const cfg = loadConfig({
      NODE_ENV: 'test',
      DB_TYPE: 'sqljs',
      SQLJS_FILE: ':memory:',
      JWT_ACCESS_SECRET: 'sync-secret-sync-secret-sync-secret-1234',
      AI_PROVIDER: 'mock',
      THROTTLE_LIMIT: '10000',
      NEW_GUESTS_PER_IP_PER_DAY: '100000',
    } as NodeJS.ProcessEnv);
    const mod = await Test.createTestingModule({ imports: [AppModule.forRoot(cfg)] })
      .overrideProvider(GoogleTokenVerifier)
      .useValue({ verify: async (t: string) => ({ sub: 'sub-' + t.slice(0, 12), email: t.slice(0, 6) + '@x.com', name: 'Minh' }) })
      .compile();
    app = mod.createNestApplication();
    configureApp(app, cfg);
    await app.init();
    http = app.getHttpServer();
  });
  afterAll(async () => app.close());

  const tokenOf = (id: string) => id.padEnd(120, 'x');
  const guest = async () => {
    const r = await request(http).post('/v1/auth/guest').send({ device_id: randomUUID() }).expect(200);
    return `Bearer ${r.body.access_token}`;
  };
  const seed = async (auth: string) => {
    const ev = randomUUID();
    await request(http).put(`/v1/events/${ev}`).set('Authorization', auth)
      .send({ name: 'Lễ', event_date: '2026-05-24', type: 'wedding' }).expect(200);
    await request(http).put(`/v1/gifts/${randomUUID()}`).set('Authorization', auth)
      .send({ event_id: ev, guest_name: 'Anh Long', amount_vnd: 2_000_000, status: 'confirmed', source: 'manual' }).expect(200);
    await request(http).put(`/v1/plan/items/${randomUUID()}`).set('Authorization', auth)
      .send({ event_id: ev, category: 'venue', name: 'Nhà hàng', planned_vnd: 100 }).expect(200);
    await request(http).put(`/v1/plan/guests/${randomUUID()}`).set('Authorization', auth)
      .send({ event_id: ev, name: 'Chị Mai', party_size: 2 }).expect(200);
    await request(http).put(`/v1/invitations/${randomUUID()}`).set('Authorization', auth)
      .send({ person_name: 'Bạn Hùng', event_date: '2026-12-20', event_time: '10:30', planned_vnd: 1_000_000 }).expect(200);
    return ev;
  };
  const counts = async (auth: string) => {
    const evs = await request(http).get('/v1/events').set('Authorization', auth).expect(200);
    const inv = await request(http).get('/v1/invitations').set('Authorization', auth).expect(200);
    return { events: evs.body.items.length, invitations: inv.body.items.length };
  };

  describe('Lịch đi mừng', () => {
    it('tạo/sửa (LWW)/xoá mềm + validate + IDOR', async () => {
      const a = await guest();
      const b = await guest();
      const id = randomUUID();
      const body = { person_name: 'Bạn Hùng', relationship: 'Bạn thân', event_date: '2026-12-20', event_time: '10:30', location: 'Nhà hàng Hoa Sen', planned_vnd: 1_000_000 };
      const c = await request(http).put(`/v1/invitations/${id}`).set('Authorization', a)
        .send({ ...body, updated_at: '2026-05-01T10:00:00.000Z' }).expect(200);
      expect(c.body).toMatchObject({ person_name: 'Bạn Hùng', event_time: '10:30', planned_vnd: 1_000_000, given_vnd: 0, status: 'upcoming' });
      const stale = await request(http).put(`/v1/invitations/${id}`).set('Authorization', a)
        .send({ ...body, planned_vnd: 5, updated_at: '2026-05-01T09:00:00.000Z' }).expect(200);
      expect(stale.body.planned_vnd).toBe(1_000_000);
      const up = await request(http).put(`/v1/invitations/${id}`).set('Authorization', a)
        .send({ ...body, given_vnd: 1_200_000, status: 'attended', updated_at: '2026-05-01T11:00:00.000Z' }).expect(200);
      expect(up.body).toMatchObject({ given_vnd: 1_200_000, status: 'attended' });
      const put = (x: object) => request(http).put(`/v1/invitations/${randomUUID()}`).set('Authorization', a).send({ ...body, ...x });
      await put({ event_date: '20/12/2026' }).expect(400);
      await put({ event_time: '25:00' }).expect(400);
      await put({ person_name: '' }).expect(400);
      await put({ status: 'weird' }).expect(400);
      await put({ planned_vnd: -5 }).expect(400);
      await put({ occasion: 'party' }).expect(400);
      await request(http).put(`/v1/invitations/${id}`).set('Authorization', b).send(body).expect(404); // IDOR
      await request(http).delete(`/v1/invitations/${id}`).set('Authorization', b).expect(404);
      expect((await request(http).get('/v1/invitations').set('Authorization', b).expect(200)).body.items).toHaveLength(0);
      await request(http).delete(`/v1/invitations/${id}`).set('Authorization', a).expect(204);
      await request(http).delete(`/v1/invitations/${id}`).set('Authorization', a).expect(204);
      expect((await request(http).get('/v1/invitations').set('Authorization', a).expect(200)).body.items).toHaveLength(0);
      await request(http).get('/v1/invitations').expect(401);
    });

    it('sắp xếp theo ngày giờ tăng dần', async () => {
      const a = await guest();
      for (const [d, t, n] of [['2026-12-25', '09:00', 'C'], ['2026-12-20', '18:00', 'B'], ['2026-12-20', '09:00', 'A']] as const) {
        await request(http).put(`/v1/invitations/${randomUUID()}`).set('Authorization', a)
          .send({ person_name: n, event_date: d, event_time: t }).expect(200);
      }
      const l = await request(http).get('/v1/invitations').set('Authorization', a).expect(200);
      expect(l.body.items.map((i: any) => i.person_name)).toEqual(['A', 'B', 'C']);
    });
  });

  describe('Đăng nhập Google: xem trước + chọn gộp / dùng dữ liệu tài khoản', () => {
    it('preview: tài khoản mới + khách có dữ liệu', async () => {
      const g = await guest();
      await seed(g);
      const r = await request(http).post('/v1/auth/google/preview').set('Authorization', g)
        .send({ id_token: tokenOf('newuser-aaaa') }).expect(200);
      expect(r.body).toMatchObject({ account_exists: false, account_has_data: false, guest_has_data: true });
      expect(r.body.guest).toMatchObject({ events: 1, gifts: 1, plan_items: 1, plan_guests: 1, invitations: 1 });
      // preview không tạo tài khoản và không gộp
      const r2 = await request(http).post('/v1/auth/google/preview').set('Authorization', g)
        .send({ id_token: tokenOf('newuser-aaaa') }).expect(200);
      expect(r2.body.account_exists).toBe(false);
      expect(await counts(g)).toEqual({ events: 1, invitations: 1 });
    });

    it('tài khoản đã có dữ liệu + khách cũng có: preview báo đủ hai phía; GỘP -> có cả hai (cả kế hoạch & lịch đi mừng)', async () => {
      const tok = tokenOf('merge-bbbb-');
      // thiết bị 1 tạo tài khoản Google có dữ liệu
      const g1 = await guest();
      await seed(g1);
      const l1 = await request(http).post('/v1/auth/google').set('Authorization', g1).send({ id_token: tok }).expect(200);
      const acc = `Bearer ${l1.body.access_token}`;
      expect(await counts(acc)).toEqual({ events: 1, invitations: 1 });
      // thiết bị 2 (khách mới có dữ liệu riêng)
      const g2 = await guest();
      await seed(g2);
      const pv = await request(http).post('/v1/auth/google/preview').set('Authorization', g2).send({ id_token: tok }).expect(200);
      expect(pv.body).toMatchObject({ account_exists: true, account_has_data: true, guest_has_data: true });
      expect(pv.body.account.events).toBe(1);
      // chọn GỘP
      const merged = await request(http).post('/v1/auth/google').set('Authorization', g2).send({ id_token: tok, merge: true }).expect(200);
      expect(await counts(`Bearer ${merged.body.access_token}`)).toEqual({ events: 2, invitations: 2 });
      const evs = await request(http).get('/v1/events').set('Authorization', `Bearer ${merged.body.access_token}`).expect(200);
      const planItems = await request(http).get(`/v1/events/${evs.body.items[0].id}/plan/items`).set('Authorization', `Bearer ${merged.body.access_token}`).expect(200);
      expect(planItems.body.items.length).toBe(1);
    });

    it('chọn DÙNG DỮ LIỆU TÀI KHOẢN (merge=false): không gộp, dữ liệu khách không lẫn vào', async () => {
      const tok = tokenOf('nomerge-cccc');
      const g1 = await guest();
      await seed(g1);
      await request(http).post('/v1/auth/google').set('Authorization', g1).send({ id_token: tok }).expect(200);
      const g2 = await guest();
      await seed(g2);
      const r = await request(http).post('/v1/auth/google').set('Authorization', g2).send({ id_token: tok, merge: false }).expect(200);
      expect(await counts(`Bearer ${r.body.access_token}`)).toEqual({ events: 1, invitations: 1 });
      // dữ liệu của khách vẫn nguyên ở phiên khách (không bị mất, không bị gộp)
      expect(await counts(g2)).toEqual({ events: 1, invitations: 1 });
    });

    it('cài lại app: đăng nhập Google từ thiết bị mới (không có dữ liệu) lấy lại đủ dữ liệu cũ', async () => {
      const tok = tokenOf('reinstall-dd');
      const g1 = await guest();
      const ev = await seed(g1);
      await request(http).post('/v1/auth/google').set('Authorization', g1).send({ id_token: tok }).expect(200);
      // "gỡ app, cài lại": thiết bị mới, khách rỗng
      const fresh = await guest();
      const pv = await request(http).post('/v1/auth/google/preview').set('Authorization', fresh).send({ id_token: tok }).expect(200);
      expect(pv.body).toMatchObject({ account_has_data: true, guest_has_data: false });
      const r = await request(http).post('/v1/auth/google').set('Authorization', fresh).send({ id_token: tok }).expect(200);
      const auth = `Bearer ${r.body.access_token}`;
      const gifts = await request(http).get(`/v1/events/${ev}/gifts`).set('Authorization', auth).expect(200);
      expect(gifts.body.items).toHaveLength(1);
      expect(gifts.body.items[0].guest_name).toBe('Anh Long');
      expect((await request(http).get(`/v1/events/${ev}/plan/guests`).set('Authorization', auth).expect(200)).body.items).toHaveLength(1);
      expect((await request(http).get('/v1/invitations').set('Authorization', auth).expect(200)).body.items[0].person_name).toBe('Bạn Hùng');
    });

    it('preview cần id_token hợp lệ về định dạng; thiếu token -> 400', async () => {
      await request(http).post('/v1/auth/google/preview').send({ id_token: 'short' }).expect(400);
      await request(http).post('/v1/auth/google/preview').send({}).expect(400);
    });
  });
});
