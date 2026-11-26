import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

export class ParseGiftDto {
  @ApiProperty() @IsUUID() event_id: string;

  @ApiProperty({ description: 'UUID client sinh. Gửi lại cùng request_id trả đúng kết quả cũ, không gọi AI lần nữa.' })
  @IsUUID()
  request_id: string;

  @ApiProperty({ description: 'Văn bản đã nhận dạng trên thiết bị (một lượt nói = một phong bì)', maxLength: 500 })
  @IsString()
  @MinLength(2)
  @MaxLength(500)
  text: string;
}
