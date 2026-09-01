import {
  Controller,
  Get,
  Patch,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { PreachersService } from './preachers.service';
import { ApproveStudentDto } from './dto/approve-student.dto';
import { FirebaseAuthGuard } from '../common/guards/firebase-auth.guard';
import { ActiveUserGuard } from '../common/guards/active-user.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { OwnershipGuard } from '../common/guards/ownership.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';

@ApiTags('Preacher Dashboard')
@Controller('preacher')
@UseGuards(FirebaseAuthGuard, ActiveUserGuard, RolesGuard, OwnershipGuard)
@Roles('preacher', 'admin')
@ApiBearerAuth('access-token')
export class PreachersController {
  constructor(private readonly preachersService: PreachersService) {}

  @Get('students')
  @ApiOperation({ summary: 'Get assigned students directory and pending approvals count' })
  async getMyStudents(@CurrentUser() preacher: any) {
    return this.preachersService.getMyStudents(preacher._id);
  }

  @Patch('students/:id/approve')
  @ApiOperation({ summary: 'Approve or reject a pending student account' })
  async approveStudentAccount(
    @CurrentUser() preacher: any,
    @Param('id') studentId: string,
    @Body() dto: ApproveStudentDto,
  ) {
    return this.preachersService.approveStudentAccount(preacher._id, studentId, dto);
  }

  @Get('students/:id/progress')
  @ApiOperation({ summary: 'Get detailed sadhana progress & history for an assigned student' })
  async getStudentProgress(
    @CurrentUser() preacher: any,
    @Param('id') studentId: string,
  ) {
    return this.preachersService.getStudentProgress(preacher._id, studentId);
  }
}
