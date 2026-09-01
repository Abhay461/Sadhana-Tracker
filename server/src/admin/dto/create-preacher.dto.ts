import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsEmail, MinLength } from 'class-validator';

export class CreatePreacherDto {
  @ApiProperty({ description: 'Preacher Full Name', example: 'Advaita Das' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({ description: 'Preacher Email', example: 'preacher@example.com' })
  @IsEmail()
  @IsNotEmpty()
  email: string;

  @ApiProperty({ description: 'Preacher WhatsApp / Mobile Number', example: '+919876543210' })
  @IsString()
  @IsNotEmpty()
  phoneNumber: string;

  @ApiProperty({ description: 'Initial login password', example: 'Preacher@123' })
  @IsString()
  @MinLength(8)
  password: string;
}
