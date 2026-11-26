import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsInt, IsISO8601, IsOptional, IsString, Matches, Max, MaxLength, Min, MinLength } from 'class-validator';

export const OCCASIONS = ['wedding', 'engagement', 'birthday', 'housewarming', 'baby_month', 'other'];
export const INVITATION_STATUSES = ['upcoming', 'attended', 'skipped'];
const HARD_MAX = 2_000_000_000;

export class UpsertInvitationDto {
  @ApiProperty({ description: 'Tên người mời (cô dâu/chú rể/chủ nhà)' })
  @IsString() @MinLength(1) @MaxLength(200) person_name: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(100) relationship?: string | null;
  @ApiPropertyOptional({ enum: OCCASIONS }) @IsOptional() @IsIn(OCCASIONS) occasion?: string;
  @ApiProperty({ example: '2026-12-20' })
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'event_date phải dạng YYYY-MM-DD' }) event_date: string;
  @ApiPropertyOptional({ example: '10:30', description: 'Giờ 24h HH:mm' })
  @IsOptional() @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'event_time phải dạng HH:mm' }) event_time?: string | null;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(300) location?: string | null;
  @ApiPropertyOptional({ description: 'Dự định mừng (VND)' }) @IsOptional() @IsInt() @Min(0) @Max(HARD_MAX) planned_vnd?: number;
  @ApiPropertyOptional({ description: 'Đã mừng (VND)' }) @IsOptional() @IsInt() @Min(0) @Max(HARD_MAX) given_vnd?: number;
  @ApiPropertyOptional({ enum: INVITATION_STATUSES }) @IsOptional() @IsIn(INVITATION_STATUSES) status?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(1000) note?: string | null;
  @ApiPropertyOptional() @IsOptional() @IsISO8601() created_at?: string;
  @ApiPropertyOptional() @IsOptional() @IsISO8601() updated_at?: string;
}
