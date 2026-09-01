import { Module } from '@nestjs/common';
import { ScreenTimeService } from './screen-time.service';
import { ScreenTimeController } from './screen-time.controller';
import { DatabaseModule } from '../database/database.module';

@Module({
  imports: [DatabaseModule],
  controllers: [ScreenTimeController],
  providers: [ScreenTimeService],
  exports: [ScreenTimeService],
})
export class ScreenTimeModule {}
