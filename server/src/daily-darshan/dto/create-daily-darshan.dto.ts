import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional } from 'class-validator';

export class CreateDailyDarshanDto {
  @ApiPropertyOptional({ example: '2026-09-06' })
  @IsOptional()
  date?: string;

  @ApiPropertyOptional({ example: 'Sri Sri Radha Gopinath Morning Darshan' })
  @IsOptional()
  title?: string;

  @ApiPropertyOptional({ example: ['https://res.cloudinary.com/demo/image/upload/sample.jpg'] })
  @IsOptional()
  imageUrls?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  imageUrl?: string;

  @ApiPropertyOptional({ example: 'Morning Shringar Darshan' })
  @IsOptional()
  description?: string;

  @ApiPropertyOptional()
  @IsOptional()
  message?: string;
}
