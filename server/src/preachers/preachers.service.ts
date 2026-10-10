import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { User, UserDocument } from '../database/schemas/users.schema';
import { SadhanaEntry, SadhanaEntryDocument } from '../database/schemas/sadhana-entries.schema';
import { ApproveStudentDto } from './dto/approve-student.dto';
import { RealtimeService } from '../realtime/realtime.service';

@Injectable()
export class PreachersService {
  constructor(
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
    @InjectModel(SadhanaEntry.name) private readonly sadhanaModel: Model<SadhanaEntryDocument>,
    private readonly realtimeService: RealtimeService,
  ) {}

  async getMyStudents(preacher: any, targetPreacherId?: string) {
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

    const buildPreacherCondition = (pId: string, extra?: string) => {
      const matchers: any[] = [];
      if (pId) {
        matchers.push({ preacherId: pId });
        if (Types.ObjectId.isValid(pId)) {
          matchers.push({ preacherId: new Types.ObjectId(pId) });
        }
      }
      if (extra && extra !== pId) {
        matchers.push({ preacherId: extra });
        if (Types.ObjectId.isValid(extra)) {
          matchers.push({ preacherId: new Types.ObjectId(extra) });
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
          ],
        };
      }
    }

    let rawStudents: any[] = [];
    try {
      rawStudents = await this.userModel
        .find(queryFilter)
        .populate('preacherId', 'name email preacherCode')
        .select('name email phoneNumber role status photoUrl dob joiningDate isBlocked createdAt preacherId whatsapp_number')
        .sort({ name: 1 })
        .lean();
    } catch (populateError) {
      // Fallback: If populate fails due to any uncastable preacherId in legacy records, fetch cleanly without populate
      rawStudents = await this.userModel
        .find(queryFilter)
        .select('name email phoneNumber role status photoUrl dob joiningDate isBlocked createdAt preacherId whatsapp_number')
        .sort({ name: 1 })
        .lean();
    }

    const students = rawStudents.map((s: any) => ({
      ...s,
      id: s._id ? s._id.toString() : '',
      _id: s._id ? s._id.toString() : '',
    }));

    const pendingCount = students.filter((s: any) => s.status === 'PENDING_APPROVAL').length;

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
    const studentPreacherId = student.preacherId ? student.preacherId.toString() : '';
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
    this.realtimeService.emit('student_update', 'update', res, { preacherId, studentId });
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
      : (student.preacherId ? student.preacherId.toString() : '');
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
