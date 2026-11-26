import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { VoiceJob } from '../../database/entities';
import { AiModule } from '../ai/ai.module';
import { EventsModule } from '../events/events.module';
import { GiftsModule } from '../gifts/gifts.module';
import { QuotasModule } from '../quotas/quotas.module';
import { ParseController } from './parse.controller';
import { ParseService } from './parse.service';

@Module({
  imports: [TypeOrmModule.forFeature([VoiceJob]), AiModule, EventsModule, GiftsModule, QuotasModule],
  controllers: [ParseController],
  providers: [ParseService],
})
export class ParseModule {}
