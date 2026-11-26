import { CanActivate, ExecutionContext, Inject, Injectable, Logger } from '@nestjs/common';
import type { Request } from 'express';
import { AppError } from '../../common/app-error';
import { AppConfig, CONFIG } from '../../config/config';
import { AppCheckVerifier } from './app-check.verifier';

/**
 * Chặn client không phải app thật. Chế độ (APP_CHECK_MODE):
 *  - off:     không kiểm tra.
 *  - monitor: kiểm tra + ghi log thống kê, KHÔNG chặn (dùng khi chưa phát hành app có token).
 *  - enforce: thiếu/sai token -> 401 app_check_failed.
 * Header: X-Firebase-AppCheck.
 */
@Injectable()
export class AppCheckGuard implements CanActivate {
  private readonly log = new Logger('AppCheck');
  private seen = { ok: 0, missing: 0, invalid: 0 };
  private lastReport = Date.now();

  constructor(
    private readonly verifier: AppCheckVerifier,
    @Inject(CONFIG) private readonly cfg: AppConfig,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const mode = this.cfg.appCheckMode;
    if (mode === 'off') return true;
    const req = ctx.switchToHttp().getRequest<Request>();
    const raw = req.header('x-firebase-appcheck');
    const r = await this.verifier.verify(raw);
    if (r.ok) {
      this.seen.ok++;
      return true;
    }
    if (r.reason === 'missing') this.seen.missing++;
    else this.seen.invalid++;
    if (mode === 'monitor') {
      this.report(r.reason);
      return true;
    }
    this.log.warn(`app check bị từ chối: ${r.reason} (${req.method} ${req.path})`);
    throw new AppError(401, 'app_check_failed', 'Ứng dụng không được xác thực. Hãy cập nhật hoặc cài lại bản chính thức.');
  }

  /** Ghi tối đa 1 dòng/phút để theo dõi tỉ lệ token hợp lệ khi đang ở chế độ monitor. */
  private report(reason: string) {
    const now = Date.now();
    if (now - this.lastReport < 60_000) return;
    this.lastReport = now;
    this.log.log(`monitor: ok=${this.seen.ok} missing=${this.seen.missing} invalid=${this.seen.invalid} (gần nhất: ${reason})`);
  }
}
