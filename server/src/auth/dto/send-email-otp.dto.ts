import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty } from 'class-validator';

export class SendEmailOtpDto {
  @ApiProperty({ description: 'User email address for OTP', example: 'user@example.com' })
  @IsEmail()
  @IsNotEmpty()
  email: string;
}
