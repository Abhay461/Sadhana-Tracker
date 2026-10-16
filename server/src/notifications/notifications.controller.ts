import {
  Controller,
  Post,
  Delete,
  Body,
  UseGuards,
  ForbiddenException,
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
    const userId = user?._id || user?.id || user?.uid || user?.firebaseUid;
    return this.notificationsService.registerDeviceToken(userId, dto);
  }

  @Delete('device-token')
  @ApiOperation({ summary: 'Revoke FCM device token on logout' })
  async removeDeviceToken(
    @CurrentUser() user: any,
    @Body('fcmToken') fcmToken: string,
  ) {
    const userId = user?._id || user?.id || user?.uid || user?.firebaseUid;
    return this.notificationsService.removeDeviceToken(userId, fcmToken);
  }

  @Post('send')
  @UseGuards(RolesGuard)
  @Roles('admin', 'preacher', 'folk_boy', 'residency', 'student', 'user', 'member')
  @ApiOperation({ summary: 'Send targeted FCM push notification' })
  async sendNotification(
    @CurrentUser() user: any,
    @Body() dto: SendNotificationDto,
  ) {
    if (user?.role !== 'admin' && user?.role !== 'preacher') {
      const allowedPreacherId = (user?.preacherId?._id || user?.preacherId)?.toString();
      if (!allowedPreacherId) {
        throw new ForbiddenException('You do not have an assigned preacher to notify');
      }
      const isOnlyPreacher =
        Array.isArray(dto.targetUserIds) &&
        dto.targetUserIds.length === 1 &&
        dto.targetUserIds[0] === allowedPreacherId;

      if (!isOnlyPreacher) {
        throw new ForbiddenException('Non-preacher users can only send notifications to their assigned preacher');
      }
    }
    return this.notificationsService.sendMulticastNotification(dto);
  }
}
