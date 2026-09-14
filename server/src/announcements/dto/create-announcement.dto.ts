import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional } from 'class-validator';

export class CreateAnnouncementDto {
  @ApiPropertyOptional()
  @IsOptional()
  title?: string;

  @ApiPropertyOptional()
  @IsOptional()
  content?: string;

  @ApiPropertyOptional()
  @IsOptional()
  category?: string;

  @ApiPropertyOptional()
  @IsOptional()
  description?: string;

  @ApiPropertyOptional()
  @IsOptional()
  type?: string;

  @ApiPropertyOptional()
  @IsOptional()
  bannerUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  externalLink?: string;

  @ApiPropertyOptional()
  @IsOptional()
  sessionTime?: string;

  @ApiPropertyOptional()
  @IsOptional()
  preacher_id?: string;
}
