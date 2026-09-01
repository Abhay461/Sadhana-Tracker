import {
  Injectable,
  Logger,
  BadRequestException,
  InternalServerErrorException,
} from '@nestjs/common';
import { InjectModel, InjectConnection } from '@nestjs/mongoose';
import { Model, Connection } from 'mongoose';
import { User, UserDocument } from '../database/schemas/users.schema';
import { AuditLog, AuditLogDocument } from '../database/schemas/audit-logs.schema';
import { CreatePreacherDto } from './dto/create-preacher.dto';
import { FirebaseService } from '../firebase/firebase.service';
import { PhoneNumberUtil, PhoneNumberFormat } from 'google-libphonenumber';

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);
  private readonly phoneUtil = PhoneNumberUtil.getInstance();

  constructor(
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
    @InjectModel(AuditLog.name) private readonly auditLogModel: Model<AuditLogDocument>,
    @InjectConnection() private readonly connection: Connection,
    private readonly firebaseService: FirebaseService,
  ) {}

  private generatePreacherCode(): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let result = '';
    for (let i = 0; i < 6; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return `PRCH-${result}`;
  }

  private normalizePhone(rawPhone: string): string {
    try {
      if (!rawPhone.startsWith('+')) rawPhone = `+${rawPhone}`;
      const parsed = this.phoneUtil.parseAndKeepRawInput(rawPhone, 'IN');
      return this.phoneUtil.format(parsed, PhoneNumberFormat.E164);
    } catch (_) {
      return rawPhone.trim();
    }
  }

  async createPreacher(adminUser: any, dto: CreatePreacherDto) {
    const normalizedPhone = this.normalizePhone(dto.phoneNumber);

    const existingUser = await this.userModel.findOne({
      $or: [{ phoneNumber: normalizedPhone }, { email: dto.email.toLowerCase().trim() }],
    });

    if (existingUser) {
      throw new BadRequestException('A user with this phone number or email already exists.');
    }

    const preacherCode = this.generatePreacherCode();
    let createdFirebaseUid: string | null = null;

    // STEP 1: Create Firebase Auth User via Admin SDK
    try {
      const fbUser = await this.firebaseService.getAuth().createUser({
        email: dto.email.toLowerCase().trim(),
        phoneNumber: normalizedPhone,
        password: dto.password,
        displayName: dto.name,
      });
      createdFirebaseUid = fbUser.uid;
    } catch (e) {
      this.logger.error(`Firebase user creation failed: ${e.message}`);
      throw new BadRequestException(`Firebase account creation failed: ${e.message}`);
    }

    // STEP 2 & 3: Create MongoDB User Profile + Audit Log using Mongoose Session Transaction
    const session = await this.connection.startSession();
    session.startTransaction();

    try {
      const preacherProfiles = await this.userModel.create(
        [
          {
            firebaseUid: createdFirebaseUid,
            phoneNumber: normalizedPhone,
            email: dto.email.toLowerCase().trim(),
            name: dto.name,
            role: 'preacher',
            status: 'ACTIVE',
            preacherCode,
          },
        ],
        { session },
      );

      const preacher = preacherProfiles[0];

      await this.auditLogModel.create(
        [
          {
            performedBy: adminUser._id,
            action: 'CREATE_PREACHER',
            targetUserId: preacher._id,
            metadata: { preacherCode, email: dto.email, phone: normalizedPhone },
          },
        ],
        { session },
      );

      await session.commitTransaction();
      session.endSession();

      this.logger.log(`Admin ${adminUser._id} created Preacher ${preacher._id} (${preacherCode})`);

      return {
        id: preacher._id,
        name: preacher.name,
        email: preacher.email,
        phoneNumber: preacher.phoneNumber,
        preacherCode: preacher.preacherCode,
        role: preacher.role,
        status: preacher.status,
      };
    } catch (dbError) {
      this.logger.error(`MongoDB transaction failed during preacher creation. Executing Saga compensating rollback: ${dbError.message}`);
      await session.abortTransaction();
      session.endSession();

      // COMPENSATING ACTION: Delete orphaned Firebase Auth user
      if (createdFirebaseUid) {
        try {
          await this.firebaseService.getAuth().deleteUser(createdFirebaseUid);
          this.logger.log(`Compensating rollback: Deleted orphaned Firebase user ${createdFirebaseUid}`);
        } catch (fbRollbackErr) {
          this.logger.error(`CRITICAL: Failed to delete orphaned Firebase user ${createdFirebaseUid}: ${fbRollbackErr.message}`);
        }
      }

      throw new InternalServerErrorException('Failed to create preacher profile in database.');
    }
  }

  async getAllPreachers() {
    const preachers = await this.userModel.find({ role: 'preacher' }).sort({ name: 1 });
    const students = await this.userModel.find({ preacherId: { $ne: null } }).select('name role status preacherId whatsapp_number photoUrl');

    const grouped: Record<string, any[]> = {};
    for (const student of students) {
      const pId = student.preacherId.toString();
      if (!grouped[pId]) grouped[pId] = [];
      grouped[pId].push(student);
    }

    return preachers.map((p) => ({
      ...p.toObject(),
      assignedStudentsCount: grouped[p._id.toString()]?.length || 0,
      students: grouped[p._id.toString()] || [],
    }));
  }
}
