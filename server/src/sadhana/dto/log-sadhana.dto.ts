import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsOptional, IsNumber, IsBoolean, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export class ManglaArtiDto {
  @IsBoolean()
  @IsOptional()
  attended?: boolean;

  @IsString()
  @IsOptional()
  time?: string;
}

export class ChantingDto {
  @IsNumber()
  @IsOptional()
  rounds?: number;
}

export class OnlineSessionDto {
  @IsBoolean()
  @IsOptional()
  attended?: boolean;

  @IsString()
  @IsOptional()
  timeSpan?: string;
}

export class BookReadingDto {
  @IsString()
  @IsOptional()
  bookName?: string;

  @IsString()
  @IsOptional()
  pagesOrMinutes?: string;
}

export class ServiceActivityDto {
  @IsString()
  @IsOptional()
  serviceName?: string;

  @IsNumber()
  @IsOptional()
  durationMinutes?: number;
}

export class TempleVisitDto {
  @IsBoolean()
  @IsOptional()
  visited?: boolean;
}

export class ClassAttendanceDto {
  @IsBoolean()
  @IsOptional()
  attended?: boolean;
}

export class EkadashiFastingDto {
  @IsString()
  @IsOptional()
  fastingType?: string;

  @IsString()
  @IsOptional()
  notes?: string;
}

export class ActivitiesDto {
  @IsString()
  @IsOptional()
  wakeUpTime?: string;

  @IsString()
  @IsOptional()
  sleepTime?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => ManglaArtiDto)
  manglaArti?: ManglaArtiDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => ChantingDto)
  chanting?: ChantingDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => OnlineSessionDto)
  onlineSession?: OnlineSessionDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => BookReadingDto)
  bookReading?: BookReadingDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => ServiceActivityDto)
  service?: ServiceActivityDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => TempleVisitDto)
  templeVisit?: TempleVisitDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => ClassAttendanceDto)
  srimadBhagavatamClass?: ClassAttendanceDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => ClassAttendanceDto)
  bhagavadGitaClass?: ClassAttendanceDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => EkadashiFastingDto)
  ekadashiFasting?: EkadashiFastingDto;
}

export class LogSadhanaDto {
  @ApiProperty({ description: 'Date string YYYY-MM-DD', example: '2026-08-25' })
  @IsString()
  @IsNotEmpty()
  dateString: string;

  @ApiProperty({ description: 'Client timezone offset in minutes from UTC', example: 330 })
  @IsNumber()
  @IsOptional()
  timezoneOffsetMinutes?: number;

  @ApiProperty({ description: 'Activities logged' })
  @ValidateNested()
  @Type(() => ActivitiesDto)
  activities: ActivitiesDto;
}
