import { createSign, generateKeyPairSync } from 'crypto';
import { loadConfig } from '../../config/config';
import { AppCheckVerifier, Jwk } from './app-check.verifier';

const PROJECT = '589252278901';
const APP_ID = '1:589252278901:android:3a5972ad164c02617bd63c';

const b64 = (o: unknown) => Buffer.from(typeof o === 'string' ? o : JSON.stringify(o)).toString('base64url');

function makeKey(kid: string) {
  const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const jwk = { ...(publicKey.export({ format: 'jwk' }) as Jwk), kid, alg: 'RS256', use: 'sig' } as Jwk;
  return { jwk, privateKey };
}

function sign(
  priv: ReturnType<typeof makeKey>['privateKey'],
  kid: string,
  claims: Record<string, unknown>,
  header: Record<string, unknown> = {},
) {
  const h = b64({ alg: 'RS256', typ: 'JWT', kid, ...header });
  const p = b64(claims);
  const sig = createSign('RSA-SHA256').update(`${h}.${p}`).sign(priv).toString('base64url');
  return `${h}.${p}.${sig}`;
}

const goodClaims = () => ({
  iss: `https://firebaseappcheck.googleapis.com/${PROJECT}`,
  aud: [`projects/${PROJECT}`, 'projects/giftflow'],
  sub: APP_ID,
  exp: Math.floor(Date.now() / 1000) + 3600,
  iat: Math.floor(Date.now() / 1000),
});

class StubVerifier extends AppCheckVerifier {
  calls = 0;
  constructor(cfg: ReturnType<typeof loadConfig>, private readonly keys: Jwk[]) {
    super(cfg);
  }
  protected async fetchJwks(): Promise<Jwk[]> {
    this.calls++;
    return this.keys;
  }
}

const cfg = (extra: Record<string, string> = {}) =>
  loadConfig({
    JWT_ACCESS_SECRET: 'x'.repeat(40),
    AI_PROVIDER: 'mock',
    DB_TYPE: 'sqljs',
    APP_CHECK_MODE: 'enforce',
    FIREBASE_PROJECT_NUMBER: PROJECT,
    ...extra,
  } as NodeJS.ProcessEnv);

describe('AppCheckVerifier', () => {
  const k = makeKey('kid-1');
  const other = makeKey('kid-1'); // cùng kid nhưng khoá khác -> chữ ký sai
  const v = () => new StubVerifier(cfg(), [k.jwk]);

  it('token hợp lệ -> ok + app id', async () => {
    const r = await v().verify(sign(k.privateKey, 'kid-1', goodClaims()));
    expect(r).toEqual({ ok: true, appId: APP_ID });
  });

  it('thiếu token / sai định dạng', async () => {
    expect(await v().verify(undefined)).toEqual({ ok: false, reason: 'missing' });
    expect(await v().verify('abc')).toEqual({ ok: false, reason: 'malformed' });
    expect(await v().verify('a.b.c')).toEqual({ ok: false, reason: 'malformed' });
  });

  it('chữ ký giả (ký bằng khoá khác) bị từ chối', async () => {
    const r = await v().verify(sign(other.privateKey, 'kid-1', goodClaims()));
    expect(r).toEqual({ ok: false, reason: 'bad_signature' });
  });

  it('claim bị sửa sau khi ký -> bad_signature', async () => {
    const t = sign(k.privateKey, 'kid-1', goodClaims()).split('.');
    t[1] = b64({ ...goodClaims(), sub: 'evil' });
    expect(await v().verify(t.join('.'))).toEqual({ ok: false, reason: 'bad_signature' });
  });

  it('hết hạn / sai issuer / sai audience', async () => {
    expect(await v().verify(sign(k.privateKey, 'kid-1', { ...goodClaims(), exp: 1 }))).toEqual({ ok: false, reason: 'expired' });
    expect(await v().verify(sign(k.privateKey, 'kid-1', { ...goodClaims(), iss: 'https://evil.example/1' }))).toEqual({ ok: false, reason: 'bad_issuer' });
    expect(await v().verify(sign(k.privateKey, 'kid-1', { ...goodClaims(), aud: ['projects/999999'] }))).toEqual({ ok: false, reason: 'bad_audience' });
  });

  it('thuật toán không phải RS256 (alg=none/HS256) bị từ chối', async () => {
    const none = `${b64({ alg: 'none', typ: 'JWT', kid: 'kid-1' })}.${b64(goodClaims())}.`;
    expect(await v().verify(none)).toEqual({ ok: false, reason: 'bad_header' });
    const hs = sign(k.privateKey, 'kid-1', goodClaims(), { alg: 'HS256' });
    expect(await v().verify(hs)).toEqual({ ok: false, reason: 'bad_header' });
  });

  it('kid lạ -> unknown_key; JWKS được cache, không gọi mạng mỗi request', async () => {
    const sv = v();
    expect(await sv.verify(sign(k.privateKey, 'kid-zzz', goodClaims()))).toEqual({ ok: false, reason: 'unknown_key' });
    const good = sign(k.privateKey, 'kid-1', goodClaims());
    await sv.verify(good);
    await sv.verify(good);
    await sv.verify(good);
    expect(sv.calls).toBeLessThanOrEqual(2); // 1 lần ban đầu (+ tối đa 1 lần thử lại kid lạ trong 60s bị chặn)
  });

  it('giới hạn app id: chỉ chấp nhận danh sách cấu hình', async () => {
    const strict = new StubVerifier(cfg({ APP_CHECK_APP_IDS: '1:589252278901:android:other' }), [k.jwk]);
    expect(await strict.verify(sign(k.privateKey, 'kid-1', goodClaims()))).toEqual({ ok: false, reason: 'bad_app' });
  });

  it('cấu hình: bật App Check mà thiếu project number -> không khởi động', () => {
    expect(() => cfg({ FIREBASE_PROJECT_NUMBER: '' })).toThrow(/FIREBASE_PROJECT_NUMBER/);
    expect(cfg({ APP_CHECK_MODE: 'off', FIREBASE_PROJECT_NUMBER: '' }).appCheckMode).toBe('off');
  });
});
