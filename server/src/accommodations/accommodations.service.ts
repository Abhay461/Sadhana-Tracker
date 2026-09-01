import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Accommodation, AccommodationDocument } from '../database/schemas/accommodations.schema';
import { User, UserDocument } from '../database/schemas/users.schema';
import { CreateAccommodationDto } from './dto/create-accommodation.dto';
import { UpdateAccommodationStatusDto } from './dto/update-accommodation-status.dto';

@Injectable()
export class AccommodationsService {
  constructor(
    @InjectModel(Accommodation.name) private readonly accommodationModel: Model<AccommodationDocument>,
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
  ) {}

  async createRequest(user: any, dto: CreateAccommodationDto) {
    if (!user.preacherId) {
      throw new BadRequestException('You do not have an assigned preacher yet to submit accommodation requests.');
    }

    const accommodation = await this.accommodationModel.create({
      userId: user._id,
      preacherId: user.preacherId,
      requestDetails: dto.requestDetails,
      status: 'PENDING',
    });

    return accommodation;
  }

  async getMyRequests(userId: string) {
    return this.accommodationModel.find({ userId }).sort({ createdAt: -1 });
  }

  async getPreacherQueue(preacherId: string) {
    return this.accommodationModel
      .find({ preacherId })
      .populate('userId', 'name email phoneNumber photoUrl')
      .sort({ createdAt: -1 });
  }

  async updateStatus(preacherId: string, id: string, dto: UpdateAccommodationStatusDto) {
    const item = await this.accommodationModel.findById(id);
    if (!item) {
      throw new NotFoundException('Accommodation request not found.');
    }

    if (item.preacherId.toString() !== preacherId.toString()) {
      throw new ForbiddenException('Access denied: Request is not assigned to your preacher queue.');
    }

    item.status = dto.status;
    if (dto.assignedRoom) {
      item.assignedRoom = dto.assignedRoom;
    }
    await item.save();

    return item;
  }
}
