import { Module } from '@nestjs/common';
import { PreachersService } from './preachers.service';
import { PreachersController } from './preachers.controller';
import { DatabaseModule } from '../database/database.module';

@Module({
  imports: [DatabaseModule],
  controllers: [PreachersController],
  providers: [PreachersService],
  exports: [PreachersService],
})
export class PreachersModule {}
