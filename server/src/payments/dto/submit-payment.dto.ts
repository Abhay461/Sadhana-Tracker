import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsNumber, IsOptional, Min } from 'class-validator';

export class SubmitPaymentDto {
  @ApiProperty({ description: 'Payment title/category', example: 'Monthly Contribution' })
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiProperty({ description: 'Payment amount in INR', example: 500 })
  @IsNumber()
  @Min(1)
  amount: number;

  @ApiProperty({ description: 'Payment proof screenshot URL', required: false })
  @IsOptional()
  @IsString()
  proofUrl?: string;

  @ApiProperty({ description: 'Remarks/notes', required: false })
  @IsOptional()
  @IsString()
  remarks?: string;
}
