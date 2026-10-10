import { Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { UserDevice, UserDeviceDocument } from '../database/schemas/user-devices.schema';
import { User, UserDocument } from '../database/schemas/users.schema';
import { FirebaseService } from '../firebase/firebase.service';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { SendNotificationDto } from './dto/send-notification.dto';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    @InjectModel(UserDevice.name) private readonly userDeviceModel: Model<UserDeviceDocument>,
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
    private readonly firebaseService: FirebaseService,
  ) {}

  async registerDeviceToken(userIdentifier: any, dto: RegisterDeviceDto) {
    let mongoUserId: any = null;

    if (userIdentifier) {
      const idStr = userIdentifier.toString();
      if (Types.ObjectId.isValid(idStr)) {
        mongoUserId = new Types.ObjectId(idStr);
      } else {
        const foundUser = await this.userModel.findOne({ firebaseUid: idStr }).select('_id').lean();
        if (foundUser) {
          mongoUserId = foundUser._id;
        } else {
          mongoUserId = idStr;
        }
      }
    }

    const device = await this.userDeviceModel.findOneAndUpdate(
      { fcmToken: dto.fcmToken },
      {
        $set: {
          userId: mongoUserId || userIdentifier,
          platform: dto.platform,
          appInstanceId: dto.appInstanceId,
          appVersion: dto.appVersion,
          lastSeenAt: new Date(),
        },
      },
      { upsert: true, new: true },
    );
    this.logger.log(`Registered FCM token for user ${userIdentifier} (resolved: ${mongoUserId}) (${dto.platform})`);
    return device;
  }

  async removeDeviceToken(userId: string, fcmToken: string) {
    await this.userDeviceModel.deleteOne({ fcmToken });
    this.logger.log(`Revoked FCM token for user ${userId}`);
    return { success: true };
  }

  async sendMulticastNotification(dto: SendNotificationDto) {
    if (!dto.targetUserIds || dto.targetUserIds.length === 0) {
      return { successCount: 0, failureCount: 0 };
    }

    const rawIds = dto.targetUserIds.filter(Boolean).map((id) => id.toString().trim());
    if (rawIds.length === 0) {
      return { successCount: 0, failureCount: 0 };
    }

    const targetOids = new Set<string>();

    for (const rawId of rawIds) {
      if (Types.ObjectId.isValid(rawId)) {
        targetOids.add(rawId);
      }
    }

    const matchedUsers = await this.userModel
      .find({
        $or: [
          { _id: { $in: Array.from(targetOids).map((id) => new Types.ObjectId(id)) } },
          { firebaseUid: { $in: rawIds } },
        ],
      })
      .select('_id')
      .lean();

    matchedUsers.forEach((u) => targetOids.add(u._id.toString()));

    const targetObjectIds = Array.from(targetOids).map((id) => new Types.ObjectId(id));
    const targetStringIds = Array.from(targetOids);

    const devices = await this.userDeviceModel.find({
      $or: [
        { userId: { $in: targetObjectIds } },
        { userId: { $in: targetStringIds } },
        { userId: { $in: rawIds } },
      ],
    });

    this.logger.log(`Found ${devices.length} registered FCM devices for targets: ${rawIds.join(', ')}`);

    if (devices.length === 0) {
      this.logger.warn(`No registered FCM devices found for users: ${rawIds.join(', ')}`);
      return { successCount: 0, failureCount: 0 };
    }

    const tokens = Array.from(new Set(devices.map((d) => d.fcmToken).filter(Boolean)));
    if (tokens.length === 0) {
      return { successCount: 0, failureCount: 0 };
    }

    const sanitizedData: Record<string, string> = {};
    if (dto.dataPayload) {
      for (const [k, v] of Object.entries(dto.dataPayload)) {
        if (v !== undefined && v !== null) {
          sanitizedData[k] = String(v);
        }
      }
    }
    sanitizedData['title'] = dto.title;
    sanitizedData['body'] = dto.body;

    const message: any = {
      tokens,
      notification: {
        title: dto.title,
        body: dto.body,
      },
      data: sanitizedData,
      android: {
        priority: 'high',
        notification: {
          channelId: 'sadhana_tracker_notifications',
          sound: 'default',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    try {
      const messaging = this.firebaseService.getMessaging();
      let response: any;

      if (typeof (messaging as any).sendEachForMulticast === 'function') {
        response = await (messaging as any).sendEachForMulticast(message);
      } else if (typeof (messaging as any).sendMulticast === 'function') {
        response = await (messaging as any).sendMulticast(message);
      } else {
        response = { successCount: 0, failureCount: 0, responses: [] };
        for (const token of tokens) {
          try {
            await messaging.send({
              token,
              notification: { title: dto.title, body: dto.body },
              data: sanitizedData,
            });
            response.successCount++;
            response.responses.push({ success: true });
          } catch (err: any) {
            response.failureCount++;
            response.responses.push({ success: false, error: err });
          }
        }
      }

      this.logger.log(
        `FCM Multicast sent to ${tokens.length} devices: ${response.successCount} succeeded, ${response.failureCount} failed.`,
      );

      // Clean up invalid/unregistered tokens
      if (response.failureCount > 0 && response.responses) {
        const tokensToRemove: string[] = [];
        response.responses.forEach((resp: any, idx: number) => {
          if (!resp.success && resp.error) {
            const code = resp.error.code;
            this.logger.warn(`Device ${idx} error: ${resp.error.message} (${code})`);
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
