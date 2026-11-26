import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsIn,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

/** Danh mục chi tiêu của kế hoạch cưới. */
export const PLAN_CATEGORIES = [
  'venue', // địa điểm / nhà hàng
  'catering', // tiệc / ăn uống
  'attire', // trang phục (áo cưới, vest)
  'makeup', // trang điểm, làm tóc
  'photo', // chụp ảnh, quay phim
  'decor', // trang trí, hoa
  'invitation', // thiệp, in ấn
  'ceremony', // lễ vật, sính lễ, ăn hỏi
  'ring', // nhẫn, trang sức
  'transport', // xe, đi lại
  'entertainment', // MC, ban nhạc, âm thanh
  'honeymoon', // tuần trăng mật
  'other',
];
export const PLAN_ITEM_STATUSES = ['planned', 'deposit', 'paid'];
export const INVITE_STATUSES = ['planned', 'invited', 'confirmed', 'declined'];
export const GUEST_SIDES = ['mine', 'parents'];
const HARD_MAX = 2_000_000_000;

export class UpsertPlanItemDto {
  @ApiProperty() @IsUUID() event_id: string;
  @ApiProperty({ enum: PLAN_CATEGORIES }) @IsIn(PLAN_CATEGORIES) category: string;
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(200) name: string;
  @ApiProperty({ description: 'Chi phí dự kiến (VND)' }) @IsInt() @Min(0) @Max(HARD_MAX) planned_vnd: number;
  @ApiPropertyOptional({ description: 'Đã trả / đặt cọc (VND)' })
  @IsOptional() @IsInt() @Min(0) @Max(HARD_MAX) paid_vnd?: number;
  @ApiPropertyOptional({ enum: PLAN_ITEM_STATUSES }) @IsOptional() @IsIn(PLAN_ITEM_STATUSES) status?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) vendor?: string | null;
  @ApiPropertyOptional({ example: '2026-04-01' })
  @IsOptional() @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'due_date phải dạng YYYY-MM-DD' }) due_date?: string | null;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(1000) note?: string | null;
  @ApiPropertyOptional() @IsOptional() @IsISO8601() created_at?: string;
  @ApiPropertyOptional() @IsOptional() @IsISO8601() updated_at?: string;
}

export class UpsertPlanGuestDto {
  @ApiProperty() @IsUUID() event_id: string;
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(200) name: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(100) relationship?: string | null;
  @ApiPropertyOptional({ enum: GUEST_SIDES }) @IsOptional() @IsIn(GUEST_SIDES) side?: string;
  @ApiPropertyOptional({ description: 'Số người đi cùng, tính cả khách (>=1)' })
  @IsOptional() @IsInt() @Min(1) @Max(50) party_size?: number;
  @ApiPropertyOptional({ enum: INVITE_STATUSES }) @IsOptional() @IsIn(INVITE_STATUSES) invite_status?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(30) phone?: string | null;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(1000) note?: string | null;
  @ApiPropertyOptional() @IsOptional() @IsISO8601() created_at?: string;
  @ApiPropertyOptional() @IsOptional() @IsISO8601() updated_at?: string;
}
