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

  private async cleanExpiredFestivals() {
    try {
      const todayStr = new Date().toISOString().split('T')[0];
      const res = await this.festivalModel.deleteMany({ dateString: { $lt: todayStr } }).exec();
      if (res.deletedCount && res.deletedCount > 0) {
        console.log(`Cleaned up ${res.deletedCount} expired festival(s) from database.`);
      }
    } catch (err) {
      console.error('Error cleaning expired festivals:', err);
    }
  }

  async createFestival(user: any, dto: CreateFestivalDto) {
    const data: Record<string, any> = {
      title: dto.title,
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
    await this.cleanExpiredFestivals();
    const todayStr = new Date().toISOString().split('T')[0];
    
    const festival = await this.festivalModel
      .findOne({ dateString: todayStr, isActive: true })
      .sort({ createdAt: -1 })
      .exec();

    return festival || null;
  }

  async getAllFestivals() {
    await this.cleanExpiredFestivals();
    return this.festivalModel
      .find({ isActive: true })
      .sort({ dateString: 1, createdAt: -1 })
      .exec();
  }

  async deleteFestival(id: string) {
    const res = await this.festivalModel.findByIdAndDelete(id).exec();
    if (!res) {
      throw new NotFoundException(`Festival with ID ${id} not found`);
    }
    return { success: true, message: 'Festival deleted successfully from database' };
  }
}
