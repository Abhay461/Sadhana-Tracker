import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { DailyDarshan, DailyDarshanDocument } from '../database/schemas/daily_darshan.schema';
import { CreateDailyDarshanDto } from './dto/create-daily-darshan.dto';
import { MediaService } from '../media/media.service';

@Injectable()
export class DailyDarshanService {
  constructor(
    @InjectModel(DailyDarshan.name) private readonly darshanModel: Model<DailyDarshanDocument>,
    private readonly mediaService: MediaService,
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

    const darshanData: Record<string, any> = {
      title: dto.title || 'Sri Sri Radha Vrindavan Chandra Daily Darshan',
      date: dto.date || today,
      imageUrls: images,
      description: dto.description || dto.message || '',
      isActive: true,
    };

    if (user?._id) {
      darshanData.createdBy = user._id;
    }

    return this.darshanModel.create(darshanData);
  }

  async getTodayDarshan() {
    const today = new Date().toISOString().split('T')[0];
    
    let darshan = await this.darshanModel
      .findOne({ date: today, isActive: true })
      .sort({ createdAt: -1 })
      .exec();

    if (!darshan) {
      darshan = await this.darshanModel
        .findOne({ isActive: true })
        .sort({ createdAt: -1 })
        .exec();
    }

    return darshan;
  }

  async getAllDarshans() {
    return this.darshanModel.find().sort({ createdAt: -1 }).limit(100).exec();
  }

  async deleteDarshan(id: string) {
    const item = await this.darshanModel.findById(id);
    if (item) {
      if (item.imageUrls && Array.isArray(item.imageUrls)) {
        for (const url of item.imageUrls) {
          await this.mediaService.deleteCloudinaryImage(url);
        }
      }
      await this.darshanModel.deleteOne({ _id: id });
    }
    return { success: true, message: 'Daily Darshan deleted from database & Cloudinary' };
  }
}
