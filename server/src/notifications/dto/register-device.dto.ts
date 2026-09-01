import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsEnum } from 'class-validator';

export class RegisterDeviceDto {
  @ApiProperty({ description: 'FCM Device Registration Token' })
  @IsString()
  @IsNotEmpty()
  fcmToken: string;

  @ApiProperty({ description: 'Device Platform', enum: ['android', 'ios', 'web'] })
  @IsEnum(['android', 'ios', 'web'])
  @IsNotEmpty()
  platform: string;

  @ApiProperty({ description: 'Privacy-safe application installation ID (UUIDv4)' })
  @IsString()
  @IsNotEmpty()
  appInstanceId: string;

  @ApiProperty({ description: 'App Version', example: '1.0.0' })
  @IsString()
  @IsNotEmpty()
  appVersion: string;
}
