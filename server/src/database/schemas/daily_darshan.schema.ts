import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Schema as MongooseSchema } from 'mongoose';

export type DailyDarshanDocument = DailyDarshan & Document;

@Schema({ timestamps: true })
export class DailyDarshan {
  @Prop({ required: true, index: true })
  date: string; // YYYY-MM-DD format

  @Prop({ required: true })
  title: string;

  @Prop({ type: [String], required: true })
  imageUrls: string[];

  @Prop({ required: false })
  description?: string;

  // Optional while the admin portal supports publishing without a login.
  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: false, default: null })
  createdBy: MongooseSchema.Types.ObjectId;

  @Prop({ default: true })
  isActive: boolean;
}

export const DailyDarshanSchema = SchemaFactory.createForClass(DailyDarshan);
DailyDarshanSchema.index({ date: 1, isActive: 1 });
