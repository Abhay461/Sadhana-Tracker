import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { User, UserDocument } from '../database/schemas/users.schema';
import { UpdateUserProfileDto } from './dto/update-user-profile.dto';

@Injectable()
export class UsersService {
  constructor(@InjectModel(User.name) private readonly userModel: Model<UserDocument>) {}

  async getProfile(userId: string) {
    const user = await this.userModel.findById(userId).populate('preacherId', 'name email photoUrl whatsapp_number');
    if (!user) {
      throw new NotFoundException('User profile not found.');
    }
    return user;
  }

  async updateProfile(userId: string, dto: UpdateUserProfileDto) {
    const updateData: Record<string, any> = {};
    if (dto.name) updateData.name = dto.name;
    if (dto.photoUrl) updateData.photoUrl = dto.photoUrl;
    if (dto.email) updateData.email = dto.email;
    if (dto.dob) updateData.dob = new Date(dto.dob);
    if (dto.joiningDate) updateData.joiningDate = new Date(dto.joiningDate);

    const user = await this.userModel.findByIdAndUpdate(userId, { $set: updateData }, { new: true });
    if (!user) {
      throw new NotFoundException('User profile not found.');
    }
    return user;
  }
}
