import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class VerifyEmailOtpDto {
  @ApiProperty({ description: 'User email address', example: 'user@example.com' })
  @IsString()
  @IsNotEmpty()
  email: string;

  @ApiProperty({ description: '6-digit OTP code', example: '482910' })
  @IsString()
  @IsNotEmpty()
  otp: string;
}
