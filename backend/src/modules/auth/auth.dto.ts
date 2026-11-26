import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class GuestAuthDto {
  @ApiProperty({ description: 'UUID ngẫu nhiên do app sinh một lần và lưu trên máy' })
  @IsString()
  @Matches(/^[A-Za-z0-9-]{16,64}$/, { message: 'device_id không hợp lệ' })
  device_id: string;
}

export class RefreshDto {
  @ApiProperty()
  @IsString()
  @MinLength(20)
  @MaxLength(200)
  refresh_token: string;
}

export class GoogleAuthDto {
  @ApiProperty({ description: 'Google ID token lấy từ google_sign_in (serverClientId = Web client ID)' })
  @IsString()
  @MinLength(100)
  @MaxLength(4000)
  id_token: string;
}

export class GoogleLoginDto extends GoogleAuthDto {
  @ApiProperty({
    required: false,
    description:
      'true (mặc định): gộp dữ liệu khách trên máy vào tài khoản Google. false: chỉ đăng nhập, dùng dữ liệu của tài khoản (không đụng dữ liệu khách).',
  })
  @IsOptional()
  @IsBoolean()
  merge?: boolean;
}
