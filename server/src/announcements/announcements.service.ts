import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Announcement, AnnouncementDocument } from '../database/schemas/announcements.schema';
import { CreateAnnouncementDto } from './dto/create-announcement.dto';

@Injectable()
export class AnnouncementsService {
  constructor(
    @InjectModel(Announcement.name) private readonly announcementModel: Model<AnnouncementDocument>,
  ) {}

  async createAnnouncement(creatorUser: any, dto: CreateAnnouncementDto) {
    return this.announcementModel.create({
      ...dto,
      createdBy: creatorUser._id,
      isActive: true,
    });
  }

  async getActiveAnnouncements() {
    return this.announcementModel.find({ isActive: true }).sort({ createdAt: -1 }).limit(30);
  }
}
