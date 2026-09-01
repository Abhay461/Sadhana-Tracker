import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Schema as MongooseSchema } from 'mongoose';

export type ScreenTimeLogDocument = ScreenTimeLog & Document;

@Schema({ timestamps: true, collection: 'screenTimeLogs' })
export class ScreenTimeLog {
  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: true, index: true })
  userId: MongooseSchema.Types.ObjectId;

  @Prop({ type: String, required: true }) // "YYYY-MM-DD"
  date: string;

  @Prop({ type: String, required: true }) // e.g. "2h 45m"
  totalDurationLabel: string;

  @Prop({ type: String, default: '' })
  breakdownDescription: string;
}

export const ScreenTimeLogSchema = SchemaFactory.createForClass(ScreenTimeLog);

// Compound unique index to prevent duplicate logs per day
ScreenTimeLogSchema.index({ userId: 1, date: 1 }, { unique: true });
