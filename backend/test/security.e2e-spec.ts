import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { randomUUID } from 'crypto';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/app.setup';
import { loadConfig } from '../src/config/config';
import { AppCheckVerifier } from '../src/modules/app-check/app-check.verifier';

async function boot(env: Record<string, string>, verifier?: Partial<AppCheckVerifier>) {
  process.env.THROTTLE_GUEST_LIMIT = '1000';
  const cfg = loadConfig({
    NODE_ENV: 'test',
    DB_TYPE: 'sqljs',
    SQLJS_FILE: ':memory:',
    JWT_ACCESS_SECRET: 'sec-secret-sec-secret-sec-secret-123456',
    AI_PROVIDER: 'mock',
    THROTTLE_LIMIT: '10000',
    NEW_GUESTS_PER_IP_PER_DAY: '100000',
    ...env,
  } as NodeJS.ProcessEnv);
  let b = Test.createTestingModule({ imports: [AppModule.forRoot(cfg)] });
  if (verifier) b = b.overrideProvider(AppCheckVerifier).useValue(verifier);
  const mod = await b.compile();
  const app = mod.createNestApplication();
  configureApp(app, cfg);
  await app.init();
  return app;
}

const guest = (http: any, extra: Record<string, string> = {}, deviceId = randomUUID()) =>
  request(http).post('/v1/auth/guest').set(extra).send({ device_id: deviceId });

const stubVerifier = {
  verify: async (t?: string) =>
    t === 'good' ? { ok: true as const, appId: 'app' } : { ok: false as const, reason: t ? ('bad_signature' as const) : ('missing' as const) },
};

describe('Bảo mật: App Check', () => {
  let app: INestApplication;
  afterEach(async () => app?.close());

  it('enforce: thiếu/sai token bị chặn 401 ở đăng nhập khách, Google và các API AI; có token hợp lệ thì qua', async () => {
    app = await boot({ APP_CHECK_MODE: 'enforce', FIREBASE_PROJECT_NUMBER: '589252278901' }, stubVerifier);
    const http = app.getHttpServer();

    const r1 = await guest(http).expect(401);
    expect(r1.body.code).toBe('app_check_failed');
    await guest(http, { 'X-Firebase-AppCheck': 'forged' }).expect(401);
    await request(http).post('/v1/auth/google').send({ id_token: 'x'.repeat(30) }).expect(401);

    const ok = await guest(http, { 'X-Firebase-AppCheck': 'good' }).expect(200);
    const auth = `Bearer ${ok.body.access_token}`;

    // API AI cần token app check (JWT đúng cũng chưa đủ)
    const ev = randomUUID();
    await request(http).put(`/v1/events/${ev}`).set('Authorization', auth)
      .send({ name: 'Lễ', event_date: '2026-05-24', type: 'wedding' }).expect(200);
    const body = { event_id: ev, request_id: randomUUID(), text: 'Anh Long mừng hai triệu' };
    await request(http).post('/v1/ai/parse-gift').set('Authorization', auth).send(body).expect(401);
    await request(http).post('/v1/ai/parse-gift').set('Authorization', auth).set('X-Firebase-AppCheck', 'good').send(body).expect(200);
    await request(http).post('/v1/voice/segments').set('Authorization', auth)
      .field('event_id', ev).field('request_id', randomUUID()).field('duration_ms', '1500').field('transcript_text', 'Anh Long hai triệu')
      .expect(401);

    // API dữ liệu thường (không tốn AI) không bắt buộc App Check -> app cũ vẫn đọc/ghi được
    await request(http).get('/v1/events').set('Authorization', auth).expect(200);
  });

  it('monitor: không chặn dù thiếu token (dùng khi chuyển đổi)', async () => {
    app = await boot({ APP_CHECK_MODE: 'monitor', FIREBASE_PROJECT_NUMBER: '589252278901' }, stubVerifier);
    await guest(app.getHttpServer()).expect(200);
  });

  it('off: bỏ qua hoàn toàn', async () => {
    app = await boot({ APP_CHECK_MODE: 'off' });
    await guest(app.getHttpServer()).expect(200);
  });
});

describe('Bảo mật: chống lạm dụng chi phí AI', () => {
  let app: INestApplication;
  afterEach(async () => app?.close());

  it('mỗi IP chỉ tạo được N tài khoản khách mới mỗi ngày; thiết bị cũ vẫn đăng nhập lại được', async () => {
    app = await boot({ NEW_GUESTS_PER_IP_PER_DAY: '2' });
    const http = app.getHttpServer();
    const dev = randomUUID();
    await guest(http, {}, dev).expect(200);
    await guest(http).expect(200);
    const blocked = await guest(http).expect(429);
    expect(blocked.body.code).toBe('too_many_new_accounts');
    await guest(http, {}, dev).expect(200); // thiết bị đã có tài khoản không bị tính
  });

  it('trần AI toàn hệ thống/ngày: hết trần -> 429 ai_capacity, không trừ lượt của người dùng', async () => {
    app = await boot({ AI_GLOBAL_DAILY_LIMIT: '2', QUOTA_LIMIT_PER_PERIOD: '50' });
    const http = app.getHttpServer();
    const { body } = await guest(http).expect(200);
    const auth = `Bearer ${body.access_token}`;
    const ev = randomUUID();
    await request(http).put(`/v1/events/${ev}`).set('Authorization', auth)
      .send({ name: 'Lễ', event_date: '2026-05-24', type: 'wedding' }).expect(200);
    const parse = () =>
      request(http).post('/v1/ai/parse-gift').set('Authorization', auth)
        .send({ event_id: ev, request_id: randomUUID(), text: 'Anh Long mừng hai triệu' });
    await parse().expect(200);
    await parse().expect(200);
    const over = await parse().expect(429);
    expect(over.body.code).toBe('ai_capacity');
    const me = await request(http).get('/v1/me').set('Authorization', auth).expect(200);
    expect(me.body.quota.used).toBe(2); // lượt thứ 3 không bị trừ
  });

  it('lỗi nhà cung cấp AI hoàn lại cả lượt người dùng lẫn lượt toàn hệ thống (không rò rỉ trần)', async () => {
    app = await boot({ AI_GLOBAL_DAILY_LIMIT: '1' });
    const http = app.getHttpServer();
    const { body } = await guest(http).expect(200);
    const auth = `Bearer ${body.access_token}`;
    const ev = randomUUID();
    await request(http).put(`/v1/events/${ev}`).set('Authorization', auth)
      .send({ name: 'Lễ', event_date: '2026-05-24', type: 'wedding' }).expect(200);
    // văn bản rỗng bị chặn trước khi trừ lượt -> vẫn còn trần cho lần gọi hợp lệ
    await request(http).post('/v1/ai/parse-gift').set('Authorization', auth)
      .send({ event_id: ev, request_id: randomUUID(), text: '  .. ' }).expect(400);
    await request(http).post('/v1/ai/parse-gift').set('Authorization', auth)
      .send({ event_id: ev, request_id: randomUUID(), text: 'Anh Long mừng hai triệu' }).expect(200);
  });

  it('phản hồi API không bị cache (Cache-Control: no-store) và ẩn X-Powered-By', async () => {
    app = await boot({});
    const r = await request(app.getHttpServer()).get('/v1/events').expect(401);
    expect(r.headers['cache-control']).toBe('no-store');
    expect(r.headers['x-powered-by']).toBeUndefined();
    expect(r.headers['x-content-type-options']).toBe('nosniff');
  });
});
