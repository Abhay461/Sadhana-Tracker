import { Module } from '@nestjs/common';
import { DailyQuotesController } from './daily-quotes.controller';
import { DailyQuotesService } from './daily-quotes.service';
import { DatabaseModule } from '../database/database.module';
import { MediaModule } from '../media/media.module';

@Module({
  imports: [DatabaseModule, MediaModule],
  controllers: [DailyQuotesController],
  providers: [DailyQuotesService],
  exports: [DailyQuotesService],
})
export class DailyQuotesModule {}
