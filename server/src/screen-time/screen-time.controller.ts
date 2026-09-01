import {
  Controller,
  Get,
  Post,
  Body,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ScreenTimeService } from './screen-time.service';
import { LogScreenTimeDto } from './dto/log-screen-time.dto';
import { FirebaseAuthGuard } from '../common/guards/firebase-auth.guard';
import { ActiveUserGuard } from '../common/guards/active-user.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Screen Time Tracking')
@Controller('screen-time')
@UseGuards(FirebaseAuthGuard, ActiveUserGuard)
@ApiBearerAuth('access-token')
export class ScreenTimeController {
  constructor(private readonly screenTimeService: ScreenTimeService) {}

  @Post()
  @ApiOperation({ summary: 'Log daily screen time usage (auto-synced from native channel)' })
  async logScreenTime(@CurrentUser() user: any, @Body() dto: LogScreenTimeDto) {
    return this.screenTimeService.logScreenTime(user._id, dto);
  }

  @Get('my')
  @ApiOperation({ summary: 'Get current user screen time logs' })
  async getMyLogs(@CurrentUser() user: any) {
    return this.screenTimeService.getMyLogs(user._id);
  }
}
