import { Controller, Post, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { SyncUserDto } from './dto/sync-user.dto';
import { VerifyLegacyDto } from './dto/verify-legacy.dto';
import { FirebaseAuthGuard } from '../common/guards/firebase-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

import { SendEmailOtpDto } from './dto/send-email-otp.dto';
import { VerifyEmailOtpDto } from './dto/verify-email-otp.dto';

@ApiTags('Authentication')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('send-email-otp')
  @ApiOperation({ summary: 'Send 6-digit verification code to user email' })
  async sendEmailOtp(@Body() dto: SendEmailOtpDto) {
    return this.authService.sendEmailOtp(dto.email);
  }

  @Post('verify-email-otp')
  @ApiOperation({ summary: 'Verify 6-digit OTP code sent to email' })
  async verifyEmailOtp(@Body() dto: VerifyEmailOtpDto) {
    return this.authService.verifyEmailOtp(dto.email, dto.otp);
  }

  @Post('sync')
  @UseGuards(FirebaseAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Sync Firebase Auth user with MongoDB profile' })
  async syncUser(@CurrentUser() firebaseUser: any, @Body() dto: SyncUserDto) {
    return this.authService.syncUser(firebaseUser, dto);
  }

  @Post('verify-legacy')
  @UseGuards(FirebaseAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Link legacy Supabase account with verified email proof' })
  async verifyLegacyAccount(
    @CurrentUser() firebaseUser: any,
    @Body() dto: VerifyLegacyDto,
  ) {
    return this.authService.verifyLegacyAccount(firebaseUser, dto);
  }
}
