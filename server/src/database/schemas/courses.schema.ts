import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type CourseDocument = Course & Document;

@Schema({ timestamps: true })
export class CourseVideo {
  @Prop({ required: true })
  title: string;

  @Prop()
  description?: string;

  @Prop({ required: true })
  videoUrl: string;

  @Prop()
  thumbnailUrl?: string;

  @Prop()
  duration?: string;

  @Prop({ default: false })
  isPreview: boolean;

  @Prop({ default: 0 })
  orderIndex: number;
}

const CourseVideoSchema = SchemaFactory.createForClass(CourseVideo);

@Schema({ timestamps: true })
export class Course {
  @Prop({ required: true, trim: true })
  title: string;

  @Prop({ trim: true })
  subtitle?: string;

  @Prop()
  description?: string;

  @Prop({ default: 'Vedic Wisdom' })
  category: string;

  @Prop({ required: true })
  price: string;

  @Prop()
  originalPrice?: string;

  @Prop({ required: true, default: 0 })
  priceVal: number;

  @Prop({ default: 'Self-Paced' })
  duration: string;

  @Prop()
  bannerImage?: string;

  @Prop({ default: 'psychology_rounded' })
  iconName: string;

  @Prop({ default: '#4F46E5' })
  colorHex: string;

  @Prop({ default: '#EEF2FF' })
  bgHex: string;

  @Prop({ default: true })
  isActive: boolean;

  @Prop({ type: [CourseVideoSchema], default: [] })
  videos: CourseVideo[];
}

export const CourseSchema = SchemaFactory.createForClass(Course);
