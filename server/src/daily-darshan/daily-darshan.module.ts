import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { MediaModule } from '../media/media.module';
import { DailyDarshanController } from './daily-darshan.controller';
import { DailyDarshanService } from './daily-darshan.service';

@Module({
  imports: [DatabaseModule, MediaModule],
  controllers: [DailyDarshanController],
  providers: [DailyDarshanService],
  exports: [DailyDarshanService],
})
export class DailyDarshanModule {}
