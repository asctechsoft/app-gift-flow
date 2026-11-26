import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser, JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UpsertPlanGuestDto, UpsertPlanItemDto } from './plan.dto';
import { PlanService } from './plan.service';

/** Kế hoạch sự kiện (trước lễ): khoản chi + khách mời dự kiến. Không liên quan tiền mừng. */
@ApiTags('plan')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('v1')
export class PlanController {
  constructor(private readonly plan: PlanService) {}

  @Get('events/:eventId/plan/summary')
  summary(@CurrentUser() u: AuthUser, @Param('eventId', ParseUUIDPipe) eventId: string) {
    return this.plan.summary(u.id, eventId);
  }

  // ---- khoản chi
  @Get('events/:eventId/plan/items')
  listItems(
    @CurrentUser() u: AuthUser,
    @Param('eventId', ParseUUIDPipe) eventId: string,
    @Query('include_deleted') includeDeleted?: string,
  ) {
    return this.plan.listItems(u.id, eventId, includeDeleted === 'true');
  }

  @Put('plan/items/:id')
  upsertItem(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpsertPlanItemDto) {
    return this.plan.upsertItem(u.id, id, dto);
  }

  @Delete('plan/items/:id')
  @HttpCode(204)
  async removeItem(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    await this.plan.removeItem(u.id, id);
  }

  // ---- khách mời dự kiến
  @Get('events/:eventId/plan/guests')
  listGuests(
    @CurrentUser() u: AuthUser,
    @Param('eventId', ParseUUIDPipe) eventId: string,
    @Query('include_deleted') includeDeleted?: string,
  ) {
    return this.plan.listGuests(u.id, eventId, includeDeleted === 'true');
  }

  @Put('plan/guests/:id')
  upsertGuest(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpsertPlanGuestDto) {
    return this.plan.upsertGuest(u.id, id, dto);
  }

  @Delete('plan/guests/:id')
  @HttpCode(204)
  async removeGuest(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    await this.plan.removeGuest(u.id, id);
  }
}
