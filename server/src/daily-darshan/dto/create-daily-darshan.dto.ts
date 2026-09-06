import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsArray, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateDailyDarshanDto {
  @ApiProperty({ example: '2026-09-06' })
  @IsString()
  @IsNotEmpty()
  date: string;

  @ApiProperty({ example: 'Sri Sri Radha Gopinath Morning Darshan' })
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiProperty({ example: ['https://res.cloudinary.com/demo/image/upload/sample.jpg'] })
  @IsArray()
  @IsString({ each: true })
  @IsNotEmpty()
  imageUrls: string[];

  @ApiPropertyOptional({ example: 'Morning Shringar Darshan' })
  @IsString()
  @IsOptional()
  description?: string;
}
