import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Query,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { SadhanaService } from './sadhana.service';
import { LogSadhanaDto } from './dto/log-sadhana.dto';
import { LockDayDto } from './dto/lock-day.dto';
import { FirebaseAuthGuard } from '../common/guards/firebase-auth.guard';
import { ActiveUserGuard } from '../common/guards/active-user.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { OwnershipGuard } from '../common/guards/ownership.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';

@ApiTags('Sadhana Tracking')
@Controller('sadhana')
@UseGuards(FirebaseAuthGuard, ActiveUserGuard, RolesGuard, OwnershipGuard)
@ApiBearerAuth('access-token')
export class SadhanaController {
  constructor(private readonly sadhanaService: SadhanaService) {}

  @Post()
  @Roles('folk_boy', 'residency', 'student', 'user', 'member')
  @ApiOperation({ summary: 'Log or update daily sadhana entry' })
  async logSadhana(@CurrentUser() user: any, @Body() dto: LogSadhanaDto) {
    return this.sadhanaService.logSadhana(user._id, dto);
  }

  @Post('student-update')
  @ApiOperation({ summary: 'Save student sadhana update log' })
  async handleStudentUpdate(@CurrentUser() user: any, @Body() body: any) {
    return this.sadhanaService.handleStudentUpdate(user._id, body);
  }

  @Post('updates')
  @ApiOperation({ summary: 'Save sadhana update log' })
  async postUpdates(@CurrentUser() user: any, @Body() body: any) {
    return this.sadhanaService.handleStudentUpdate(user._id, body);
  }

  @Get('updates')
  @ApiOperation({ summary: 'Get student sadhana update logs' })
  async getUpdates(@CurrentUser() user: any) {
    return this.sadhanaService.getUpdates(user);
  }

  @Patch('updates/:id')
  @ApiOperation({ summary: 'Update sadhana update log' })
  async patchUpdate(@Param('id') id: string, @Body() body: any) {
    return this.sadhanaService.updateStudentUpdate(id, body);
  }

  @Delete('updates/:id')
  @ApiOperation({ summary: 'Delete sadhana update log' })
  async deleteUpdate(
    @Param('id') id: string,
    @Query('label') label?: string,
    @Query('activityKey') activityKey?: string,
  ) {
    return this.sadhanaService.deleteUpdate(id, label, activityKey);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete sadhana entry' })
  async deleteSadhanaById(
    @Param('id') id: string,
    @Query('label') label?: string,
    @Query('activityKey') activityKey?: string,
  ) {
    return this.sadhanaService.deleteUpdate(id, label, activityKey);
  }

  @Get('history')
  @Roles('folk_boy', 'residency', 'student', 'user', 'member')
  @ApiOperation({ summary: 'Get current student sadhana history (paginated)' })
  @ApiQuery({ name: 'page', required: false, example: 1 })
  @ApiQuery({ name: 'limit', required: false, example: 30 })
  async getMyHistory(
    @CurrentUser() user: any,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.sadhanaService.getHistory(user._id, page || 1, limit || 30);
  }

  @Get('date/:date')
  @ApiOperation({ summary: 'Get sadhana entry for specific date (YYYY-MM-DD)' })
  async getByDate(@CurrentUser() user: any, @Param('date') dateString: string) {
    return this.sadhanaService.getByDate(user._id, dateString);
  }

  @Get('user/:userId/date/:date')
  @Roles('preacher', 'admin')
  @ApiOperation({ summary: 'Get assigned student sadhana entry for specific date' })
  async getStudentSadhanaByDate(
    @Param('userId') userId: string,
    @Param('date') dateString: string,
  ) {
    return this.sadhanaService.getByDate(userId, dateString);
  }

  @Post('lock-day')
  @Roles('preacher', 'admin')
  @ApiOperation({ summary: 'Lock or unlock daily sadhana tracking for a student' })
  async lockDay(@CurrentUser() preacher: any, @Body() dto: LockDayDto) {
    return this.sadhanaService.lockOrUnlockDay(preacher._id, dto);
  }
}
