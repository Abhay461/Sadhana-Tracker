import { Injectable, NotFoundException, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { User, UserDocument } from '../database/schemas/users.schema';
import { UpdateUserProfileDto } from './dto/update-user-profile.dto';
import { FirebaseService } from '../firebase/firebase.service';
import { RealtimeService } from '../realtime/realtime.service';

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
    private readonly firebaseService: FirebaseService,
    private readonly realtimeService: RealtimeService,
  ) {}

  async getProfile(userId: string) {
    const user = await this.userModel.findById(userId).populate('preacherId', 'name email photoUrl phoneNumber whatsapp_number');
    if (!user) {
      throw new NotFoundException('User profile not found.');
    }
    return user;
  }

  async updateProfile(userId: string, dto: UpdateUserProfileDto) {
    const updateData: Record<string, any> = {};
    if (dto.name) updateData.name = dto.name;
    const photoUrl = dto.photoUrl || dto.photo_url;
    if (photoUrl) updateData.photoUrl = photoUrl;
    if (dto.email) updateData.email = dto.email;
    if (dto.phoneNumber) {
      updateData.phoneNumber = dto.phoneNumber;
      updateData.whatsapp_number = dto.phoneNumber;
    }
    if (dto.whatsapp_number) {
      updateData.whatsapp_number = dto.whatsapp_number;
    }
    if (dto.dob) updateData.dob = new Date(dto.dob);
    if (dto.joiningDate || dto.joining_date) {
      const jDate = dto.joiningDate || dto.joining_date;
      updateData.joiningDate = new Date(jDate);
      updateData.joining_date = new Date(jDate);
    }
    if (dto.preacherId) updateData.preacherId = dto.preacherId;
    if (dto.occupation) updateData.occupation = dto.occupation;
    if (dto.college) updateData.college = dto.college;
    if (dto.courseYear) updateData.courseYear = dto.courseYear;
    if (dto.city) updateData.city = dto.city;

    const user = await this.userModel.findByIdAndUpdate(userId, { $set: updateData }, { new: true }).populate('preacherId', 'name email photoUrl phoneNumber whatsapp_number');
    if (!user) {
      throw new NotFoundException('User profile not found.');
    }
    this.realtimeService.emit('student_update', 'profile_update', user, {
      preacherId: (user.preacherId as any)?._id?.toString() ?? (user.preacherId as any)?.toString(),
      studentId: userId,
    });
    return user;
  }

  async getPublicPreachers() {
    const preachers = await this.userModel
      .find({ role: 'preacher', status: 'ACTIVE' })
      .select('_id name email preacherCode photoUrl phoneNumber firebaseUid')
      .sort({ name: 1 });

    const validPreachers: any[] = [];

    for (const p of preachers) {
      if (p.firebaseUid) {
        try {
          await this.firebaseService.getAuth().getUser(p.firebaseUid);
          validPreachers.push(p);
        } catch (err: any) {
          if (err.code === 'auth/user-not-found') {
            this.logger.warn(`Preacher ${p.name} (${p._id}) not found in Firebase Auth. Deactivating orphan in MongoDB.`);
            await this.userModel.findByIdAndUpdate(p._id, { status: 'DEACTIVATED', isBlocked: true });
            continue;
          }
          validPreachers.push(p);
        }
      } else {
        validPreachers.push(p);
      }
    }

    return validPreachers.map((p) => ({
      id: p._id.toString(),
      _id: p._id.toString(),
      name: p.name,
      email: p.email,
      preacherCode: p.preacherCode,
      photoUrl: p.photoUrl,
      phoneNumber: p.phoneNumber,
      whatsapp_number: p.phoneNumber,
    }));
  }
}
