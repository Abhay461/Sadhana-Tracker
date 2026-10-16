import { Module } from '@nestjs/common';
import { PreachersService } from './preachers.service';
import { PreachersController } from './preachers.controller';
import { DatabaseModule } from '../database/database.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [DatabaseModule, NotificationsModule],
  controllers: [PreachersController],
  providers: [PreachersService],
  exports: [PreachersService],
})
export class PreachersModule {}
