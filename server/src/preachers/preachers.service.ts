import {
  Injectable,
  Logger,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { User, UserDocument } from '../database/schemas/users.schema';
import { SadhanaEntry, SadhanaEntryDocument } from '../database/schemas/sadhana-entries.schema';
import { ApproveStudentDto } from './dto/approve-student.dto';
import { RealtimeService } from '../realtime/realtime.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class PreachersService {
  private readonly logger = new Logger(PreachersService.name);

  constructor(
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
    @InjectModel(SadhanaEntry.name) private readonly sadhanaModel: Model<SadhanaEntryDocument>,
    private readonly realtimeService: RealtimeService,
    private readonly notificationsService?: NotificationsService,
  ) {}

  async getMyStudents(preacher: any, targetPreacherId?: string) {
    try {
      const preacherId = (
        preacher?._id ??
        preacher?.id ??
        preacher?.uid ??
        (typeof preacher === 'string' ? preacher : '')
      ).toString();
      const canViewAll = Boolean(
        preacher?.canViewAllStudents || preacher?.isHeadPreacher || preacher?.role === 'admin'
      );
      const extraUid = (preacher?.firebaseUid ?? preacher?.uid ?? '').toString();

      this.logger.log(
        `[getMyStudents] Request started: preacherId=${preacherId}, role=${preacher?.role}, canViewAll=${canViewAll}, targetPreacherId=${targetPreacherId || 'none'}`
      );

      const buildPreacherCondition = (pId: string, extra?: string) => {
        const matchers: any[] = [];
        if (pId) {
          matchers.push({ preacherId: pId }, { preacher_id: pId });
          if (Types.ObjectId.isValid(pId)) {
            const oid = new Types.ObjectId(pId);
            matchers.push({ preacherId: oid }, { preacher_id: oid });
          }
        }
        if (extra && extra !== pId) {
          matchers.push({ preacherId: extra }, { preacher_id: extra });
          if (Types.ObjectId.isValid(extra)) {
            const extraOid = new Types.ObjectId(extra);
            matchers.push({ preacherId: extraOid }, { preacher_id: extraOid });
          }
        }
        return matchers.length > 0 ? { $or: matchers } : { preacherId: pId };
      };

      let availablePreachers: any[] = [];
      let queryFilter: any = buildPreacherCondition(preacherId, extraUid);

      if (canViewAll) {
        try {
          availablePreachers = await this.userModel
            .find({ role: 'preacher', status: 'ACTIVE' })
            .select('_id name email preacherCode photoUrl phoneNumber')
            .sort({ name: 1 })
            .lean();
        } catch (err) {
          this.logger.warn(`[getMyStudents] Failed to load availablePreachers: ${err.message}`);
          availablePreachers = [];
        }

        if (targetPreacherId && targetPreacherId !== 'all') {
          queryFilter = buildPreacherCondition(targetPreacherId);
        } else {
          // 'all' or empty - fetch all students/members who have a preacher assigned or any student role
          queryFilter = {
            $or: [
              { role: { $in: ['folk_boy', 'residency', 'student', 'user', 'member'] } },
              { preacherId: { $exists: true, $ne: null } },
              { preacher_id: { $exists: true, $ne: null } },
            ],
          };
        }
      }

      let rawStudents: any[] = [];
      try {
        rawStudents = await this.userModel
          .find(queryFilter)
          .populate('preacherId', 'name email preacherCode')
          .select('name email phoneNumber role status photoUrl dob joiningDate isBlocked createdAt preacherId preacher_id whatsapp_number')
          .sort({ name: 1 })
          .lean();
      } catch (populateError) {
        this.logger.warn(`[getMyStudents] Populate failed (${populateError.message}), falling back to unpopulated query`);
        try {
          rawStudents = await this.userModel
            .find(queryFilter)
            .select('name email phoneNumber role status photoUrl dob joiningDate isBlocked createdAt preacherId preacher_id whatsapp_number')
            .sort({ name: 1 })
            .lean();
        } catch (findError) {
          this.logger.error(`[getMyStudents] Direct query failed (${findError.message}), falling back to direct ID match`);
          const fallbackCondition: any = Types.ObjectId.isValid(preacherId)
            ? { $or: [{ preacherId: new Types.ObjectId(preacherId) }, { preacherId }] }
            : { preacherId };
          rawStudents = await this.userModel
            .find(fallbackCondition)
            .select('name email phoneNumber role status photoUrl dob joiningDate isBlocked createdAt preacherId preacher_id whatsapp_number')
            .sort({ name: 1 })
            .lean();
        }
      }

      const students = rawStudents.map((s: any) => ({
        ...s,
        id: s._id ? s._id.toString() : '',
        _id: s._id ? s._id.toString() : '',
        preacherId: s.preacherId || s.preacher_id,
      }));

      const pendingCount = students.filter((s: any) => s.status === 'PENDING_APPROVAL').length;

      this.logger.log(
        `[getMyStudents] Completed successfully: returned ${students.length} students (pending=${pendingCount})`
      );

      return {
        total: students.length,
        pendingCount,
        students,
        canViewAll,
        availablePreachers: (availablePreachers || []).map((p: any) => ({
          id: (p._id ?? p.id ?? '').toString(),
          _id: (p._id ?? p.id ?? '').toString(),
          name: p.name ?? '',
          email: p.email ?? '',
          preacherCode: p.preacherCode ?? '',
        })),
      };
    } catch (fatalError) {
      this.logger.error(`[getMyStudents] Fatal error: ${fatalError.message}`, fatalError.stack);
      throw fatalError;
    }
  }

  async approveStudentAccount(preacher: any, studentId: string, dto: ApproveStudentDto) {
    const student = await this.userModel.findById(studentId);

    if (!student) {
      throw new NotFoundException('Student account not found.');
    }

    const preacherId = (
      preacher?._id ??
      preacher?.id ??
      preacher?.uid ??
      (typeof preacher === 'string' ? preacher : '')
    ).toString();
    const canViewAll = Boolean(
      preacher?.canViewAllStudents || preacher?.isHeadPreacher || preacher?.role === 'admin'
    );
    const studentPreacherId = (student.preacherId?._id ?? student.preacherId ?? (student as any).preacher_id)?.toString() || '';
    const extraUid = (preacher?.firebaseUid ?? preacher?.uid ?? '').toString();

    if (!canViewAll && studentPreacherId !== preacherId && (!extraUid || studentPreacherId !== extraUid)) {
      throw new ForbiddenException('Access denied: Student is not assigned to your preacher group.');
    }

    student.status = dto.status;
    await student.save();

    const res = {
      id: student._id,
      name: student.name,
      status: student.status,
    };
    this.realtimeService?.emit('student_update', 'update', res, { preacherId, studentId });

    if (this.notificationsService && studentId) {
      const isApproved = (dto.status || '').toUpperCase() === 'APPROVED' || (dto.status || '').toUpperCase() === 'ACTIVE';
      const title = isApproved ? 'Account Approved!' : 'Account Status Updated';
      const body = isApproved
        ? 'Your account has been approved by your preacher. You can now access all features.'
        : `Your account status has been updated to ${dto.status}.`;

      this.notificationsService
        .sendMulticastNotification({
          targetUserIds: [studentId.toString()],
          title,
          body,
          dataPayload: {
            category: 'student_account',
            studentId: studentId.toString(),
            status: dto.status,
          },
        })
        .catch((err) => this.logger.error('Failed to send student account approval notification', err));
    }

    return res;
  }

  async getStudentProgress(preacher: any, studentId: string) {
    let student: any;
    try {
      student = await this.userModel.findById(studentId).populate('preacherId', 'name email preacherCode');
    } catch (err) {
      student = await this.userModel.findById(studentId);
    }

    if (!student) {
      throw new NotFoundException('Student account not found.');
    }

    const preacherId = (
      preacher?._id ??
      preacher?.id ??
      preacher?.uid ??
      (typeof preacher === 'string' ? preacher : '')
    ).toString();
    const canViewAll = Boolean(
      preacher?.canViewAllStudents || preacher?.isHeadPreacher || preacher?.role === 'admin'
    );
    const studentPreacherId = student.preacherId?._id
      ? student.preacherId._id.toString()
      : ((student.preacherId ?? (student as any).preacher_id)?.toString() || '');
    const extraUid = (preacher?.firebaseUid ?? preacher?.uid ?? '').toString();

    if (!canViewAll && studentPreacherId !== preacherId && (!extraUid || studentPreacherId !== extraUid)) {
      throw new ForbiddenException('Access denied: Student is not assigned to your preacher group.');
    }

    const recentEntries = await this.sadhanaModel
      .find({ userId: studentId })
      .sort({ logicalDate: -1 })
      .limit(30);

    const totalPointsMonth = recentEntries.reduce((sum, entry) => sum + (entry.totalPoints || 0), 0);

    return {
      student: {
        id: student._id,
        name: student.name,
        email: student.email,
        phoneNumber: student.phoneNumber,
        photoUrl: student.photoUrl,
        role: student.role,
        status: student.status,
        preacher: student.preacherId
          ? {
              id: (student.preacherId as any)._id,
              name: (student.preacherId as any).name,
              preacherCode: (student.preacherId as any).preacherCode,
            }
          : null,
      },
      totalPointsMonth,
      recentEntries,
    };
  }
}
