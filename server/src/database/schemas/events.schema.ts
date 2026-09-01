import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Schema as MongooseSchema } from 'mongoose';

export type EventDocument = Event & Document;

@Schema({ timestamps: true, collection: 'events' })
export class Event {
  @Prop({ type: String, required: true, trim: true })
  title: string;

  @Prop({ type: String, default: '' })
  description: string;

  @Prop({ type: String, required: true }) // "YYYY-MM-DD"
  eventDate: string;

  @Prop({ type: String, default: '' })
  eventTime: string;

  @Prop({ type: String, default: '' })
  bannerUrl: string;

  @Prop({ type: String, default: '' })
  registrationLink: string;

  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: true })
  createdBy: MongooseSchema.Types.ObjectId;

  @Prop({ type: Boolean, default: true, index: true })
  isActive: boolean;
}

export const EventSchema = SchemaFactory.createForClass(Event);
