import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Schema as MongooseSchema } from 'mongoose';

export type AppointmentDocument = Appointment & Document;

@Schema({ timestamps: true, collection: 'appointments' })
export class Appointment {
  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: true, index: true })
  userId: MongooseSchema.Types.ObjectId;

  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: true, index: true })
  preacherId: MongooseSchema.Types.ObjectId;

  @Prop({ type: String, required: true })
  preferredDate: string;

  @Prop({ type: String, required: true })
  preferredTime: string;

  @Prop({ type: String, required: true })
  reason: string;

  @Prop({
    type: String,
    enum: ['PENDING', 'APPROVED', 'REJECTED'],
    default: 'PENDING',
    index: true,
  })
  status: string;
}

export const AppointmentSchema = SchemaFactory.createForClass(Appointment);
AppointmentSchema.index({ preacherId: 1, status: 1 });
