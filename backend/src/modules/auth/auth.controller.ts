import { Body, Controller, Get, Headers, HttpCode, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { JwtService } from '@nestjs/jwt';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { AppCheckGuard } from '../app-check/app-check.guard';
import { AuthService } from './auth.service';
import { GoogleAuthDto, GuestAuthDto, RefreshDto } from './auth.dto';
import { AuthUser, CurrentUser, JwtAuthGuard } from './jwt-auth.guard';

@ApiTags('auth')
@Controller('v1')
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly jwt: JwtService,
  ) {}

  @Post('auth/guest')
  @UseGuards(AppCheckGuard)
  @HttpCode(200)
  @Throttle({ default: { limit: () => Number(process.env.THROTTLE_GUEST_LIMIT ?? 10), ttl: 60_000 } })
  guest(@Body() dto: GuestAuthDto, @Req() req: Request) {
    return this.auth.guest(dto.device_id, req.ip ?? 'unknown');
  }

  /** Gửi kèm Authorization (guest) để gộp dữ liệu guest vào tài khoản Google. */
  @Post('auth/google')
  @UseGuards(AppCheckGuard)
  @HttpCode(200)
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  async google(@Body() dto: GoogleAuthDto, @Headers('authorization') authz?: string) {
    let guestId: string | undefined;
    const token = authz?.startsWith('Bearer ') ? authz.slice(7).trim() : undefined;
    if (token) {
      try {
        const p = await this.jwt.verifyAsync<{ sub: string; typ: string }>(token);
        if (p.typ === 'access') guestId = p.sub;
      } catch {
        /* token guest hết hạn: bỏ qua, chỉ đăng nhập */
      }
    }
    return this.auth.loginGoogle(dto.id_token, guestId);
  }

  @Post('auth/refresh')
  @HttpCode(200)
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  refresh(@Body() dto: RefreshDto) {
    return this.auth.rotate(dto.refresh_token);
  }

  @Get('me')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  me(@CurrentUser() user: AuthUser) {
    return this.auth.me(user.id);
  }
}
