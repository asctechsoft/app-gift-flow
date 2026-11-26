import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { notFound } from '../../common/app-error';
import { fold } from '../../common/text';
import { Invitation } from '../../database/entities';
import { AuditService } from '../audit/audit.service';
import { UpsertInvitationDto } from './invitations.dto';

export const invitationToApi = (i: Invitation) => ({
  id: i.id,
  person_name: i.personName,
  relationship: i.relationship,
  occasion: i.occasion,
  event_date: i.eventDate,
  event_time: i.eventTime,
  location: i.location,
  planned_vnd: i.plannedVnd,
  given_vnd: i.givenVnd,
  status: i.status,
  note: i.note,
  created_at: i.createdAt.toISOString(),
  updated_at: i.updatedAt.toISOString(),
  deleted_at: i.deletedAt ? i.deletedAt.toISOString() : null,
});

const clean = (s?: string | null) => {
  const t = (s ?? '').trim();
  return t.length ? t : null;
};

/** Lịch đi mừng: sự kiện của người khác mình được mời. Owner-scoped, xoá mềm, LWW. */
@Injectable()
export class InvitationsService {
  constructor(
    @InjectRepository(Invitation) private readonly repo: Repository<Invitation>,
    private readonly audit: AuditService,
  ) {}

  async list(ownerId: string, includeDeleted = false) {
    const rows = await this.repo.find({
      where: includeDeleted ? { ownerId } : { ownerId, deletedAt: IsNull() },
      order: { eventDate: 'ASC', eventTime: 'ASC', createdAt: 'ASC' },
    });
    return { items: rows.map(invitationToApi) };
  }

  async upsert(ownerId: string, id: string, dto: UpsertInvitationDto) {
    const existing = await this.repo.findOne({ where: { id } });
    if (existing && existing.ownerId !== ownerId) throw notFound('Không tìm thấy lời mời');
    const incoming = dto.updated_at ? new Date(dto.updated_at) : new Date();
    const name = dto.person_name.trim();
    const fields = {
      personName: name,
      relationship: clean(dto.relationship),
      occasion: dto.occasion ?? 'wedding',
      eventDate: dto.event_date,
      eventTime: dto.event_time ?? null,
      location: clean(dto.location),
      plannedVnd: dto.planned_vnd ?? 0,
      givenVnd: dto.given_vnd ?? 0,
      status: dto.status ?? 'upcoming',
      note: clean(dto.note),
      searchKey: fold(`${name} ${dto.relationship ?? ''} ${dto.location ?? ''}`).slice(0, 400),
    };
    if (!existing) {
      const saved = await this.repo.save(
        this.repo.create({
          id,
          ownerId,
          ...fields,
          createdAt: new Date(dto.created_at ?? incoming),
          updatedAt: incoming,
          deletedAt: null,
        }),
      );
      await this.audit.record(ownerId, 'event', saved.id, 'invitation_create', null, { occasion: saved.occasion });
      return invitationToApi(saved);
    }
    if (incoming.getTime() < existing.updatedAt.getTime()) return invitationToApi(existing); // LWW
    Object.assign(existing, { ...fields, updatedAt: incoming, deletedAt: null });
    const saved = await this.repo.save(existing);
    await this.audit.record(ownerId, 'event', saved.id, 'invitation_update', null, { status: saved.status });
    return invitationToApi(saved);
  }

  async remove(ownerId: string, id: string): Promise<void> {
    const i = await this.repo.findOne({ where: { id, ownerId } });
    if (!i) throw notFound('Không tìm thấy lời mời');
    if (i.deletedAt) return;
    i.deletedAt = new Date();
    i.updatedAt = i.deletedAt;
    await this.repo.save(i);
    await this.audit.record(ownerId, 'event', id, 'invitation_delete', null, { deleted: true });
  }
}
