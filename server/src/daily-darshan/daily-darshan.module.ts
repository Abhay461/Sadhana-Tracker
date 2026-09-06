import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { DailyDarshanController } from './daily-darshan.controller';
import { DailyDarshanService } from './daily-darshan.service';

@Module({
  imports: [DatabaseModule],
  controllers: [DailyDarshanController],
  providers: [DailyDarshanService],
  exports: [DailyDarshanService],
})
export class DailyDarshanModule {}
