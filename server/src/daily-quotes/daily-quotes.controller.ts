import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
} from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { DailyQuotesService } from './daily-quotes.service';
import { CreateDailyQuoteDto } from './dto/create-daily-quote.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Daily Quotes')
@Controller('daily-quotes')
export class DailyQuotesController {
  constructor(private readonly quotesService: DailyQuotesService) {}

  @Get('today')
  @ApiOperation({ summary: 'Get active Daily Quote for today (or latest)' })
  async getTodayQuote() {
    return this.quotesService.getTodayQuote();
  }

  @Get()
  @ApiOperation({ summary: 'Get all active Daily Quotes' })
  async getAllQuotes() {
    return this.quotesService.getAllQuotes();
  }

  @Post()
  @ApiOperation({ summary: 'Publish new Daily Quote (Admin Portal & App)' })
  async createQuote(@CurrentUser() user: any, @Body() dto: CreateDailyQuoteDto) {
    return this.quotesService.createQuote(user, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete Daily Quote (Admin Portal)' })
  async deleteQuote(@Param('id') id: string) {
    return this.quotesService.deleteQuote(id);
  }
}
