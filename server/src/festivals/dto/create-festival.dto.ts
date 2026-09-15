import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, IsBoolean } from 'class-validator';

export class CreateFestivalDto {
  @ApiProperty({ description: 'Festival Title', example: 'Sri Krishna Janmashtami' })
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiProperty({ description: 'Festival Description', example: 'Appearance day of Lord Krishna', required: false })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiProperty({ description: 'Festival Image URL (Cloudinary or web link)', required: false })
  @IsString()
  @IsOptional()
  imageUrl?: string;

  @ApiProperty({ description: 'Festival Date in YYYY-MM-DD format', example: '2026-09-15' })
  @IsString()
  @IsNotEmpty()
  dateString: string;

  @ApiProperty({ description: 'Is Festival Active', default: true, required: false })
  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}
