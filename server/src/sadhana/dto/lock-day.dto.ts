import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsBoolean } from 'class-validator';

export class LockDayDto {
  @ApiProperty({ description: 'Target student userId' })
  @IsString()
  @IsNotEmpty()
  userId: string;

  @ApiProperty({ description: 'Date string YYYY-MM-DD', example: '2026-08-25' })
  @IsString()
  @IsNotEmpty()
  dateString: string;

  @ApiProperty({ description: 'Lock status: true to lock, false to unlock' })
  @IsBoolean()
  isLocked: boolean;
}
