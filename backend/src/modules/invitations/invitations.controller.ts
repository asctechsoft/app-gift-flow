import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser, JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UpsertInvitationDto } from './invitations.dto';
import { InvitationsService } from './invitations.service';

@ApiTags('invitations')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('v1/invitations')
export class InvitationsController {
  constructor(private readonly svc: InvitationsService) {}

  @Get()
  list(@CurrentUser() u: AuthUser, @Query('include_deleted') includeDeleted?: string) {
    return this.svc.list(u.id, includeDeleted === 'true');
  }

  @Put(':id')
  upsert(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpsertInvitationDto) {
    return this.svc.upsert(u.id, id, dto);
  }

  @Delete(':id')
  @HttpCode(204)
  async remove(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    await this.svc.remove(u.id, id);
  }
}
