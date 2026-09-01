import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsOptional, IsEmail } from 'class-validator';

export class SyncUserDto {
  @ApiProperty({ description: 'Full name of the user', example: 'Rahul Sharma' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({ description: 'User email address', required: false, example: 'rahul@example.com' })
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiProperty({ description: 'User role', required: false })
  @IsOptional()
  @IsString()
  role?: string;

  @ApiProperty({ description: 'Selected Preacher ID', required: false })
  @IsOptional()
  @IsString()
  preacherId?: string;

  @ApiProperty({ description: 'Phone / WhatsApp number', required: false })
  @IsOptional()
  @IsString()
  phoneNumber?: string;

  @ApiProperty({ description: 'Assigned Preacher Code', required: false, example: 'PRCH-X8K92A' })
  @IsOptional()
  @IsString()
  preacherCode?: string;

  @ApiProperty({ description: 'Profile photo URL', required: false })
  @IsOptional()
  @IsString()
  photoUrl?: string;
}
