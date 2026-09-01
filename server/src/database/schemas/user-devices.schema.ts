import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Schema as MongooseSchema } from 'mongoose';

export type UserDeviceDocument = UserDevice & Document;

@Schema({ timestamps: true, collection: 'userDevices' })
export class UserDevice {
  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: true, index: true })
  userId: MongooseSchema.Types.ObjectId;

  @Prop({ type: String, required: true, unique: true, index: true })
  fcmToken: string;

  @Prop({ type: String, enum: ['android', 'ios', 'web'], required: true })
  platform: string;

  @Prop({ type: String, required: true })
  appInstanceId: string; // Privacy-safe installation ID

  @Prop({ type: String, default: '1.0.0' })
  appVersion: string;

  @Prop({ type: Date, default: Date.now, index: true })
  lastSeenAt: Date;
}

export const UserDeviceSchema = SchemaFactory.createForClass(UserDevice);

// TTL Index: Automatically expire devices inactive for > 60 days (5,184,000 seconds)
UserDeviceSchema.index({ lastSeenAt: 1 }, { expireAfterSeconds: 5184000 });
