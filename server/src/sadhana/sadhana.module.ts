import { Module } from '@nestjs/common';
import { SadhanaService } from './sadhana.service';
import { SadhanaController } from './sadhana.controller';
import { DatabaseModule } from '../database/database.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [DatabaseModule, NotificationsModule],
  controllers: [SadhanaController],
  providers: [SadhanaService],
  exports: [SadhanaService],
})
export class SadhanaModule {}
