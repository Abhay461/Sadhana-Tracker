import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsOptional } from 'class-validator';

export class CreateAccommodationDto {
  @ApiProperty({ description: 'Details of accommodation request', example: 'Need room for 3 days during festival' })
  @IsString()
  @IsNotEmpty()
  requestDetails: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  preacherId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  preacher_id?: string;
}
