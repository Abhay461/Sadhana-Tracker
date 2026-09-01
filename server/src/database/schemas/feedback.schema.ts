import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Schema as MongooseSchema } from 'mongoose';

export type FeedbackDocument = Feedback & Document;

@Schema({ timestamps: true, collection: 'feedback' })
export class Feedback {
  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: true, index: true })
  userId: MongooseSchema.Types.ObjectId;

  @Prop({ type: String, default: 'General' })
  category: string;

  @Prop({ type: String, required: true })
  message: string;

  @Prop({ type: Number, default: 5 })
  rating: number;
}

export const FeedbackSchema = SchemaFactory.createForClass(Feedback);
