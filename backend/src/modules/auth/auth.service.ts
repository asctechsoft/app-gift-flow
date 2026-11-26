import { Inject, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { createHash, randomBytes } from 'crypto';
import { DataSource, IsNull, Repository } from 'typeorm';
import { AppError } from '../../common/app-error';
import { AppConfig, CONFIG } from '../../config/config';
import {
  ExportJob,
  Gift,
  GiftEvent,
  Invitation,
  PlanGuest,
  PlanItem,
  RefreshToken,
  User,
  VoiceJob,
} from '../../database/entities';
import { GoogleTokenVerifier } from './google-verifier';
import { QuotasService } from '../quotas/quotas.service';

export interface TokenPair {
  access_token: string;
  refresh_token: string;
  token_type: 'Bearer';
  expires_in: number;
}

const sha256 = (s: string) => createHash('sha256').update(s).digest('hex');

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
    @InjectRepository(RefreshToken) private readonly refresh: Repository<RefreshToken>,
    private readonly jwt: JwtService,
    private readonly quotas: QuotasService,
    private readonly google: GoogleTokenVerifier,
    private readonly ds: DataSource,
    @Inject(CONFIG) private readonly cfg: AppConfig,
  ) {}

  /** Guest auth: định danh thiết bị (hash) -> user ẩn danh có quota riêng. */
  /** Bộ đếm tài khoản khách mới theo IP/ngày (bộ nhớ tiến trình; đủ cho 1 instance). */
  private readonly newGuests = new Map<string, { day: string; n: number }>();

  private checkNewGuestQuota(ip: string): void {
    const limit = this.cfg.newGuestsPerIpPerDay;
    if (limit <= 0) return;
    const day = new Date().toISOString().slice(0, 10);
    const cur = this.newGuests.get(ip);
    if (!cur || cur.day !== day) {
      this.newGuests.set(ip, { day, n: 1 });
      if (this.newGuests.size > 50_000) this.newGuests.clear(); // chặn phình bộ nhớ
      return;
    }
    if (cur.n >= limit) {
      throw new AppError(429, 'too_many_new_accounts', 'Quá nhiều tài khoản mới từ địa chỉ này, hãy thử lại ngày mai');
    }
    cur.n++;
  }

  async guest(deviceId: string, ip = 'unknown'): Promise<TokenPair> {
    const providerUserId = sha256(`guest:${deviceId}`);
    let user = await this.users.findOne({ where: { authProvider: 'guest', providerUserId } });
    if (!user) {
      this.checkNewGuestQuota(ip); // chỉ tính khi thực sự tạo tài khoản mới
      try {
        user = await this.users.save(
          this.users.create({ authProvider: 'guest', providerUserId, displayName: null, plan: 'free' }),
        );
      } catch {
        // 2 request đồng thời cùng thiết bị: unique constraint -> lấy bản đã tạo
        user = await this.users.findOneOrFail({ where: { authProvider: 'guest', providerUserId } });
      }
    }
    return this.issue(user.id);
  }

  /**
   * Đăng nhập Google. Nếu request có token guest hợp lệ, toàn bộ dữ liệu của guest
   * (sự kiện, tiền mừng...) được GỘP sang tài khoản Google (không nhân đôi, id giữ nguyên).
   */
  async loginGoogle(
    idToken: string,
    guestUserId?: string,
    merge = true,
  ): Promise<TokenPair & { display_name: string | null }> {
    const ident = await this.google.verify(idToken);
    let user = await this.users.findOne({ where: { authProvider: 'google', providerUserId: ident.sub } });
    if (!user) {
      try {
        user = await this.users.save(
          this.users.create({
            authProvider: 'google',
            providerUserId: ident.sub,
            displayName: ident.name ?? null,
            plan: 'free',
          }),
        );
      } catch {
        user = await this.users.findOneOrFail({ where: { authProvider: 'google', providerUserId: ident.sub } });
      }
    }
    if (merge && guestUserId && guestUserId !== user.id) {
      const guest = await this.users.findOne({ where: { id: guestUserId, authProvider: 'guest' } });
      if (guest) await this.mergeGuest(guest.id, user.id);
    }
    return { ...(await this.issue(user.id)), display_name: user.displayName };
  }

  /** Đếm dữ liệu (chưa xoá) của một người dùng - để app hỏi người dùng trước khi đồng bộ. */
  private async countData(ownerId: string) {
    const live = { ownerId, deletedAt: IsNull() } as any;
    const [events, gifts, planItems, planGuests, invitations] = await Promise.all([
      this.ds.getRepository(GiftEvent).count({ where: live }),
      this.ds.getRepository(Gift).count({ where: live }),
      this.ds.getRepository(PlanItem).count({ where: live }),
      this.ds.getRepository(PlanGuest).count({ where: live }),
      this.ds.getRepository(Invitation).count({ where: live }),
    ]);
    return { events, gifts, plan_items: planItems, plan_guests: planGuests, invitations };
  }

  /**
   * Xem trước khi đăng nhập Google: tài khoản đã có dữ liệu chưa, và (nếu có token khách)
   * dữ liệu của khách trên máy. KHÔNG tạo tài khoản, KHÔNG gộp - chỉ để app hiện hộp thoại hỏi.
   */
  async previewGoogle(idToken: string, guestUserId?: string) {
    const ident = await this.google.verify(idToken);
    const user = await this.users.findOne({ where: { authProvider: 'google', providerUserId: ident.sub } });
    const account = user ? await this.countData(user.id) : null;
    const guest =
      guestUserId && guestUserId !== user?.id ? await this.countData(guestUserId) : null;
    const has = (c: Record<string, number> | null) => !!c && Object.values(c).some((n) => n > 0);
    return {
      account_exists: !!user,
      email: ident.email ?? null,
      display_name: ident.name ?? null,
      account,
      guest,
      account_has_data: has(account),
      guest_has_data: has(guest),
    };
  }

  private async mergeGuest(fromId: string, toId: string): Promise<void> {
    await this.ds.transaction(async (m) => {
      for (const entity of [GiftEvent, Gift, VoiceJob, ExportJob, PlanItem, PlanGuest, Invitation]) {
        await m.getRepository(entity).update({ ownerId: fromId } as any, { ownerId: toId } as any);
      }
      await m.getRepository(RefreshToken).update({ userId: fromId, revokedAt: IsNull() }, { revokedAt: new Date() });
    });
  }

  /** Refresh token xoay vòng: mỗi token dùng một lần; dùng lại token cũ => thu hồi tất cả. */
  async rotate(token: string): Promise<TokenPair> {
    const row = await this.refresh.findOne({ where: { tokenHash: sha256(token) } });
    if (!row || row.expiresAt.getTime() < Date.now()) {
      throw new AppError(401, 'unauthorized', 'Refresh token không hợp lệ');
    }
    if (row.revokedAt) {
      await this.refresh.update({ userId: row.userId, revokedAt: IsNull() }, { revokedAt: new Date() });
      throw new AppError(401, 'token_reuse', 'Phiên đăng nhập không còn hiệu lực');
    }
    // Thu hồi có điều kiện để 2 request đồng thời không cùng đổi được 1 token.
    const res = await this.refresh.update({ id: row.id, revokedAt: IsNull() }, { revokedAt: new Date() });
    if (!res.affected) throw new AppError(401, 'token_reuse', 'Phiên đăng nhập không còn hiệu lực');
    return this.issue(row.userId);
  }

  async me(userId: string) {
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user) throw new AppError(401, 'unauthorized', 'Tài khoản không tồn tại');
    const quota = await this.quotas.snapshot(userId);
    return { id: user.id, display_name: user.displayName, plan: user.plan, quota };
  }

  private async issue(userId: string): Promise<TokenPair> {
    const access = await this.jwt.signAsync({ sub: userId, typ: 'access' });
    const raw = randomBytes(48).toString('base64url');
    await this.refresh.save(
      this.refresh.create({
        userId,
        tokenHash: sha256(raw),
        expiresAt: new Date(Date.now() + this.cfg.refreshTtlDays * 86_400_000),
        revokedAt: null,
      }),
    );
    return { access_token: access, refresh_token: raw, token_type: 'Bearer', expires_in: this.cfg.jwtAccessTtl };
  }
}
