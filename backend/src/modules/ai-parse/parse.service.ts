import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AppError, badRequest, conflict } from '../../common/app-error';
import { VoiceJob } from '../../database/entities';
import { AiService } from '../ai/ai.service';
import { AuditService } from '../audit/audit.service';
import { EventsService } from '../events/events.service';
import { GiftsService } from '../gifts/gifts.service';
import { QuotasService } from '../quotas/quotas.service';
import { ParseGiftDto } from './parse.dto';

export interface ParseGiftResponse {
  request_id: string;
  transcript: string;
  data: {
    guest_name: string | null;
    relationship: string | null;
    amount: number | null;
    currency: 'VND';
  };
  needs_review: boolean;
  possible_duplicate: boolean;
  warnings: string[];
  duplicate_candidates: Array<{ gift_id: string; guest_name: string; amount: number }>;
}

/**
 * Chỉ PHÂN TÍCH văn bản (không tạo bản ghi quà). Việc lưu là của API gifts hiện có,
 * do client quyết định theo business rules (auto-save / xác nhận).
 */
@Injectable()
export class ParseService {
  private readonly log = new Logger('Parse');

  constructor(
    @InjectRepository(VoiceJob) private readonly jobs: Repository<VoiceJob>,
    private readonly events: EventsService,
    private readonly gifts: GiftsService,
    private readonly ai: AiService,
    private readonly quotas: QuotasService,
    private readonly audit: AuditService,
  ) {}

  async parse(ownerId: string, dto: ParseGiftDto): Promise<ParseGiftResponse> {
    const text = dto.text.replace(/\s+/g, ' ').trim();
    if (text.replace(/[^\p{L}\p{N}]/gu, '').length < 2) throw badRequest('text_empty', 'Văn bản trống');

    // ---- idempotency theo (owner, request_id): không gọi AI/không trừ quota lần 2 ----
    const existing = await this.jobs.findOne({ where: { ownerId, requestId: dto.request_id } });
    if (existing) {
      if (existing.responseJson) return JSON.parse(existing.responseJson) as ParseGiftResponse;
      const stale = Date.now() - existing.createdAt.getTime() > 60_000;
      if (existing.state === 'processing' && !stale) {
        throw conflict('processing', 'Yêu cầu này đang được xử lý, hãy thử lại sau ít giây');
      }
      await this.jobs.delete({ id: existing.id });
    }

    const event = await this.events.getOwned(ownerId, dto.event_id); // 404 nếu không phải của mình
    if (event.status === 'closed') throw conflict('event_closed', 'Sự kiện đã đóng');

    await this.quotas.reserve(ownerId); // atomic, 429 khi hết lượt

    let job: VoiceJob;
    try {
      job = await this.jobs.save(
        this.jobs.create({
          ownerId,
          eventId: dto.event_id,
          requestId: dto.request_id,
          durationMs: 0,
          provider: this.ai.providerName,
          state: 'processing',
          warningCodes: '',
          responseJson: null,
          tokenUsage: null,
        }),
      );
    } catch {
      await this.quotas.release(ownerId);
      throw conflict('processing', 'Yêu cầu này đang được xử lý, hãy thử lại sau ít giây');
    }

    let outcome;
    try {
      outcome = await this.ai.processText(text);
    } catch (e) {
      this.log.warn(`AI provider failed for job ${job.id}: ${(e as Error).message}`);
      await this.quotas.release(ownerId); // lỗi nhà cung cấp: không tính lượt
      await this.jobs.delete({ id: job.id }); // cho phép thử lại cùng request_id
      throw new AppError(502, 'provider_error', 'Dịch vụ AI tạm thời lỗi, hãy thử lại');
    }

    const { candidate } = outcome;
    const warnings = [...candidate.warnings];
    const name = candidate.guest_name ?? '';
    const amount = candidate.amount_vnd;
    const dups = await this.gifts.findDuplicates(ownerId, dto.event_id, name, amount ?? 0);
    if (dups.length) warnings.push('possible_duplicate');

    const needsReview = candidate.needs_review || dups.length > 0 || !name || amount === null || amount <= 0;
    const response: ParseGiftResponse = {
      request_id: dto.request_id,
      transcript: text,
      data: {
        guest_name: name || null,
        relationship: candidate.relationship_label,
        amount: amount && amount > 0 ? amount : null,
        currency: 'VND',
      },
      needs_review: needsReview,
      possible_duplicate: dups.length > 0,
      warnings,
      duplicate_candidates: dups.map((d) => ({ gift_id: d.id, guest_name: d.guestName, amount: d.amountVnd })),
    };
    job.state = needsReview ? 'pending_review' : 'confirmed';
    job.warningCodes = warnings.join(',').slice(0, 500);
    job.responseJson = JSON.stringify(response);
    await this.jobs.save(job);
    // Log/audit không chứa transcript hay tên khách (PII).
    this.log.log(`parse job ${job.id} chars=${text.length} review=${needsReview} warnings=[${warnings.join(',')}]`);
    await this.audit.record(ownerId, 'voice', job.id, 'parse', null, {
      needs_review: needsReview,
      event_id: dto.event_id,
    });
    return response;
  }
}
