import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsOptional, IsArray } from 'class-validator';

export class SendNotificationDto {
  @ApiProperty({ description: 'Target user IDs', type: [String] })
  @IsArray()
  @IsString({ each: true })
  targetUserIds: string[];

  @ApiProperty({ description: 'Notification Title', example: 'New Session Scheduled' })
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiProperty({ description: 'Notification Body', example: 'Join Bhagavad Gita class at 8:00 AM' })
  @IsString()
  @IsNotEmpty()
  body: string;

  @ApiProperty({ description: 'Optional key-value data payload', required: false })
  @IsOptional()
  dataPayload?: Record<string, string>;
}
