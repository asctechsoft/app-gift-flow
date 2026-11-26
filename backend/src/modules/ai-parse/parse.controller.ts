import { Body, Controller, HttpCode, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { AppCheckGuard } from '../app-check/app-check.guard';
import { AuthUser, CurrentUser, JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ParseGiftDto } from './parse.dto';
import { ParseService } from './parse.service';

@ApiTags('ai')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('v1/ai')
export class ParseController {
  constructor(private readonly parser: ParseService) {}

  /** Phân tích 1 câu nói đã chuyển thành chữ -> tên/quan hệ/số tiền VND. Không lưu bản ghi. */
  @Post('parse-gift')
  @UseGuards(AppCheckGuard)
  @HttpCode(200)
  @Throttle({ default: { limit: 40, ttl: 60_000 } })
  parse(@CurrentUser() u: AuthUser, @Body() dto: ParseGiftDto) {
    return this.parser.parse(u.id, dto);
  }
}
