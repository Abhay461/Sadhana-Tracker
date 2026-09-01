import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Schema as MongooseSchema } from 'mongoose';

export type AccommodationDocument = Accommodation & Document;

@Schema({ timestamps: true, collection: 'accommodations' })
export class Accommodation {
  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: true, index: true })
  userId: MongooseSchema.Types.ObjectId;

  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: true, index: true })
  preacherId: MongooseSchema.Types.ObjectId;

  @Prop({ type: String, required: true })
  requestDetails: string;

  @Prop({
    type: String,
    enum: ['PENDING', 'APPROVED', 'REJECTED'],
    default: 'PENDING',
    index: true,
  })
  status: string;

  @Prop({ type: String, default: '' })
  assignedRoom: string;
}

export const AccommodationSchema = SchemaFactory.createForClass(Accommodation);
AccommodationSchema.index({ preacherId: 1, status: 1 });
