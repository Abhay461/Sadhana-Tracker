import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Schema as MongooseSchema } from 'mongoose';

export type TripRegistrationDocument = TripRegistration & Document;

@Schema({ timestamps: true, collection: 'tripRegistrations' })
export class TripRegistration {
  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'Trip', required: true, index: true })
  tripId: MongooseSchema.Types.ObjectId;

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

export const TripRegistrationSchema = SchemaFactory.createForClass(TripRegistration);

// Compound unique index to prevent duplicate registrations
TripRegistrationSchema.index({ tripId: 1, userId: 1 }, { unique: true });
