import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Schema as MongooseSchema } from 'mongoose';

export type TripDocument = Trip & Document;

@Schema({ timestamps: true, collection: 'trips' })
export class Trip {
  @Prop({ type: String, required: true, trim: true })
  title: string;

  @Prop({ type: String, default: '' })
  description: string;

  @Prop({ type: String, required: true }) // "YYYY-MM-DD"
  tripDate: string;

  @Prop({ type: String, default: '' })
  bannerUrl: string;

  @Prop({ type: String, default: '' })
  registrationLink: string;

  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: true })
  createdBy: MongooseSchema.Types.ObjectId;

  @Prop({ type: Boolean, default: true, index: true })
  isActive: boolean;
}

export const TripSchema = SchemaFactory.createForClass(Trip);
