import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { DailyDarshan, DailyDarshanDocument } from '../database/schemas/daily-darshan.schema';
import { CreateDailyDarshanDto } from './dto/create-daily-darshan.dto';

@Injectable()
export class DailyDarshanService {
  constructor(
    @InjectModel(DailyDarshan.name) private readonly darshanModel: Model<DailyDarshanDocument>,
  ) {}

  async createDarshan(user: any, dto: CreateDailyDarshanDto | any) {
    const today = new Date().toISOString().split('T')[0];
    
    let images: string[] = [];
    if (dto.imageUrls && Array.isArray(dto.imageUrls) && dto.imageUrls.length > 0) {
      images = dto.imageUrls;
    } else if (typeof dto.imageUrls === 'string' && dto.imageUrls.trim().length > 0) {
      images = [dto.imageUrls.trim()];
    } else if (dto.imageUrl && typeof dto.imageUrl === 'string' && dto.imageUrl.trim().length > 0) {
      images = [dto.imageUrl.trim()];
    }

    if (images.length === 0) {
      images = ['https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=600&q=80'];
    }

    return this.darshanModel.create({
      title: dto.title || 'Sri Sri Radha Vrindavan Chandra Daily Darshan',
      date: dto.date || today,
      imageUrls: images,
      description: dto.description || dto.message || '',
      createdBy: user?._id || null,
      isActive: true,
    });
  }

  async getTodayDarshan() {
    const today = new Date().toISOString().split('T')[0];
    
    // First try to find today's darshan
    let darshan = await this.darshanModel
      .findOne({ date: today, isActive: true })
      .sort({ createdAt: -1 })
      .exec();

    // Fallback: Return the latest active darshan if today's is not yet uploaded
    if (!darshan) {
      darshan = await this.darshanModel
        .findOne({ isActive: true })
        .sort({ createdAt: -1 })
        .exec();
    }

    return darshan;
  }

  async deleteDarshan(id: string) {
    return this.darshanModel.findByIdAndUpdate(id, { isActive: false }, { new: true });
  }
}
