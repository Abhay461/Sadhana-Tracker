import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Announcement, AnnouncementDocument } from '../database/schemas/announcements.schema';
import { CreateAnnouncementDto } from './dto/create-announcement.dto';
import { MediaService } from '../media/media.service';

@Injectable()
export class AnnouncementsService {
  constructor(
    @InjectModel(Announcement.name) private readonly announcementModel: Model<AnnouncementDocument>,
    private readonly mediaService: MediaService,
  ) {}

  async createAnnouncement(creatorUser: any, dto: CreateAnnouncementDto) {
    const rawContent = dto.content || '';
    const title = dto.title || (rawContent.length > 0 ? rawContent.split('\n')[0] : 'Announcement');
    const createdBy = creatorUser?._id || creatorUser?.id || null;

    return this.announcementModel.create({
      ...dto,
      title: title,
      createdBy: createdBy,
      isActive: true,
    });
  }

  async getActiveAnnouncements() {
    return this.announcementModel.find({ isActive: true }).sort({ createdAt: -1 }).limit(50);
  }

  async deleteAnnouncement(id: string) {
    const item = await this.announcementModel.findById(id);
    if (item) {
      if (item.banner_url) {
        await this.mediaService.deleteCloudinaryImage(item.banner_url);
      }
      if (item.photo_url) {
        await this.mediaService.deleteCloudinaryImage(item.photo_url);
      }
      await this.announcementModel.deleteOne({ _id: id });
    }
    return { success: true, message: 'Announcement deleted from database & Cloudinary' };
  }
}
