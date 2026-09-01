import { ApiProperty } from '@nestjs/swagger';
import { IsEnum, IsNotEmpty } from 'class-validator';

export class ApproveStudentDto {
  @ApiProperty({ description: 'Status decision: ACTIVE or REJECTED', enum: ['ACTIVE', 'REJECTED'] })
  @IsEnum(['ACTIVE', 'REJECTED'])
  @IsNotEmpty()
  status: string;
}
