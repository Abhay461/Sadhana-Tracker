import {
  Injectable,
  Logger,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { User, UserDocument } from '../database/schemas/users.schema';
import { SyncUserDto } from './dto/sync-user.dto';
import { VerifyLegacyDto } from './dto/verify-legacy.dto';
import { PhoneNumberUtil, PhoneNumberFormat } from 'google-libphonenumber';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private readonly phoneUtil = PhoneNumberUtil.getInstance();

  constructor(@InjectModel(User.name) private readonly userModel: Model<UserDocument>) {}

  private normalizePhoneNumber(rawPhone: string): string | null {
    if (!rawPhone || rawPhone.trim().length === 0) return null;
    try {
      let formatted = rawPhone.trim();
      if (!formatted.startsWith('+')) {
        formatted = `+${formatted}`;
      }
      const parsed = this.phoneUtil.parseAndKeepRawInput(formatted, 'IN');
      if (this.phoneUtil.isValidNumber(parsed)) {
        return this.phoneUtil.format(parsed, PhoneNumberFormat.E164);
      }
      return formatted;
    } catch (_) {
      return rawPhone.trim();
    }
  }

  /**
   * Configurable Multi-Provider Sync:
   * Supports Firebase Phone OTP, Google Sign-In, and Email/Password.
   */
  async syncUser(firebaseUser: any, dto: SyncUserDto) {
    const firebaseUid = firebaseUser.uid;
    const rawPhone = firebaseUser.phone_number;
    const email = firebaseUser.email || dto.email;

    const normalizedPhone = rawPhone ? this.normalizePhoneNumber(rawPhone) : null;

    if (!normalizedPhone && !email) {
      throw new BadRequestException('Firebase user must have a verified phone number or email address.');
    }

    // 1. Primary Lookup: Search by unique firebaseUid
    let user = await this.userModel.findOne({ firebaseUid });

    if (!user) {
      // 2. Secondary Lookup: Search by verified phoneNumber or email for legacy linking
      const queryOr: any[] = [];
      if (normalizedPhone) queryOr.push({ phoneNumber: normalizedPhone });
      if (email) queryOr.push({ email: email.toLowerCase().trim() });

      user = await this.userModel.findOne({ $or: queryOr });

      if (user) {
        // Safe Account Linking Guard: Ensure account isn't already bound to a different active firebaseUid
        if (user.firebaseUid && user.firebaseUid !== firebaseUid) {
          throw new ForbiddenException({
            statusCode: 403,
            errorCode: 'ACCOUNT_CONFLICT',
            message: 'This user account is already linked to a different authentication identity.',
          });
        }

        user.firebaseUid = firebaseUid;
        if (normalizedPhone && !user.phoneNumber) user.phoneNumber = normalizedPhone;
        if (email && !user.email) user.email = email.toLowerCase().trim();
        if (user.migrationStatus === 'PENDING_LINK') {
          user.migrationStatus = 'COMPLETED';
        }
        if (dto.name && !user.name) user.name = dto.name;
        if (dto.photoUrl) user.photoUrl = dto.photoUrl;
        await user.save();
        this.logger.log(`Linked firebaseUid ${firebaseUid} to existing profile ${user._id}`);
      } else {
        // 3. New User Provisioning
        let preacherId = null;
        if (dto.preacherId) {
          preacherId = dto.preacherId;
        } else if (dto.preacherCode) {
          const preacher = await this.userModel.findOne({
            preacherCode: dto.preacherCode.toUpperCase().trim(),
            role: 'preacher',
          });
          if (preacher) {
            preacherId = preacher._id;
          }
        }

        let assignedRole = 'folk_boy';
        if (dto.role) {
          if (dto.role.includes('residency')) assignedRole = 'residency';
          else if (dto.role.includes('preacher')) assignedRole = 'preacher';
          else assignedRole = 'folk_boy';
        }

        const phoneToStore = normalizedPhone || (dto.phoneNumber ? dto.phoneNumber.trim() : null) || `TEMP_${Date.now()}_${Math.floor(Math.random() * 10000)}`;

        user = await this.userModel.create({
          firebaseUid,
          phoneNumber: phoneToStore,
          name: dto.name,
          email: email ? email.toLowerCase().trim() : null,
          role: assignedRole,
          status: 'ACTIVE',
          preacherId,
          photoUrl: dto.photoUrl || null,
        });

        this.logger.log(`Provisioned new user profile ${user._id} for ${normalizedPhone || email}`);
      }
    }

    if (user.isBlocked || user.status === 'BLOCKED') {
      throw new ForbiddenException({
        statusCode: 403,
        errorCode: 'ACCOUNT_BLOCKED',
        message: 'Your account has been blocked by an administrator.',
      });
    }

    return user;
  }

  async verifyLegacyAccount(firebaseUser: any, dto: VerifyLegacyDto) {
    const firebaseUid = firebaseUser.uid;
    const legacyUser = await this.userModel.findOne({
      email: dto.legacyEmail.toLowerCase().trim(),
      migrationStatus: 'PENDING_LINK',
    });

    if (!legacyUser) {
      throw new BadRequestException('Legacy profile matching provided email was not found or already linked.');
    }

    if (legacyUser.firebaseUid && legacyUser.firebaseUid !== firebaseUid) {
      throw new ForbiddenException('Legacy account is already bound to another authentication record.');
    }

    legacyUser.firebaseUid = firebaseUid;
    legacyUser.migrationStatus = 'COMPLETED';
    await legacyUser.save();

    this.logger.log(`Verified legacy email ${dto.legacyEmail} linked to firebaseUid ${firebaseUid}`);
    return legacyUser;
  }

  private readonly otpStore = new Map<string, { otp: string; expiresAt: number }>();

  async sendEmailOtp(emailStr: string) {
    const cleanEmail = emailStr.toLowerCase().trim();
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes

    this.otpStore.set(cleanEmail, { otp, expiresAt });
    this.logger.log(`[EMAIL OTP GENERATED] Email: ${cleanEmail} -> OTP: ${otp}`);

    const smtpUser = process.env.SMTP_USER || process.env.EMAIL_USER;
    const smtpPass = process.env.SMTP_PASS || process.env.EMAIL_PASS;

    if (smtpUser && smtpPass) {
      try {
        const nodemailer = require('nodemailer');
        const transporter = nodemailer.createTransport({
          service: 'gmail',
          auth: {
            user: smtpUser,
            pass: smtpPass,
          },
        });

        await transporter.sendMail({
          from: `"Sadhana Tracker" <${smtpUser}>`,
          to: cleanEmail,
          subject: `${otp} is your Sadhana Tracker verification code`,
          html: `
            <div style="font-family: Arial, sans-serif; padding: 20px; color: #333;">
              <h2 style="color: #6366F1;">Hare Krishna!</h2>
              <p>Your 6-digit OTP verification code for <strong>Sadhana Tracker</strong> registration is:</p>
              <div style="background: #F1F5F9; padding: 16px; border-radius: 8px; text-align: center; font-size: 28px; font-weight: bold; letter-spacing: 4px; color: #312E81;">
                ${otp}
              </div>
              <p style="margin-top: 16px; color: #64748B; font-size: 13px;">This code is valid for 10 minutes. If you did not request this, please ignore this email.</p>
            </div>
          `,
        });
        this.logger.log(`Successfully sent OTP email to ${cleanEmail} via SMTP`);
      } catch (mailErr) {
        this.logger.error(`Failed to send email via Nodemailer: ${mailErr.message}`);
      }
    } else {
      this.logger.warn(`SMTP credentials not set in environment. OTP for ${cleanEmail} logged to console: ${otp}`);
    }

    return {
      success: true,
      message: `Verification code sent to ${cleanEmail}`,
    };
  }

  async verifyEmailOtp(emailStr: string, otpCode: string) {
    const cleanEmail = emailStr.toLowerCase().trim();
    const record = this.otpStore.get(cleanEmail);

    if (!record) {
      throw new BadRequestException('No verification code requested for this email address.');
    }

    if (Date.now() > record.expiresAt) {
      this.otpStore.delete(cleanEmail);
      throw new BadRequestException('Verification code has expired. Please request a new code.');
    }

    if (record.otp !== otpCode.trim()) {
      throw new BadRequestException('Invalid 6-digit OTP code. Please check your email and try again.');
    }

    this.otpStore.delete(cleanEmail);
    this.logger.log(`[EMAIL OTP VERIFIED SUCCESS] ${cleanEmail}`);

    return {
      success: true,
      message: 'Email OTP verified successfully.',
    };
  }
}
