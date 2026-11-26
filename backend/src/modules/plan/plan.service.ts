import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { badRequest, notFound } from '../../common/app-error';
import { fold } from '../../common/text';
import { PlanGuest, PlanItem } from '../../database/entities';
import { AuditService } from '../audit/audit.service';
import { EventsService } from '../events/events.service';
import { UpsertPlanGuestDto, UpsertPlanItemDto } from './plan.dto';

export const planItemToApi = (i: PlanItem) => ({
  id: i.id,
  event_id: i.eventId,
  category: i.category,
  name: i.name,
  planned_vnd: i.plannedVnd,
  paid_vnd: i.paidVnd,
  status: i.status,
  vendor: i.vendor,
  due_date: i.dueDate,
  note: i.note,
  created_at: i.createdAt.toISOString(),
  updated_at: i.updatedAt.toISOString(),
  deleted_at: i.deletedAt ? i.deletedAt.toISOString() : null,
});

export const planGuestToApi = (g: PlanGuest) => ({
  id: g.id,
  event_id: g.eventId,
  name: g.name,
  relationship: g.relationship,
  side: g.side,
  party_size: g.partySize,
  invite_status: g.inviteStatus,
  phone: g.phone,
  note: g.note,
  created_at: g.createdAt.toISOString(),
  updated_at: g.updatedAt.toISOString(),
  deleted_at: g.deletedAt ? g.deletedAt.toISOString() : null,
});

const clean = (s?: string | null) => {
  const t = (s ?? '').trim();
  return t.length ? t : null;
};

/**
 * Kế hoạch trước lễ: khoản chi (ngân sách) + khách mời dự kiến. Hoàn toàn tách khỏi
 * tiền mừng (gifts): không bao giờ cộng vào thống kê tiền mừng.
 */
@Injectable()
export class PlanService {
  constructor(
    @InjectRepository(PlanItem) private readonly items: Repository<PlanItem>,
    @InjectRepository(PlanGuest) private readonly guests: Repository<PlanGuest>,
    private readonly events: EventsService,
    private readonly audit: AuditService,
  ) {}

  // ---------------------------------------------------------------- khoản chi

  async listItems(ownerId: string, eventId: string, includeDeleted = false) {
    await this.events.getOwned(ownerId, eventId, includeDeleted);
    const rows = await this.items.find({
      where: includeDeleted ? { ownerId, eventId } : { ownerId, eventId, deletedAt: IsNull() },
      order: { category: 'ASC', createdAt: 'ASC' },
    });
    return { items: rows.map(planItemToApi) };
  }

  /** Upsert idempotent theo id; bản cũ hơn bản server bị bỏ (last-write-wins). */
  async upsertItem(ownerId: string, id: string, dto: UpsertPlanItemDto) {
    await this.events.getOwned(ownerId, dto.event_id, true);
    const existing = await this.items.findOne({ where: { id } });
    if (existing && existing.ownerId !== ownerId) throw notFound('Không tìm thấy khoản chi');
    const planned = dto.planned_vnd;
    const paid = dto.paid_vnd ?? 0;
    const incoming = dto.updated_at ? new Date(dto.updated_at) : new Date();
    const status = dto.status ?? (paid <= 0 ? 'planned' : paid >= planned ? 'paid' : 'deposit');
    if (!existing) {
      const created = new Date(dto.created_at ?? incoming);
      const saved = await this.items.save(
        this.items.create({
          id,
          eventId: dto.event_id,
          ownerId,
          category: dto.category,
          name: dto.name.trim(),
          plannedVnd: planned,
          paidVnd: paid,
          status,
          vendor: clean(dto.vendor),
          dueDate: dto.due_date ?? null,
          note: clean(dto.note),
          createdAt: created,
          updatedAt: incoming,
          deletedAt: null,
        }),
      );
      await this.audit.record(ownerId, 'event', saved.id, 'plan_item_create', null, { category: saved.category });
      return planItemToApi(saved);
    }
    if (incoming.getTime() < existing.updatedAt.getTime()) return planItemToApi(existing);
    Object.assign(existing, {
      eventId: dto.event_id,
      category: dto.category,
      name: dto.name.trim(),
      plannedVnd: planned,
      paidVnd: paid,
      status,
      vendor: clean(dto.vendor),
      dueDate: dto.due_date ?? null,
      note: clean(dto.note),
      updatedAt: incoming,
      deletedAt: null,
    });
    const saved = await this.items.save(existing);
    await this.audit.record(ownerId, 'event', saved.id, 'plan_item_update', null, { category: saved.category });
    return planItemToApi(saved);
  }

  async removeItem(ownerId: string, id: string): Promise<void> {
    const i = await this.items.findOne({ where: { id, ownerId } });
    if (!i) throw notFound('Không tìm thấy khoản chi');
    if (i.deletedAt) return;
    i.deletedAt = new Date();
    i.updatedAt = i.deletedAt;
    await this.items.save(i);
    await this.audit.record(ownerId, 'event', id, 'plan_item_delete', null, { deleted: true });
  }

  // ------------------------------------------------------------- khách dự kiến

  async listGuests(ownerId: string, eventId: string, includeDeleted = false) {
    await this.events.getOwned(ownerId, eventId, includeDeleted);
    const rows = await this.guests.find({
      where: includeDeleted ? { ownerId, eventId } : { ownerId, eventId, deletedAt: IsNull() },
      order: { createdAt: 'ASC' },
    });
    return { items: rows.map(planGuestToApi) };
  }

  async upsertGuest(ownerId: string, id: string, dto: UpsertPlanGuestDto) {
    await this.events.getOwned(ownerId, dto.event_id, true);
    const existing = await this.guests.findOne({ where: { id } });
    if (existing && existing.ownerId !== ownerId) throw notFound('Không tìm thấy khách');
    const name = dto.name.trim();
    if (!name) throw badRequest('name_required', 'Tên khách không được trống');
    const incoming = dto.updated_at ? new Date(dto.updated_at) : new Date();
    const fields = {
      eventId: dto.event_id,
      name,
      relationship: clean(dto.relationship),
      side: dto.side ?? 'mine',
      partySize: dto.party_size ?? 1,
      inviteStatus: dto.invite_status ?? 'planned',
      phone: clean(dto.phone),
      note: clean(dto.note),
      searchKey: fold(`${name} ${dto.relationship ?? ''} ${dto.phone ?? ''}`).slice(0, 400),
    };
    if (!existing) {
      const created = new Date(dto.created_at ?? incoming);
      const saved = await this.guests.save(
        this.guests.create({ id, ownerId, ...fields, createdAt: created, updatedAt: incoming, deletedAt: null }),
      );
      await this.audit.record(ownerId, 'event', saved.id, 'plan_guest_create', null, { side: saved.side });
      return planGuestToApi(saved);
    }
    if (incoming.getTime() < existing.updatedAt.getTime()) return planGuestToApi(existing);
    Object.assign(existing, { ...fields, updatedAt: incoming, deletedAt: null });
    const saved = await this.guests.save(existing);
    await this.audit.record(ownerId, 'event', saved.id, 'plan_guest_update', null, { status: saved.inviteStatus });
    return planGuestToApi(saved);
  }

  async removeGuest(ownerId: string, id: string): Promise<void> {
    const g = await this.guests.findOne({ where: { id, ownerId } });
    if (!g) throw notFound('Không tìm thấy khách');
    if (g.deletedAt) return;
    g.deletedAt = new Date();
    g.updatedAt = g.deletedAt;
    await this.guests.save(g);
    await this.audit.record(ownerId, 'event', id, 'plan_guest_delete', null, { deleted: true });
  }

  // ---------------------------------------------------------------- tổng hợp

  async summary(ownerId: string, eventId: string) {
    const ev = await this.events.getOwned(ownerId, eventId);
    const items = await this.items.find({ where: { ownerId, eventId, deletedAt: IsNull() } });
    const guests = await this.guests.find({ where: { ownerId, eventId, deletedAt: IsNull() } });

    const byCat = new Map<string, { planned: number; paid: number; count: number }>();
    for (const i of items) {
      const c = byCat.get(i.category) ?? { planned: 0, paid: 0, count: 0 };
      c.planned += i.plannedVnd;
      c.paid += i.paidVnd;
      c.count += 1;
      byCat.set(i.category, c);
    }
    const planned = items.reduce((a, i) => a + i.plannedVnd, 0);
    const paid = items.reduce((a, i) => a + i.paidVnd, 0);
    const budget = ev.budgetVnd;

    const status: Record<string, number> = { planned: 0, invited: 0, confirmed: 0, declined: 0 };
    const side: Record<string, number> = { mine: 0, parents: 0 };
    let headcount = 0;
    let headcountExpected = 0; // không tính khách từ chối
    for (const g of guests) {
      status[g.inviteStatus] = (status[g.inviteStatus] ?? 0) + 1;
      side[g.side] = (side[g.side] ?? 0) + 1;
      headcount += g.partySize;
      if (g.inviteStatus !== 'declined') headcountExpected += g.partySize;
    }
    return {
      event_id: eventId,
      budget_vnd: budget,
      planned_vnd: planned,
      paid_vnd: paid,
      remaining_to_pay_vnd: Math.max(0, planned - paid),
      budget_left_vnd: budget === null ? null : budget - planned,
      over_budget: budget !== null && planned > budget,
      by_category: [...byCat.entries()]
        .map(([category, v]) => ({ category, planned_vnd: v.planned, paid_vnd: v.paid, count: v.count }))
        .sort((a, b) => b.planned_vnd - a.planned_vnd),
      guests: {
        count: guests.length,
        headcount,
        headcount_expected: headcountExpected,
        by_status: status,
        by_side: side,
      },
    };
  }
}
