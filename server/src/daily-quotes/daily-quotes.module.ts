import { Module } from '@nestjs/common';
import { DailyQuotesController } from './daily-quotes.controller';
import { DailyQuotesService } from './daily-quotes.service';
import { DatabaseModule } from '../database/database.module';

@Module({
  imports: [DatabaseModule],
  controllers: [DailyQuotesController],
  providers: [DailyQuotesService],
  exports: [DailyQuotesService],
})
export class DailyQuotesModule {}
