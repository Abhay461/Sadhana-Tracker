import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
} from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { FestivalsService } from './festivals.service';
import { CreateFestivalDto } from './dto/create-festival.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Festivals')
@Controller('festivals')
export class FestivalsController {
  constructor(private readonly festivalsService: FestivalsService) {}

  @Get('today')
  @ApiOperation({ summary: "Get active Festival for today's date" })
  async getTodayFestival() {
    return this.festivalsService.getTodayFestival();
  }

  @Get('all')
  @ApiOperation({ summary: 'Get all Festivals for management' })
  async getAllFestivals() {
    return this.festivalsService.getAllFestivals();
  }

  @Post()
  @ApiOperation({ summary: 'Publish new Festival entry' })
  async createFestival(@CurrentUser() user: any, @Body() dto: CreateFestivalDto) {
    return this.festivalsService.createFestival(user, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete Festival entry' })
  async deleteFestival(@Param('id') id: string) {
    return this.festivalsService.deleteFestival(id);
  }
}
