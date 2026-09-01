import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class SendEmailOtpDto {
  @ApiProperty({ description: 'User email address for OTP', example: 'user@example.com' })
  @IsString()
  @IsNotEmpty()
  email: string;
}
