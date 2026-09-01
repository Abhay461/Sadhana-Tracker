import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsOptional, IsEnum } from 'class-validator';

export class CreateAnnouncementDto {
  @ApiProperty({ description: 'Announcement title', example: 'Sunday Feast Seminar' })
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiProperty({ description: 'Detailed description', required: false })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ description: 'Type of announcement', enum: ['session', 'announcement', 'general'], default: 'announcement' })
  @IsEnum(['session', 'announcement', 'general'])
  @IsOptional()
  type?: string;

  @ApiProperty({ description: 'Banner image URL', required: false })
  @IsOptional()
  @IsString()
  bannerUrl?: string;

  @ApiProperty({ description: 'External link or meeting URL', required: false })
  @IsOptional()
  @IsString()
  externalLink?: string;

  @ApiProperty({ description: 'Session time label', required: false, example: '8:00 AM - 9:30 AM' })
  @IsOptional()
  @IsString()
  sessionTime?: string;
}
