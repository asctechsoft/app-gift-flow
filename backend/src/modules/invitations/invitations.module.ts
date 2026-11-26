import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Invitation } from '../../database/entities';
import { InvitationsController } from './invitations.controller';
import { InvitationsService } from './invitations.service';

@Module({
  imports: [TypeOrmModule.forFeature([Invitation])],
  controllers: [InvitationsController],
  providers: [InvitationsService],
})
export class InvitationsModule {}
