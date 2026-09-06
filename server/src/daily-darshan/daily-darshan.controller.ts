import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { DailyDarshanService } from './daily-darshan.service';
import { CreateDailyDarshanDto } from './dto/create-daily-darshan.dto';
import { FirebaseAuthGuard } from '../common/guards/firebase-auth.guard';
import { ActiveUserGuard } from '../common/guards/active-user.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';

@ApiTags('Daily Darshan')
@Controller('daily-darshan')
@UseGuards(FirebaseAuthGuard, ActiveUserGuard)
@ApiBearerAuth('access-token')
export class DailyDarshanController {
  constructor(private readonly darshanService: DailyDarshanService) {}

  @Get('today')
  @ApiOperation({ summary: 'Get active Daily Darshan for today (or latest)' })
  async getTodayDarshan() {
    return this.darshanService.getTodayDarshan();
  }

  @Post()
  @UseGuards(RolesGuard)
  @Roles('admin')
  @ApiOperation({ summary: 'Publish new Daily Darshan (Admin only)' })
  async createDarshan(@CurrentUser() user: any, @Body() dto: CreateDailyDarshanDto) {
    return this.darshanService.createDarshan(user, dto);
  }

  @Delete(':id')
  @UseGuards(RolesGuard)
  @Roles('admin')
  @ApiOperation({ summary: 'Delete Daily Darshan (Admin only)' })
  async deleteDarshan(@Param('id') id: string) {
    return this.darshanService.deleteDarshan(id);
  }
}
