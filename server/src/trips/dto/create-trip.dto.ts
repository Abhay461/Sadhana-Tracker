import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsOptional } from 'class-validator';

export class CreateTripDto {
  @ApiProperty({ description: 'Trip title', example: 'Vrindavan Yatra 2026' })
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiProperty({ description: 'Trip description', required: false })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ description: 'Trip date YYYY-MM-DD', example: '2026-10-10' })
  @IsString()
  @IsNotEmpty()
  tripDate: string;

  @ApiProperty({ description: 'Banner image URL', required: false })
  @IsOptional()
  @IsString()
  bannerUrl?: string;

  @ApiProperty({ description: 'External registration link', required: false })
  @IsOptional()
  @IsString()
  registrationLink?: string;
}
