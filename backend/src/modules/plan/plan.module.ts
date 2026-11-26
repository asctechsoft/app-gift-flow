import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PlanGuest, PlanItem } from '../../database/entities';
import { EventsModule } from '../events/events.module';
import { PlanController } from './plan.controller';
import { PlanService } from './plan.service';

@Module({
  imports: [TypeOrmModule.forFeature([PlanItem, PlanGuest]), EventsModule],
  controllers: [PlanController],
  providers: [PlanService],
})
export class PlanModule {}
