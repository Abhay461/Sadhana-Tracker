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
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class PaymentsService {
  constructor(
    @InjectModel(Payment.name) private readonly paymentModel: Model<PaymentDocument>,
    private readonly realtimeService: RealtimeService,
    private readonly notificationsService?: NotificationsService,
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

  async getPreacherQueue(preacher: any) {
    const preacherId = (preacher?._id ?? preacher?.id ?? preacher).toString();
    const canViewAll = Boolean(
      preacher?.canViewAllStudents || preacher?.isHeadPreacher || preacher?.role === 'admin'
    );
    const filter = canViewAll ? {} : { preacherId };

    return this.paymentModel
      .find(filter)
      .populate('userId', 'name email phoneNumber photoUrl')
      .sort({ createdAt: -1 });
  }

  async verifyPayment(preacher: any, id: string, dto: ApprovePaymentDto) {
    const payment = await this.paymentModel.findById(id);

    if (!payment) {
      throw new NotFoundException('Payment record not found.');
    }

    const preacherId = (preacher?._id ?? preacher?.id ?? preacher).toString();
    const canViewAll = Boolean(
      preacher?.canViewAllStudents || preacher?.isHeadPreacher || preacher?.role === 'admin'
    );

    if (!canViewAll && payment.preacherId?.toString() !== preacherId) {
      throw new ForbiddenException('Access denied: Payment record is not in your preacher verification queue.');
    }

    payment.status = dto.status;
    if (dto.remarks) {
      payment.remarks = dto.remarks;
    }
    await payment.save();

    this.realtimeService?.emit('payment_update', 'update', payment, {
      preacherId: payment.preacherId?.toString() || preacherId,
      studentId: payment.userId?.toString(),
    });

    if (this.notificationsService && payment.userId) {
      const payTitle = dto.status === 'APPROVED' ? 'Payment Approved' : 'Payment Rejected';
      const payBody = dto.status === 'APPROVED'
        ? `Your payment submission for "${payment.title || 'course/service'}" has been approved.`
        : `Your payment submission for "${payment.title || 'course/service'}" was rejected.`;

      this.notificationsService
        .sendMulticastNotification({
          targetUserIds: [payment.userId.toString()],
          title: payTitle,
          body: payBody,
          dataPayload: {
            category: 'payment',
            paymentId: payment._id.toString(),
            status: dto.status,
          },
        })
        .catch((err) => console.error('Failed to send payment approval notification to student:', err));
    }

    return payment;
  }
}
