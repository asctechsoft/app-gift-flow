import { Inject, Injectable, Logger } from '@nestjs/common';
import { createPublicKey, createVerify, JsonWebKey } from 'crypto';
import { AppConfig, CONFIG } from '../../config/config';

export type AppCheckResult =
  | { ok: true; appId: string }
  | { ok: false; reason: 'missing' | 'malformed' | 'bad_header' | 'unknown_key' | 'bad_signature' | 'expired' | 'bad_issuer' | 'bad_audience' | 'bad_app' };

export interface Jwk extends JsonWebKey {
  kid?: string;
  alg?: string;
  use?: string;
}

const JWKS_URL = 'https://firebaseappcheck.googleapis.com/v1/jwks';
const JWKS_TTL_MS = 6 * 3600_000;
const JWKS_RETRY_MS = 60_000;

const b64url = (s: string) => Buffer.from(s.replace(/-/g, '+').replace(/_/g, '/'), 'base64');

/**
 * Xác thực Firebase App Check token (JWT RS256) phía server, không cần Admin SDK:
 * tải JWKS công khai của Firebase, kiểm tra chữ ký + iss + aud + exp (+ sub = app id cho phép).
 * Token chứng minh request đến từ bản app thật (Play Integrity) - không phải script/clone.
 */
@Injectable()
export class AppCheckVerifier {
  private readonly log = new Logger('AppCheck');
  private keys = new Map<string, Jwk>();
  private fetchedAt = 0;
  private lastTry = 0;

  constructor(@Inject(CONFIG) private readonly cfg: AppConfig) {}

  /** Tách ra để test thay thế (không gọi mạng). */
  protected async fetchJwks(): Promise<Jwk[]> {
    const res = await fetch(JWKS_URL, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) throw new Error(`jwks http ${res.status}`);
    const body = (await res.json()) as { keys?: Jwk[] };
    return body.keys ?? [];
  }

  private async key(kid: string): Promise<Jwk | undefined> {
    const now = Date.now();
    const stale = now - this.fetchedAt > JWKS_TTL_MS;
    if ((stale || !this.keys.has(kid)) && now - this.lastTry > JWKS_RETRY_MS) {
      this.lastTry = now;
      try {
        const keys = await this.fetchJwks();
        this.keys = new Map(keys.filter((k) => k.kid).map((k) => [k.kid as string, k]));
        this.fetchedAt = now;
      } catch (e) {
        this.log.warn(`không tải được JWKS: ${(e as Error).message}`);
      }
    }
    return this.keys.get(kid);
  }

  async verify(token: string | undefined): Promise<AppCheckResult> {
    if (!token) return { ok: false, reason: 'missing' };
    const parts = token.split('.');
    if (parts.length !== 3) return { ok: false, reason: 'malformed' };
    let header: { alg?: string; kid?: string; typ?: string };
    let payload: { iss?: string; aud?: string[] | string; exp?: number; sub?: string };
    try {
      header = JSON.parse(b64url(parts[0]).toString('utf8'));
      payload = JSON.parse(b64url(parts[1]).toString('utf8'));
    } catch {
      return { ok: false, reason: 'malformed' };
    }
    if (header.alg !== 'RS256' || !header.kid) return { ok: false, reason: 'bad_header' };

    const jwk = await this.key(header.kid);
    if (!jwk) return { ok: false, reason: 'unknown_key' };
    try {
      const pub = createPublicKey({ key: jwk as JsonWebKey, format: 'jwk' });
      const ok = createVerify('RSA-SHA256').update(`${parts[0]}.${parts[1]}`).verify(pub, b64url(parts[2]));
      if (!ok) return { ok: false, reason: 'bad_signature' };
    } catch {
      return { ok: false, reason: 'bad_signature' };
    }

    const num = this.cfg.firebaseProjectNumber;
    if (typeof payload.exp !== 'number' || payload.exp * 1000 < Date.now()) return { ok: false, reason: 'expired' };
    if (payload.iss !== `https://firebaseappcheck.googleapis.com/${num}`) return { ok: false, reason: 'bad_issuer' };
    const aud = Array.isArray(payload.aud) ? payload.aud : payload.aud ? [payload.aud] : [];
    if (!aud.includes(`projects/${num}`)) return { ok: false, reason: 'bad_audience' };
    const appId = payload.sub ?? '';
    if (this.cfg.appCheckAppIds.length && !this.cfg.appCheckAppIds.includes(appId)) {
      return { ok: false, reason: 'bad_app' };
    }
    return { ok: true, appId };
  }
}
