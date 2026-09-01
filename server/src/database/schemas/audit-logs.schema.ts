import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Schema as MongooseSchema } from 'mongoose';

export type AuditLogDocument = AuditLog & Document;

@Schema({ timestamps: true, collection: 'auditLogs' })
export class AuditLog {
  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: true, index: true })
  performedBy: MongooseSchema.Types.ObjectId;

  @Prop({ type: String, required: true, index: true }) // e.g., 'CREATE_PREACHER', 'CHANGE_ROLE', 'BLOCK_USER'
  action: string;

  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', default: null, index: true })
  targetUserId: MongooseSchema.Types.ObjectId;

  @Prop({ type: MongooseSchema.Types.Map, default: {} })
  metadata: Record<string, any>;

  @Prop({ type: String, default: null })
  ipAddress: string;
}

export const AuditLogSchema = SchemaFactory.createForClass(AuditLog);
AuditLogSchema.index({ createdAt: -1 });
