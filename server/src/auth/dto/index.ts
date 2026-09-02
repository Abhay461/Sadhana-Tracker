import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class SendEmailOtpDto {
  @ApiProperty({ description: 'User email address for OTP', example: 'user@example.com' })
  @IsString()
  @IsNotEmpty()
  email: string;
}

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

export * from './sync-user.dto';
export * from './verify-legacy.dto';
