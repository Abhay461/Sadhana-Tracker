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

  async removeDeviceToken(userId: string, fcmToken?: string) {
    if (!fcmToken || typeof fcmToken !== 'string' || fcmToken.trim().length === 0) {
      return { success: false, message: 'Invalid token' };
    }
    await this.userDeviceModel.deleteOne({ fcmToken: fcmToken.trim() });
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

    const matchedUsersQuery: any[] = [];
    if (targetOids.size > 0) {
      matchedUsersQuery.push({ _id: { $in: Array.from(targetOids).map((id) => new Types.ObjectId(id)) } });
    }
    if (rawIds.length > 0) {
      matchedUsersQuery.push({ firebaseUid: { $in: rawIds } });
    }

    if (matchedUsersQuery.length > 0) {
      const matchedUsers = await this.userModel
        .find({ $or: matchedUsersQuery })
        .select('_id')
        .lean();
      matchedUsers.forEach((u) => targetOids.add(u._id.toString()));
    }

    const targetObjectIds = Array.from(targetOids).map((id) => new Types.ObjectId(id));
    const targetStringIds = Array.from(targetOids);

    const devices = await this.userDeviceModel
      .find({
        $or: [
          { userId: { $in: targetObjectIds } },
          { userId: { $in: targetStringIds } },
          { userId: { $in: rawIds } },
        ],
      })
      .sort({ lastSeenAt: -1, createdAt: -1 });

    this.logger.log(`Found ${devices.length} registered FCM devices for targets: ${rawIds.join(', ')}`);

    if (devices.length === 0) {
      this.logger.warn(`No registered FCM devices found for users: ${rawIds.join(', ')}`);
      return { successCount: 0, failureCount: 0 };
    }

    // Deduplicate tokens: keep only newest token per user/instance to prevent duplicate delivery to same device
    const seenInstances = new Set<string>();
    const tokens: string[] = [];
    for (const d of devices) {
      if (!d.fcmToken) continue;
      const key = `${d.userId?.toString()}_${d.appInstanceId || d.platform || 'default'}`;
      if (seenInstances.has(key)) continue;
      seenInstances.add(key);
      tokens.push(d.fcmToken);
    }

    if (tokens.length === 0) {
      return { successCount: 0, failureCount: 0 };
    }

    const eventTag = dto.dataPayload?.appointmentId
      ? `appointment_${dto.dataPayload.appointmentId}`
      : (dto.dataPayload?.accommodationId
          ? `accommodation_${dto.dataPayload.accommodationId}`
          : (dto.dataPayload?.id ? `entity_${dto.dataPayload.id}` : undefined));

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

    const BATCH_SIZE = 500;
    let totalSuccess = 0;
    let totalFailure = 0;
    const tokensToRemove: string[] = [];
    const messaging = this.firebaseService.getMessaging();

    for (let i = 0; i < tokens.length; i += BATCH_SIZE) {
      const chunk = tokens.slice(i, i + BATCH_SIZE);
      const message: any = {
        tokens: chunk,
        notification: {
          title: dto.title,
          body: dto.body,
        },
        data: sanitizedData,
        android: {
          priority: 'high',
          notification: {
            channelId: 'sadhana_tracker_notifications',
            icon: 'launcher_icon',
            color: '#3F51B5',
            sound: 'default',
            priority: 'high',
            defaultSound: true,
            defaultVibrateTimings: true,
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            ...(eventTag ? { tag: eventTag } : {}),
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
        let response: any;
        if (typeof (messaging as any).sendEachForMulticast === 'function') {
          response = await (messaging as any).sendEachForMulticast(message);
        } else if (typeof (messaging as any).sendMulticast === 'function') {
          response = await (messaging as any).sendMulticast(message);
        } else {
          response = { successCount: 0, failureCount: 0, responses: [] };
          for (const token of chunk) {
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

        totalSuccess += response.successCount || 0;
        totalFailure += response.failureCount || 0;

        // Clean up invalid/unregistered tokens
        if (response.failureCount > 0 && response.responses) {
          response.responses.forEach((resp: any, idx: number) => {
            if (!resp.success && resp.error) {
              const code = resp.error.code;
              this.logger.warn(`Device ${i + idx} error: ${resp.error.message} (${code})`);
              if (
                code === 'messaging/registration-token-not-registered' ||
                code === 'messaging/invalid-registration-token'
              ) {
                tokensToRemove.push(chunk[idx]);
              }
            }
          });
        }
      } catch (chunkError: any) {
        this.logger.error(`FCM chunk multicast exception: ${chunkError.message}`);
        totalFailure += chunk.length;
      }
    }

    if (tokensToRemove.length > 0) {
      await this.userDeviceModel.deleteMany({ fcmToken: { $in: tokensToRemove } });
      this.logger.log(`Purged ${tokensToRemove.length} stale/invalid FCM tokens from database.`);
    }

    this.logger.log(
      `FCM Multicast sent to ${tokens.length} devices in total: ${totalSuccess} succeeded, ${totalFailure} failed.`,
    );

    return {
      successCount: totalSuccess,
      failureCount: totalFailure,
    };
  }
}
