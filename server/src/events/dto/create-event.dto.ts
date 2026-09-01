import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsOptional } from 'class-validator';

export class CreateEventDto {
  @ApiProperty({ description: 'Event title', example: 'Youth Festival 2026' })
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiProperty({ description: 'Event description', required: false })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ description: 'Event date YYYY-MM-DD', example: '2026-09-15' })
  @IsString()
  @IsNotEmpty()
  eventDate: string;

  @ApiProperty({ description: 'Event time label', required: false, example: '5:00 PM' })
  @IsOptional()
  @IsString()
  eventTime?: string;

  @ApiProperty({ description: 'Banner image URL', required: false })
  @IsOptional()
  @IsString()
  bannerUrl?: string;

  @ApiProperty({ description: 'External registration link', required: false })
  @IsOptional()
  @IsString()
  registrationLink?: string;
}
