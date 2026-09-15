import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { Festival, FestivalSchema } from '../database/schemas/festivals.schema';
import { FestivalsController } from './festivals.controller';
import { FestivalsService } from './festivals.service';

@Module({
  imports: [
    MongooseModule.forFeature([{ name: Festival.name, schema: FestivalSchema }]),
  ],
  controllers: [FestivalsController],
  providers: [FestivalsService],
  exports: [FestivalsService],
})
export class FestivalsModule {}
