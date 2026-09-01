import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Schema as MongooseSchema } from 'mongoose';

export type PaymentDocument = Payment & Document;

@Schema({ timestamps: true, collection: 'payments' })
export class Payment {
  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: true, index: true })
  userId: MongooseSchema.Types.ObjectId;

  @Prop({ type: MongooseSchema.Types.ObjectId, ref: 'User', required: true, index: true })
  preacherId: MongooseSchema.Types.ObjectId;

  @Prop({ type: String, required: true, trim: true })
  title: string;

  @Prop({ type: Number, required: true })
  amount: number;

  @Prop({
    type: String,
    enum: ['PENDING', 'SUBMITTED', 'APPROVED', 'REJECTED'],
    default: 'PENDING',
    index: true,
  })
  status: string;

  @Prop({ type: String, default: 'MANUAL' }) // 'MANUAL', 'RAZORPAY', 'STRIPE', 'UPI'
  paymentProvider: string;

  @Prop({ type: String, sparse: true, default: null }) // Provider Payment / Order ID
  transactionReferenceId: string;

  @Prop({ type: String, default: '' })
  proofUrl: string;

  @Prop({ type: String, default: '' })
  remarks: string;

  @Prop({ type: MongooseSchema.Types.Map, default: null })
  webhookPayload: Record<string, any>;
}

export const PaymentSchema = SchemaFactory.createForClass(Payment);
PaymentSchema.index({ preacherId: 1, status: 1 });
PaymentSchema.index({ transactionReferenceId: 1 }, { sparse: true });
