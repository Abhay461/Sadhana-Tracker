import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { MediaService } from './media.service';
import { FirebaseAuthGuard } from '../common/guards/firebase-auth.guard';
import { ActiveUserGuard } from '../common/guards/active-user.guard';

@ApiTags('Media & Storage')
@Controller('media')
@UseGuards(FirebaseAuthGuard, ActiveUserGuard)
@ApiBearerAuth('access-token')
export class MediaController {
  constructor(private readonly mediaService: MediaService) {}

  @Get('upload-signature')
  @ApiOperation({ summary: 'Generate Cloudinary short-lived upload signature (Server secret protected)' })
  getUploadSignature(@Query('folder') folder?: string) {
    return this.mediaService.generateUploadSignature(folder || 'sadhana_app');
  }
}
