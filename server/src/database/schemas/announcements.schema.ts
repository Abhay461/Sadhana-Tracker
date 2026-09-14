import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Schema as MongooseSchema } from 'mongoose';

export type AnnouncementDocument = Announcement & Document;

@Schema({ timestamps: true, collection: 'announcements', strict: false })
export class Announcement {
  @Prop({ type: String, required: false, default: '', trim: true })
  title: string;

  @Prop({ type: String, default: '' })
  content: string;

  @Prop({ type: String, default: '' })
  category: string;

  @Prop({ type: String, default: '' })
  description: string;

  @Prop({ type: String, default: 'announcement' })
  type: string;

  @Prop({ type: String, default: '' })
  bannerUrl: string;

  @Prop({ type: String, default: '' })
  externalLink: string;

  @Prop({ type: String, default: '' })
  sessionTime: string;

  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: false })
  createdBy: MongooseSchema.Types.ObjectId;

  @Prop({ type: Boolean, default: true, index: true })
  isActive: boolean;
}

export const AnnouncementSchema = SchemaFactory.createForClass(Announcement);
