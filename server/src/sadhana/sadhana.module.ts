import { Module } from '@nestjs/common';
import { SadhanaService } from './sadhana.service';
import { SadhanaController } from './sadhana.controller';
import { DatabaseModule } from '../database/database.module';

@Module({
  imports: [DatabaseModule],
  controllers: [SadhanaController],
  providers: [SadhanaService],
  exports: [SadhanaService],
})
export class SadhanaModule {}
