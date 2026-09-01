import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Schema as MongooseSchema } from 'mongoose';

export type UserDocument = User & Document;

@Schema({ timestamps: true, collection: 'users' })
export class User {
  @Prop({ type: String, sparse: true, unique: true, index: true, default: null })
  firebaseUid: string;

  @Prop({ type: String, required: true, unique: true, index: true, trim: true })
  phoneNumber: string; // Normalized E.164 (+91XXXXXXXXXX)

  @Prop({ type: String, lowercase: true, trim: true, sparse: true, index: true, default: null })
  email: string;

  @Prop({ type: String, required: true, trim: true })
  name: string;

  @Prop({
    type: String,
    enum: ['admin', 'preacher', 'folk_boy', 'residency'],
    default: 'folk_boy',
    index: true,
  })
  role: string;

  @Prop({
    type: String,
    enum: ['ACTIVE', 'PENDING_APPROVAL', 'BLOCKED', 'DEACTIVATED'],
    default: 'ACTIVE',
    index: true,
  })
  status: string;

  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', index: true, default: null })
  preacherId: MongooseSchema.Types.ObjectId;

  @Prop({ type: String, uppercase: true, trim: true, sparse: true, index: true, default: null })
  preacherCode: string;

  @Prop({ type: String, default: null })
  photoUrl: string;

  @Prop({ type: Date, default: null })
  dob: Date;

  @Prop({ type: Date, default: null })
  joiningDate: Date;

  @Prop({ type: Boolean, default: false, index: true })
  isBlocked: boolean;

  @Prop({
    type: String,
    enum: ['NONE', 'PENDING_LINK', 'COMPLETED'],
    default: 'NONE',
  })
  migrationStatus: string;

  @Prop({ type: String, sparse: true, index: true, default: null })
  legacySupabaseUserId: string;
}

export const UserSchema = SchemaFactory.createForClass(User);

// Compound index for preacher student list queries
UserSchema.index({ preacherId: 1, role: 1, status: 1 });
