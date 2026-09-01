import {
  Controller,
  Post,
  Delete,
  Body,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { NotificationsService } from './notifications.service';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { SendNotificationDto } from './dto/send-notification.dto';
import { FirebaseAuthGuard } from '../common/guards/firebase-auth.guard';
import { ActiveUserGuard } from '../common/guards/active-user.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';

@ApiTags('FCM Push Notifications')
@Controller('notifications')
@UseGuards(FirebaseAuthGuard, ActiveUserGuard)
@ApiBearerAuth('access-token')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Post('device-token')
  @ApiOperation({ summary: 'Register or refresh FCM device token for current user' })
  async registerDeviceToken(
    @CurrentUser() user: any,
    @Body() dto: RegisterDeviceDto,
  ) {
    return this.notificationsService.registerDeviceToken(user._id, dto);
  }

  @Delete('device-token')
  @ApiOperation({ summary: 'Revoke FCM device token on logout' })
  async removeDeviceToken(
    @CurrentUser() user: any,
    @Body('fcmToken') fcmToken: string,
  ) {
    return this.notificationsService.removeDeviceToken(user._id, fcmToken);
  }

  @Post('send')
  @UseGuards(RolesGuard)
  @Roles('admin', 'preacher')
  @ApiOperation({ summary: 'Send targeted FCM push notification (Admin/Preacher only)' })
  async sendNotification(@Body() dto: SendNotificationDto) {
    return this.notificationsService.sendMulticastNotification(dto);
  }
}
