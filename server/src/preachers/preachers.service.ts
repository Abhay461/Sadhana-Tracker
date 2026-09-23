import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
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
    const preacherId = preacher._id ? preacher._id.toString() : preacher.toString();
    const canViewAll = Boolean(
      preacher.canViewAllStudents || preacher.isHeadPreacher || preacher.role === 'admin'
    );

    let availablePreachers: any[] = [];
    let queryFilter: any = { preacherId };

    if (canViewAll) {
      availablePreachers = await this.userModel
        .find({ role: 'preacher', status: 'ACTIVE' })
        .select('_id name email preacherCode photoUrl phoneNumber')
        .sort({ name: 1 });

      if (targetPreacherId && targetPreacherId !== 'all') {
        queryFilter = { preacherId: targetPreacherId };
      } else {
        // 'all' or empty - fetch all students/members who have a preacher assigned or any student role
        queryFilter = {
          role: { $in: ['folk_boy', 'residency', 'student', 'user', 'member'] },
        };
      }
    }

    const students = await this.userModel
      .find(queryFilter)
      .populate('preacherId', 'name email preacherCode')
      .select('name email phoneNumber role status photoUrl dob joiningDate isBlocked createdAt preacherId')
      .sort({ name: 1 });

    const pendingCount = students.filter((s) => s.status === 'PENDING_APPROVAL').length;

    return {
      total: students.length,
      pendingCount,
      students,
      canViewAll,
      availablePreachers: availablePreachers.map((p) => ({
        id: p._id.toString(),
        _id: p._id.toString(),
        name: p.name,
        email: p.email,
        preacherCode: p.preacherCode,
      })),
    };
  }

  async approveStudentAccount(preacher: any, studentId: string, dto: ApproveStudentDto) {
    const student = await this.userModel.findById(studentId);

    if (!student) {
      throw new NotFoundException('Student account not found.');
    }

    const preacherId = preacher._id ? preacher._id.toString() : preacher.toString();
    const canViewAll = Boolean(
      preacher.canViewAllStudents || preacher.isHeadPreacher || preacher.role === 'admin'
    );

    if (!canViewAll && student.preacherId?.toString() !== preacherId) {
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
    const student = await this.userModel.findById(studentId).populate('preacherId', 'name email preacherCode');

    if (!student) {
      throw new NotFoundException('Student account not found.');
    }

    const preacherId = preacher._id ? preacher._id.toString() : preacher.toString();
    const canViewAll = Boolean(
      preacher.canViewAllStudents || preacher.isHeadPreacher || preacher.role === 'admin'
    );

    if (!canViewAll && student.preacherId?.toString() !== preacherId) {
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
