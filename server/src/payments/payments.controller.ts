import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { PaymentsService } from './payments.service';
import { SubmitPaymentDto } from './dto/submit-payment.dto';
import { ApprovePaymentDto } from './dto/approve-payment.dto';
import { FirebaseAuthGuard } from '../common/guards/firebase-auth.guard';
import { ActiveUserGuard } from '../common/guards/active-user.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { OwnershipGuard } from '../common/guards/ownership.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';

@ApiTags('Payments & Contributions')
@Controller('payments')
@UseGuards(FirebaseAuthGuard, ActiveUserGuard, RolesGuard, OwnershipGuard)
@ApiBearerAuth('access-token')
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Post()
  @Roles('folk_boy', 'residency')
  @ApiOperation({ summary: 'Submit payment status/proof' })
  async submitPayment(@CurrentUser() user: any, @Body() dto: SubmitPaymentDto) {
    return this.paymentsService.submitPayment(user, dto);
  }

  @Get('my')
  @Roles('folk_boy', 'residency')
  @ApiOperation({ summary: 'Get current student payment records' })
  async getMyPayments(@CurrentUser() user: any) {
    return this.paymentsService.getMyPayments(user._id);
  }

  @Get('queue')
  @Roles('preacher', 'admin')
  @ApiOperation({ summary: 'Get preacher payment verification queue' })
  async getPreacherQueue(@CurrentUser() preacher: any) {
    return this.paymentsService.getPreacherQueue(preacher._id);
  }

  @Patch(':id/verify')
  @Roles('preacher', 'admin')
  @ApiOperation({ summary: 'Approve or reject payment submission' })
  async verifyPayment(
    @CurrentUser() preacher: any,
    @Param('id') id: string,
    @Body() dto: ApprovePaymentDto,
  ) {
    return this.paymentsService.verifyPayment(preacher._id, id, dto);
  }
}
