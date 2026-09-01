import {
  Injectable,
  ForbiddenException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { SadhanaEntry, SadhanaEntryDocument } from '../database/schemas/sadhana-entries.schema';
import { LogSadhanaDto } from './dto/log-sadhana.dto';
import { LockDayDto } from './dto/lock-day.dto';

@Injectable()
export class SadhanaService {
  constructor(
    @InjectModel(SadhanaEntry.name) private readonly sadhanaModel: Model<SadhanaEntryDocument>,
  ) {}

  private calculatePoints(activities: any): number {
    let points = 0;
    if (!activities) return 0;

    if (activities.wakeUpTime) points += 5;
    if (activities.sleepTime) points += 5;
    if (activities.manglaArti?.attended) points += 10;
    if (activities.chanting?.rounds) {
      points += activities.chanting.rounds >= 16 ? 10 : 5;
    }
    if (activities.onlineSession?.attended) points += 5;
    if (activities.bookReading?.bookName) points += 5;
    if (activities.service?.serviceName) points += 5;
    if (activities.templeVisit?.visited) points += 5;
    if (activities.srimadBhagavatamClass?.attended) points += 5;
    if (activities.bhagavadGitaClass?.attended) points += 5;
    if (activities.ekadashiFasting?.fastingType && activities.ekadashiFasting.fastingType !== 'No Fasting') {
      points += 10;
    }

    return points;
  }

  private computeLogicalDate(dateString: string, offsetMinutes: number = 330): Date {
    // Store the instant of midnight in the user's local timezone, expressed in UTC.
    const [year, month, day] = dateString.split('-').map((v) => parseInt(v, 10));
    return new Date(Date.UTC(year, month - 1, day, 0, 0, 0) - offsetMinutes * 60_000);
  }

  async logSadhana(userId: string, dto: LogSadhanaDto) {
    const offset = dto.timezoneOffsetMinutes ?? 330;
    const logicalDate = this.computeLogicalDate(dto.dateString, offset);

    // 1. Check existing record for lock status
    const existing = await this.sadhanaModel.findOne({
      userId,
      dateString: dto.dateString,
    });

    if (existing && existing.isLocked) {
      throw new ForbiddenException('Sadhana logging for this date has been locked by your preacher.');
    }

    // 2. Merge activities if updating
    const mergedActivities = existing
      ? { ...existing.activities, ...dto.activities }
      : dto.activities;

    const totalPoints = this.calculatePoints(mergedActivities);

    // 3. Upsert sadhana entry using compound unique index { userId, dateString }
    const updatedEntry = await this.sadhanaModel.findOneAndUpdate(
      { userId, dateString: dto.dateString },
      {
        $set: {
          logicalDate,
          timezoneOffsetMinutes: offset,
          activities: mergedActivities,
          totalPoints,
        },
      },
      { new: true, upsert: true, runValidators: true },
    );

    return updatedEntry;
  }

  async getHistory(userId: string, page = 1, limit = 30) {
    const skip = (page - 1) * limit;
    const items = await this.sadhanaModel
      .find({ userId })
      .sort({ logicalDate: -1 })
      .skip(skip)
      .limit(limit);

    const total = await this.sadhanaModel.countDocuments({ userId });

    return {
      items,
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getByDate(userId: string, dateString: string) {
    const entry = await this.sadhanaModel.findOne({ userId, dateString });
    if (!entry) {
      return { userId, dateString, logged: false, activities: {} };
    }
    return entry;
  }

  async lockOrUnlockDay(preacherId: string, dto: LockDayDto) {
    const entry = await this.sadhanaModel.findOneAndUpdate(
      { userId: dto.userId, dateString: dto.dateString },
      {
        $set: {
          isLocked: dto.isLocked,
          unlockedBy: dto.isLocked ? null : preacherId,
        },
      },
      { new: true, upsert: true },
    );
    return entry;
  }
}
