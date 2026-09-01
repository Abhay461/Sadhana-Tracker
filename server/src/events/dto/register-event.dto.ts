import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty } from 'class-validator';

export class RegisterEventDto {
  @ApiProperty({ description: 'Confirmed full name for registration snapshot', example: 'Rahul Sharma' })
  @IsString()
  @IsNotEmpty()
  registeredName: string;

  @ApiProperty({ description: 'Confirmed contact number for registration snapshot', example: '+919876543210' })
  @IsString()
  @IsNotEmpty()
  contactNumber: string;
}
