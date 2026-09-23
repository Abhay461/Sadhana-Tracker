import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString, IsEmail, IsDateString } from 'class-validator';

export class UpdateUserProfileDto {
  @ApiProperty({ description: 'Full name', required: false })
  @IsOptional()
  @IsString()
  name?: string;

  @ApiProperty({ description: 'Profile photo URL', required: false })
  @IsOptional()
  @IsString()
  photoUrl?: string;

  @ApiProperty({ description: 'Profile photo URL (alias)', required: false })
  @IsOptional()
  @IsString()
  photo_url?: string;

  @ApiProperty({ description: 'Email address', required: false })
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiProperty({ description: 'Phone number', required: false })
  @IsOptional()
  @IsString()
  phoneNumber?: string;

  @ApiProperty({ description: 'WhatsApp number', required: false })
  @IsOptional()
  @IsString()
  whatsapp_number?: string;

  @ApiProperty({ description: 'Date of birth', required: false })
  @IsOptional()
  @IsDateString()
  dob?: string;

  @ApiProperty({ description: 'Joining date', required: false })
  @IsOptional()
  @IsDateString()
  joiningDate?: string;

  @ApiProperty({ description: 'Joining date (alias)', required: false })
  @IsOptional()
  @IsDateString()
  joining_date?: string;

  @ApiProperty({ description: 'Preacher User ID', required: false })
  @IsOptional()
  @IsString()
  preacherId?: string;

  @ApiProperty({ description: 'Occupation / Status', required: false })
  @IsOptional()
  @IsString()
  occupation?: string;

  @ApiProperty({ description: 'College / University Name', required: false })
  @IsOptional()
  @IsString()
  college?: string;

  @ApiProperty({ description: 'Course & Year', required: false })
  @IsOptional()
  @IsString()
  courseYear?: string;

  @ApiProperty({ description: 'City / Native Hometown', required: false })
  @IsOptional()
  @IsString()
  city?: string;

  @ApiProperty({ description: 'Allow viewing students under all preachers', required: false })
  @IsOptional()
  canViewAllStudents?: boolean;

  @ApiProperty({ description: 'Head Preacher flag', required: false })
  @IsOptional()
  isHeadPreacher?: boolean;
}
