import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Schema as MongooseSchema } from 'mongoose';

export type SadhanaEntryDocument = SadhanaEntry & Document;

@Schema({ _id: false })
export class Activities {
  @Prop({ type: String, default: null })
  wakeUpTime: string;

  @Prop({ type: String, default: null })
  sleepTime: string;

  @Prop({
    type: {
      attended: { type: Boolean, default: false },
      time: { type: String, default: null },
    },
    default: { attended: false, time: null },
  })
  manglaArti: { attended: boolean; time?: string };

  @Prop({
    type: {
      rounds: { type: Number, default: 0 },
    },
    default: { rounds: 0 },
  })
  chanting: { rounds: number };

  @Prop({
    type: {
      attended: { type: Boolean, default: false },
      timeSpan: { type: String, default: null },
    },
    default: { attended: false, timeSpan: null },
  })
  onlineSession: { attended: boolean; timeSpan?: string };

  @Prop({
    type: {
      bookName: { type: String, default: null },
      pagesOrMinutes: { type: String, default: null },
    },
    default: { bookName: null, pagesOrMinutes: null },
  })
  bookReading: { bookName?: string; pagesOrMinutes?: string };

  @Prop({
    type: {
      serviceName: { type: String, default: null },
      durationMinutes: { type: Number, default: 0 },
    },
    default: { serviceName: null, durationMinutes: 0 },
  })
  service: { serviceName?: string; durationMinutes?: number };

  @Prop({
    type: {
      visited: { type: Boolean, default: false },
    },
    default: { visited: false },
  })
  templeVisit: { visited: boolean };

  @Prop({
    type: {
      attended: { type: Boolean, default: false },
    },
    default: { attended: false },
  })
  srimadBhagavatamClass: { attended: boolean };

  @Prop({
    type: {
      attended: { type: Boolean, default: false },
    },
    default: { attended: false },
  })
  bhagavadGitaClass: { attended: boolean };

  @Prop({
    type: {
      fastingType: { type: String, default: null },
      notes: { type: String, default: null },
    },
    default: { fastingType: null, notes: null },
  })
  ekadashiFasting: { fastingType?: string; notes?: string };
}

export const ActivitiesSchema = SchemaFactory.createForClass(Activities);

@Schema({ timestamps: true, collection: 'sadhanaEntries' })
export class SadhanaEntry {
  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: true, index: true })
  userId: MongooseSchema.Types.ObjectId;

  @Prop({ type: String, required: true }) // "YYYY-MM-DD"
  dateString: string;

  @Prop({ type: Date, required: true }) // UTC midnight of local day
  logicalDate: Date;

  @Prop({ type: Number, default: 330 }) // e.g. +330 for IST
  timezoneOffsetMinutes: number;

  @Prop({ type: ActivitiesSchema, default: () => ({}) })
  activities: Activities;

  @Prop({ type: Number, default: 0 })
  totalPoints: number;

  @Prop({ type: Boolean, default: false })
  isLocked: boolean;

  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', default: null })
  unlockedBy: MongooseSchema.Types.ObjectId;
}

export const SadhanaEntrySchema = SchemaFactory.createForClass(SadhanaEntry);

// Compound unique index to prevent duplicate logs per user per date
SadhanaEntrySchema.index({ userId: 1, dateString: 1 }, { unique: true });
SadhanaEntrySchema.index({ userId: 1, logicalDate: -1 });
