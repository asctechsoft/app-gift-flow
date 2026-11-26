import { Inject, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AppError } from '../../common/app-error';
import { AppConfig, CONFIG } from '../../config/config';
import { UsageQuota } from '../../database/entities';

export const currentPeriod = (d = new Date()) => d.toISOString().slice(0, 7);

/** Kỳ "ngày" của quota toàn hệ thống: D + yymmdd (7 ký tự, vừa cột period). */
export const dayPeriod = (d = new Date()) => 'D' + d.toISOString().slice(2, 10).replace(/-/g, '');
const GLOBAL_OWNER = '__global__';

/** Quota AI theo tháng, kiểm soát hoàn toàn ở server (BR12): trừ nguyên tử. */
@Injectable()
export class QuotasService {
  constructor(
    @InjectRepository(UsageQuota) private readonly repo: Repository<UsageQuota>,
    @Inject(CONFIG) private readonly cfg: AppConfig,
  ) {}

  private async ensureRow(ownerId: string, period: string): Promise<void> {
    const exists = await this.repo.exist({ where: { ownerId, period } });
    if (exists) return;
    try {
      await this.repo.insert({ ownerId, period, quotaLimit: this.cfg.quotaLimit, used: 0 });
    } catch {
      /* đã có request khác tạo - bỏ qua */
    }
  }

  async snapshot(ownerId: string) {
    const period = currentPeriod();
    await this.ensureRow(ownerId, period);
    const row = await this.repo.findOneOrFail({ where: { ownerId, period } });
    return { period, limit: row.quotaLimit, used: row.used };
  }

  /**
   * Công tắc ngắt chi phí: tổng lượt AI của TOÀN hệ thống mỗi ngày. Hết trần -> 429 ai_capacity
   * cho mọi người dùng, kể cả khi ai đó tạo hàng loạt tài khoản để lách quota từng người.
   */
  private async reserveGlobal(): Promise<void> {
    const limit = this.cfg.aiGlobalDailyLimit;
    if (limit <= 0) return;
    const period = dayPeriod();
    const exists = await this.repo.exist({ where: { ownerId: GLOBAL_OWNER, period } });
    if (!exists) {
      try {
        await this.repo.insert({ ownerId: GLOBAL_OWNER, period, quotaLimit: limit, used: 0 });
      } catch {
        /* request khác đã tạo */
      }
    }
    const res = await this.repo
      .createQueryBuilder()
      .update(UsageQuota)
      .set({ used: () => 'used + 1' })
      .where('owner_id = :ownerId AND period = :period AND used < quota_limit', { ownerId: GLOBAL_OWNER, period })
      .execute();
    if (!res.affected) {
      throw new AppError(429, 'ai_capacity', 'Hệ thống AI đang quá tải hôm nay, vui lòng thử lại ngày mai hoặc nhập tay');
    }
  }

  private async releaseGlobal(): Promise<void> {
    if (this.cfg.aiGlobalDailyLimit <= 0) return;
    await this.repo
      .createQueryBuilder()
      .update(UsageQuota)
      .set({ used: () => 'used - 1' })
      .where('owner_id = :ownerId AND period = :period AND used > 0', { ownerId: GLOBAL_OWNER, period: dayPeriod() })
      .execute();
  }

  /** Giữ chỗ 1 lượt AI: UPDATE ... WHERE used < limit (nguyên tử, không race). */
  async reserve(ownerId: string): Promise<void> {
    const period = currentPeriod();
    await this.ensureRow(ownerId, period);
    const res = await this.repo
      .createQueryBuilder()
      .update(UsageQuota)
      .set({ used: () => 'used + 1' })
      .where('owner_id = :ownerId AND period = :period AND used < quota_limit', { ownerId, period })
      .execute();
    if (!res.affected) {
      throw new AppError(429, 'quota_exceeded', 'Bạn đã dùng hết lượt AI trong kỳ này');
    }
    try {
      await this.reserveGlobal();
    } catch (e) {
      await this.releaseUser(ownerId); // không trừ lượt của người dùng khi hệ thống hết trần
      throw e;
    }
  }

  private async releaseUser(ownerId: string): Promise<void> {
    await this.repo
      .createQueryBuilder()
      .update(UsageQuota)
      .set({ used: () => 'used - 1' })
      .where('owner_id = :ownerId AND period = :period AND used > 0', { ownerId, period: currentPeriod() })
      .execute();
  }

  /** Trả lại lượt khi nhà cung cấp AI lỗi (không phát sinh chi phí). */
  async release(ownerId: string): Promise<void> {
    await this.releaseUser(ownerId);
    await this.releaseGlobal();
  }
}
