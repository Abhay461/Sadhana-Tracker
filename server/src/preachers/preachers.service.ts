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

@Injectable()
export class PreachersService {
  constructor(
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
    @InjectModel(SadhanaEntry.name) private readonly sadhanaModel: Model<SadhanaEntryDocument>,
  ) {}

  async getMyStudents(preacherId: string) {
    const students = await this.userModel
      .find({ preacherId })
      .select('name email phoneNumber role status photoUrl dob joiningDate isBlocked createdAt')
      .sort({ name: 1 });

    const pendingCount = students.filter((s) => s.status === 'PENDING_APPROVAL').length;

    return {
      total: students.length,
      pendingCount,
      students,
    };
  }

  async approveStudentAccount(preacherId: string, studentId: string, dto: ApproveStudentDto) {
    const student = await this.userModel.findById(studentId);

    if (!student) {
      throw new NotFoundException('Student account not found.');
    }

    if (student.preacherId?.toString() !== preacherId.toString()) {
      throw new ForbiddenException('Access denied: Student is not assigned to your preacher group.');
    }

    student.status = dto.status;
    await student.save();

    return {
      id: student._id,
      name: student.name,
      status: student.status,
    };
  }

  async getStudentProgress(preacherId: string, studentId: string) {
    const student = await this.userModel.findById(studentId);

    if (!student) {
      throw new NotFoundException('Student account not found.');
    }

    if (student.preacherId?.toString() !== preacherId.toString()) {
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
      },
      totalPointsMonth,
      recentEntries,
    };
  }
}
