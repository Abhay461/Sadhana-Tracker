import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Schema as MongooseSchema } from 'mongoose';

export type DailyQuoteDocument = DailyQuote & Document;

@Schema({ timestamps: true })
export class DailyQuote {
  @Prop({ required: true, index: true })
  date: string; // YYYY-MM-DD format

  @Prop({ required: false, default: '' })
  quote?: string;

  @Prop({ required: false, default: '' })
  author?: string;

  @Prop({ type: [String], required: false, default: [] })
  imageUrls?: string[];

  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: false, default: null })
  createdBy?: MongooseSchema.Types.ObjectId;

  @Prop({ default: true })
  isActive: boolean;
}

export const DailyQuoteSchema = SchemaFactory.createForClass(DailyQuote);
DailyQuoteSchema.index({ date: 1, isActive: 1 });
