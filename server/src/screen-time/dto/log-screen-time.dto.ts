import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsOptional } from 'class-validator';

export class LogScreenTimeDto {
  @ApiProperty({ description: 'Date string YYYY-MM-DD', example: '2026-08-25' })
  @IsString()
  @IsNotEmpty()
  date: string;

  @ApiProperty({ description: 'Total duration label', example: '2h 45m' })
  @IsString()
  @IsNotEmpty()
  totalDurationLabel: string;

  @ApiProperty({ description: 'App breakdown description', required: false })
  @IsOptional()
  @IsString()
  breakdownDescription?: string;
}
