import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Schema as MongooseSchema } from 'mongoose';

export type FestivalDocument = Festival & Document;

@Schema({ timestamps: true, collection: 'festivals', strict: false })
export class Festival {
  @Prop({ type: String, required: true, trim: true })
  title: string;

  @Prop({ type: String, default: '' })
  description: string;

  @Prop({ type: String, default: '' })
  imageUrl: string;

  @Prop({ type: String, required: true, index: true })
  dateString: string; // YYYY-MM-DD

  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: false })
  createdBy: MongooseSchema.Types.ObjectId;

  @Prop({ type: Boolean, default: true, index: true })
  isActive: boolean;
}

export const FestivalSchema = SchemaFactory.createForClass(Festival);
