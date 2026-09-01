import { ApiProperty } from '@nestjs/swagger';
import { IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class ApprovePaymentDto {
  @ApiProperty({ description: 'Decision: APPROVED or REJECTED', enum: ['APPROVED', 'REJECTED'] })
  @IsEnum(['APPROVED', 'REJECTED'])
  @IsNotEmpty()
  status: string;

  @ApiProperty({ description: 'Preacher verification remarks', required: false })
  @IsOptional()
  @IsString()
  remarks?: string;
}
