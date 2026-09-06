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

  async createDarshan(user: any, dto: CreateDailyDarshanDto) {
    return this.darshanModel.create({
      ...dto,
      createdBy: user._id,
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
