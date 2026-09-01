import {
  Controller,
  Get,
  Post,
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
  @Roles('folk_boy', 'residency')
  @ApiOperation({ summary: 'Log or update daily sadhana entry' })
  async logSadhana(@CurrentUser() user: any, @Body() dto: LogSadhanaDto) {
    return this.sadhanaService.logSadhana(user._id, dto);
  }

  @Get('history')
  @Roles('folk_boy', 'residency')
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
