import {
  Controller,
  Get,
  Post,
  Body,
} from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { AnnouncementsService } from './announcements.service';
import { CreateAnnouncementDto } from './dto/create-announcement.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Announcements & Sessions')
@Controller('announcements')
export class AnnouncementsController {
  constructor(private readonly announcementsService: AnnouncementsService) {}

  @Get()
  @ApiOperation({ summary: 'Get active announcements and carousel items' })
  async getActiveAnnouncements() {
    return this.announcementsService.getActiveAnnouncements();
  }

  @Post()
  @ApiOperation({ summary: 'Create a new announcement (Admin Portal & Preacher)' })
  async createAnnouncement(@CurrentUser() user: any, @Body() dto: CreateAnnouncementDto) {
    return this.announcementsService.createAnnouncement(user, dto);
  }
}
