import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type MigrationRunDocument = MigrationRun & Document;

@Schema({ timestamps: true, collection: 'migrationRuns' })
export class MigrationRun {
  @Prop({ type: String, required: true, index: true })
  runId: string;

  @Prop({ type: String, required: true }) // e.g. 'PROFILES', 'SADHANA', 'PAYMENTS', 'ACCOMMODATIONS'
  step: string;

  @Prop({ type: Number, default: 0 })
  processedCount: number;

  @Prop({ type: String, default: null })
  lastLegacyId: string;

  @Prop({ type: String, enum: ['IN_PROGRESS', 'COMPLETED', 'FAILED'], default: 'IN_PROGRESS' })
  status: string;

  @Prop({ type: [String], default: [] })
  errorLogs: string[];
}

export const MigrationRunSchema = SchemaFactory.createForClass(MigrationRun);
MigrationRunSchema.index({ runId: 1, step: 1 }, { unique: true });
