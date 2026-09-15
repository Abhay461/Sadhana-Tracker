import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Festival, FestivalDocument } from '../database/schemas/festivals.schema';
import { CreateFestivalDto } from './dto/create-festival.dto';

@Injectable()
export class FestivalsService {
  constructor(
    @InjectModel(Festival.name) private readonly festivalModel: Model<FestivalDocument>,
  ) {}

  async createFestival(user: any, dto: CreateFestivalDto) {
    const data: Record<string, any> = {
      title: dto.title,
      description: dto.description || '',
      imageUrl: dto.imageUrl || '',
      dateString: dto.dateString,
      isActive: dto.isActive !== undefined ? dto.isActive : true,
    };

    if (user?._id) {
      data.createdBy = user._id;
    }

    return this.festivalModel.create(data);
  }

  async getTodayFestival() {
    const todayStr = new Date().toISOString().split('T')[0];
    
    // Find active festival matching today's dateString exactly
    const festival = await this.festivalModel
      .findOne({ dateString: todayStr, isActive: true })
      .sort({ createdAt: -1 })
      .exec();

    return festival || null;
  }

  async getAllFestivals() {
    return this.festivalModel
      .find({ isActive: true })
      .sort({ dateString: -1, createdAt: -1 })
      .exec();
  }

  async deleteFestival(id: string) {
    const res = await this.festivalModel.findByIdAndUpdate(id, { isActive: false }, { new: true }).exec();
    if (!res) {
      throw new NotFoundException(`Festival with ID ${id} not found`);
    }
    return { success: true, message: 'Festival deleted successfully' };
  }
}
