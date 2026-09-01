import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsString } from 'class-validator';

export class VerifyLegacyDto {
  @ApiProperty({ description: 'Legacy Supabase account email', example: 'student@example.com' })
  @IsEmail()
  @IsNotEmpty()
  legacyEmail: string;

  @ApiProperty({ description: 'Legacy verification token or hash', example: 'leg_token_98234' })
  @IsString()
  @IsNotEmpty()
  verificationProof: string;
}
