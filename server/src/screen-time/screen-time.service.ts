import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { ScreenTimeLog, ScreenTimeLogDocument } from '../database/schemas/screen-time-logs.schema';
import { LogScreenTimeDto } from './dto/log-screen-time.dto';

@Injectable()
export class ScreenTimeService {
  constructor(
    @InjectModel(ScreenTimeLog.name) private readonly logModel: Model<ScreenTimeLogDocument>,
  ) {}

  async logScreenTime(userId: string, dto: LogScreenTimeDto) {
    const log = await this.logModel.findOneAndUpdate(
      { userId, date: dto.date },
      {
        $set: {
          totalDurationLabel: dto.totalDurationLabel,
          breakdownDescription: dto.breakdownDescription || '',
        },
      },
      { upsert: true, new: true },
    );
    return log;
  }

  async getMyLogs(userId: string) {
    return this.logModel.find({ userId }).sort({ date: -1 }).limit(30);
  }
}
