import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Accommodation, AccommodationDocument } from '../database/schemas/accommodations.schema';
import { User, UserDocument } from '../database/schemas/users.schema';
import { CreateAccommodationDto } from './dto/create-accommodation.dto';
import { UpdateAccommodationStatusDto } from './dto/update-accommodation-status.dto';
import { RealtimeService } from '../realtime/realtime.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class AccommodationsService {
  constructor(
    @InjectModel(Accommodation.name) private readonly accommodationModel: Model<AccommodationDocument>,
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
    private readonly realtimeService: RealtimeService,
    private readonly notificationsService?: NotificationsService,
  ) {}

  async createRequest(user: any, dto: CreateAccommodationDto) {
    let rawPreacherId: any = dto.preacherId || dto.preacher_id || user.preacherId || null;

    if (!rawPreacherId && user._id) {
      const studentUser = await this.userModel.findById(user._id).select('preacherId').lean();
      if (studentUser && studentUser.preacherId) {
        rawPreacherId = studentUser.preacherId;
      }
    }

    let preacherIdObj: Types.ObjectId | null = null;
    if (rawPreacherId) {
      const idStr = (rawPreacherId._id || rawPreacherId.id || rawPreacherId).toString();
      if (Types.ObjectId.isValid(idStr)) {
        preacherIdObj = new Types.ObjectId(idStr);
      }
    }

    if (!preacherIdObj) {
      const defaultPreacher = await this.userModel
        .findOne({ role: { $in: ['preacher', 'admin'] }, status: 'ACTIVE' })
        .select('_id')
        .lean();
      if (defaultPreacher) {
        preacherIdObj = defaultPreacher._id as Types.ObjectId;
      }
    }

    const userIdObj = Types.ObjectId.isValid(user._id.toString()) ? new Types.ObjectId(user._id.toString()) : user._id;

    const accommodation = await this.accommodationModel.create({
      userId: userIdObj,
      preacherId: preacherIdObj || null,
      requestDetails: dto.requestDetails,
      status: 'PENDING',
    });

    console.log(`📌 [ACCOMMODATION BOOKING CREATED]: BookingID=${accommodation._id}, StudentID=${user._id}, PreacherID=${preacherIdObj?.toString() || 'UNASSIGNED'}`);

    this.realtimeService?.emit('accommodation_update', 'create', accommodation, {
      preacherId: preacherIdObj?.toString(),
      studentId: user._id?.toString(),
    });

    if (preacherIdObj && this.notificationsService) {
      const studentName = user.name || 'A student';
      const cleanDetails = (dto.requestDetails || '').replace(/\r?\n/g, ' • ');
      console.log(`📌 [ACCOMMODATION SENDING PUSH NOTIFICATION]: PreacherID=${preacherIdObj.toString()}`);
      this.notificationsService
        .sendMulticastNotification({
          targetUserIds: [preacherIdObj.toString()],
          title: 'Accommodation Request',
          body: `${studentName} requested accommodation: ${cleanDetails}`,
          dataPayload: {
            category: 'accommodation',
            accommodationId: accommodation._id.toString(),
            studentId: user._id.toString(),
          },
        })
        .then((res) => console.log('📌 [ACCOMMODATION NOTIFICATION SENT]:', res))
        .catch((err) => console.error('Failed to send accommodation push notification:', err));
    }

    return accommodation;
  }

  async getMyRequests(userId: string) {
    const userIdObj = Types.ObjectId.isValid(userId) ? new Types.ObjectId(userId) : userId;
    const items = await this.accommodationModel.find({ $or: [{ userId: userIdObj }, { userId }] }).sort({ createdAt: -1 });
    console.log(`📌 [ACCOMMODATION MY REQUESTS RETRIEVED]: StudentID=${userId}, Count=${items.length}`);
    return items;
  }

  async getPreacherQueue(preacher: any) {
    const preacherId = preacher._id ? preacher._id.toString() : preacher.toString();
    const canViewAll = Boolean(
      preacher.canViewAllStudents || preacher.isHeadPreacher || preacher.role === 'admin'
    );

    if (canViewAll) {
      return this.accommodationModel
        .find({})
        .populate('userId', 'name email phoneNumber photoUrl')
        .sort({ createdAt: -1 });
    }

    const preacherIdObj = Types.ObjectId.isValid(preacherId) ? new Types.ObjectId(preacherId) : preacherId;
    const assignedStudents = await this.userModel.find({ preacherId: preacherIdObj }).select('_id').lean();
    const studentIds: any[] = assignedStudents.map((s) => s._id);

    const items = await this.accommodationModel
      .find({
        $or: [
          { preacherId: preacherIdObj },
          { preacherId: preacherId },
          { userId: { $in: studentIds } },
          { preacherId: null },
          { preacherId: { $exists: false } },
        ],
      })
      .populate('userId', 'name email phoneNumber photoUrl')
      .sort({ createdAt: -1 });

    console.log(`📌 [ACCOMMODATION QUEUE RETRIEVED]: PreacherID=${preacherId}, Count=${items.length}`);
    return items;
  }

  async updateStatus(preacher: any, id: string, dto: UpdateAccommodationStatusDto) {
    const item = await this.accommodationModel.findById(id);
    if (!item) {
      throw new NotFoundException('Accommodation request not found.');
    }

    const preacherId = preacher._id ? preacher._id.toString() : preacher.toString();
    const canViewAll = Boolean(
      preacher.canViewAllStudents || preacher.isHeadPreacher || preacher.role === 'admin'
    );

    if (!canViewAll) {
      const itemPreacherIdStr = item.preacherId?.toString();
      if (itemPreacherIdStr && itemPreacherIdStr !== preacherId) {
        throw new ForbiddenException('Access denied: Request is assigned to another preacher queue.');
      }
      if (!itemPreacherIdStr) {
        const student = await this.userModel.findById(item.userId).select('preacherId').lean();
        if (student?.preacherId && student.preacherId.toString() !== preacherId) {
          throw new ForbiddenException('Access denied: Request is assigned to another preacher queue.');
        }
      }
    }

    item.status = dto.status;
    if (dto.assignedRoom) {
      item.assignedRoom = dto.assignedRoom;
    }
    await item.save();

    console.log(`📌 [ACCOMMODATION STATUS UPDATED]: BookingID=${item._id}, PreacherID=${preacherId}, Status=${item.status}, AssignedRoom=${item.assignedRoom || 'NONE'}`);

    this.realtimeService?.emit('accommodation_update', 'update', item, {
      preacherId: preacherId?.toString(),
      studentId: item.userId?.toString(),
    });

    return item;
  }
}
