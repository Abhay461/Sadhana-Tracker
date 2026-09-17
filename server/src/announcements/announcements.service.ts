import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Announcement, AnnouncementDocument } from '../database/schemas/announcements.schema';
import { CreateAnnouncementDto } from './dto/create-announcement.dto';
import { MediaService } from '../media/media.service';
import { RealtimeService } from '../realtime/realtime.service';

@Injectable()
export class AnnouncementsService {
  constructor(
    @InjectModel(Announcement.name) private readonly announcementModel: Model<AnnouncementDocument>,
    private readonly mediaService: MediaService,
    private readonly realtimeService: RealtimeService,
  ) {}

  async createAnnouncement(creatorUser: any, dto: CreateAnnouncementDto) {
    const rawContent = dto.content || '';
    const title = dto.title || (rawContent.length > 0 ? rawContent.split('\n')[0] : 'Announcement');
    const createdBy = creatorUser?._id || creatorUser?.id || null;

    const res = await this.announcementModel.create({
      ...dto,
      title: title,
      createdBy: createdBy,
      isActive: true,
    });
    this.realtimeService.emit('announcement_update', 'create', res);
    return res;
  }

  async getActiveAnnouncements() {
    return this.announcementModel.find({ isActive: true }).sort({ createdAt: -1 }).limit(50);
  }

  async deleteAnnouncement(id: string) {
    const item = await this.announcementModel.findById(id);
    if (item) {
      const banner = item.bannerUrl || (item as any).banner_url || (item as any).photo_url || (item as any).imageUrl;
      if (banner) {
        await this.mediaService.deleteCloudinaryImage(banner);
      }
      await this.announcementModel.deleteOne({ _id: id });
    }
    const res = { success: true, id, message: 'Announcement deleted from database & Cloudinary' };
    this.realtimeService.emit('announcement_update', 'delete', res);
    return res;
  }
}
