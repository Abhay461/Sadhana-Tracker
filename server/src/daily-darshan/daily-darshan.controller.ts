import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
} from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { DailyDarshanService } from './daily-darshan.service';
import { CreateDailyDarshanDto } from './dto/create-daily-darshan.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Daily Darshan')
@Controller('daily-darshan')
export class DailyDarshanController {
  constructor(private readonly darshanService: DailyDarshanService) {}

  @Get('today')
  @ApiOperation({ summary: 'Get active Daily Darshan for today (or latest)' })
  async getTodayDarshan() {
    return this.darshanService.getTodayDarshan();
  }

  @Get('all')
  @ApiOperation({ summary: 'Get all Daily Darshans for management' })
  async getAllDarshans() {
    return this.darshanService.getAllDarshans();
  }

  @Post()
  @ApiOperation({ summary: 'Publish new Daily Darshan (Admin Portal & App)' })
  async createDarshan(@CurrentUser() user: any, @Body() dto: CreateDailyDarshanDto) {
    return this.darshanService.createDarshan(user, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete Daily Darshan (Admin Portal)' })
  async deleteDarshan(@Param('id') id: string) {
    return this.darshanService.deleteDarshan(id);
  }
}
