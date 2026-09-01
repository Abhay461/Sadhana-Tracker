import { Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { UserDevice, UserDeviceDocument } from '../database/schemas/user-devices.schema';
import { FirebaseService } from '../firebase/firebase.service';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { SendNotificationDto } from './dto/send-notification.dto';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    @InjectModel(UserDevice.name) private readonly userDeviceModel: Model<UserDeviceDocument>,
    private readonly firebaseService: FirebaseService,
  ) {}

  async registerDeviceToken(userId: string, dto: RegisterDeviceDto) {
    const device = await this.userDeviceModel.findOneAndUpdate(
      { fcmToken: dto.fcmToken },
      {
        $set: {
          userId,
          platform: dto.platform,
          appInstanceId: dto.appInstanceId,
          appVersion: dto.appVersion,
          lastSeenAt: new Date(),
        },
      },
      { upsert: true, new: true },
    );
    this.logger.log(`Registered FCM token for user ${userId} (${dto.platform})`);
    return device;
  }

  async removeDeviceToken(userId: string, fcmToken: string) {
    await this.userDeviceModel.deleteOne({ userId, fcmToken });
    this.logger.log(`Revoked FCM token for user ${userId}`);
    return { success: true };
  }

  async sendMulticastNotification(dto: SendNotificationDto) {
    if (!dto.targetUserIds || dto.targetUserIds.length === 0) {
      return { successCount: 0, failureCount: 0 };
    }

    const devices = await this.userDeviceModel.find({
      userId: { $in: dto.targetUserIds },
    });

    if (devices.length === 0) {
      this.logger.warn(`No registered FCM devices found for users: ${dto.targetUserIds.join(', ')}`);
      return { successCount: 0, failureCount: 0 };
    }

    const tokens = devices.map((d) => d.fcmToken);

    try {
      const response = await this.firebaseService.getMessaging().sendMulticast({
        tokens,
        notification: {
          title: dto.title,
          body: dto.body,
        },
        data: dto.dataPayload || {},
      });

      this.logger.log(`FCM Multicast sent: ${response.successCount} succeeded, ${response.failureCount} failed.`);

      // Clean up invalid/unregistered tokens
      if (response.failureCount > 0) {
        const tokensToRemove: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success && resp.error) {
            const code = resp.error.code;
            if (
              code === 'messaging/registration-token-not-registered' ||
              code === 'messaging/invalid-registration-token'
            ) {
              tokensToRemove.push(tokens[idx]);
            }
          }
        });

        if (tokensToRemove.length > 0) {
          await this.userDeviceModel.deleteMany({ fcmToken: { $in: tokensToRemove } });
          this.logger.log(`Purged ${tokensToRemove.length} stale/invalid FCM tokens from database.`);
        }
      }

      return {
        successCount: response.successCount,
        failureCount: response.failureCount,
      };
    } catch (e) {
      this.logger.error(`FCM Multicast send exception: ${e.message}`);
      return { successCount: 0, failureCount: tokens.length, error: e.message };
    }
  }
}
