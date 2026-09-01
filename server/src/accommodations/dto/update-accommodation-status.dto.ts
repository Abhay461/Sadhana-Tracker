import { ApiProperty } from '@nestjs/swagger';
import { IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class UpdateAccommodationStatusDto {
  @ApiProperty({ description: 'Approval decision: APPROVED or REJECTED', enum: ['APPROVED', 'REJECTED'] })
  @IsEnum(['APPROVED', 'REJECTED'])
  @IsNotEmpty()
  status: string;

  @ApiProperty({ description: 'Assigned room label', required: false, example: 'Room 204' })
  @IsOptional()
  @IsString()
  assignedRoom?: string;
}
