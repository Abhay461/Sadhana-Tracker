import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Payment, PaymentDocument } from '../database/schemas/payments.schema';
import { SubmitPaymentDto } from './dto/submit-payment.dto';
import { ApprovePaymentDto } from './dto/approve-payment.dto';
import { RealtimeService } from '../realtime/realtime.service';

@Injectable()
export class PaymentsService {
  constructor(
    @InjectModel(Payment.name) private readonly paymentModel: Model<PaymentDocument>,
    private readonly realtimeService: RealtimeService,
  ) {}

  async submitPayment(user: any, dto: SubmitPaymentDto) {
    if (!user.preacherId) {
      throw new BadRequestException('You do not have an assigned preacher to submit payment verification.');
    }

    const payment = await this.paymentModel.create({
      userId: user._id,
      preacherId: user.preacherId,
      title: dto.title,
      amount: dto.amount,
      proofUrl: dto.proofUrl || '',
      remarks: dto.remarks || '',
      status: 'SUBMITTED',
    });

    this.realtimeService.emit('payment_update', 'create', payment, {
      preacherId: user.preacherId?.toString(),
      studentId: user._id?.toString(),
    });

    return payment;
  }

  async getMyPayments(userId: string) {
    return this.paymentModel.find({ userId }).sort({ createdAt: -1 });
  }

  async getPreacherQueue(preacherId: string) {
    return this.paymentModel
      .find({ preacherId })
      .populate('userId', 'name email phoneNumber photoUrl')
      .sort({ createdAt: -1 });
  }

  async verifyPayment(preacherId: string, id: string, dto: ApprovePaymentDto) {
    const payment = await this.paymentModel.findById(id);

    if (!payment) {
      throw new NotFoundException('Payment record not found.');
    }

    if (payment.preacherId.toString() !== preacherId.toString()) {
      throw new ForbiddenException('Access denied: Payment record is not in your preacher verification queue.');
    }

    payment.status = dto.status;
    if (dto.remarks) {
      payment.remarks = dto.remarks;
    }
    await payment.save();

    this.realtimeService.emit('payment_update', 'update', payment, {
      preacherId: preacherId.toString(),
      studentId: payment.userId?.toString(),
    });

    return payment;
  }
}
