import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Schema as MongooseSchema } from 'mongoose';

export type EventRegistrationDocument = EventRegistration & Document;

@Schema({ timestamps: true, collection: 'eventRegistrations' })
export class EventRegistration {
  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'Event', required: true, index: true })
  eventId: MongooseSchema.Types.ObjectId;

  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: true, index: true })
  userId: MongooseSchema.Types.ObjectId;

  @Prop({ type: String, required: true })
  registeredName: string; // Immutable registration snapshot

  @Prop({ type: String, required: true })
  contactNumber: string; // Immutable registration snapshot

  @Prop({ type: String, enum: ['REGISTERED', 'CANCELLED', 'ATTENDED'], default: 'REGISTERED' })
  registrationStatus: string;

  @Prop({ type: Date, default: Date.now })
  registeredAt: Date;
}

export const EventRegistrationSchema = SchemaFactory.createForClass(EventRegistration);

// Compound unique index to prevent duplicate registrations
EventRegistrationSchema.index({ eventId: 1, userId: 1 }, { unique: true });
