import { Inject, Injectable } from '@nestjs/common';
import { fold } from '../../common/text';
import { AppConfig, CONFIG } from '../../config/config';
import {
  Candidate,
  EXTRACTION_PROVIDER,
  ExtractionProvider,
  STT_PROVIDER,
  SttProvider,
} from './ai.types';
import { parseVnAmount } from './vn-amount';

export interface AiOutcome {
  transcript: string;
  candidate: Candidate;
  provider: string;
}

/**
 * Pipeline: audio -> STT -> LLM JSON -> normalizer VND -> schema validator.
 * "Schema-compliant không đồng nghĩa đúng nghĩa": luôn cross-check bằng bộ phân tích
 * số tiền tiếng Việt xác định (parseVnAmount) và ép pending khi mơ hồ.
 */
@Injectable()
export class AiService {
  constructor(
    @Inject(STT_PROVIDER) private readonly stt: SttProvider,
    @Inject(EXTRACTION_PROVIDER) private readonly extractor: ExtractionProvider,
    @Inject(CONFIG) private readonly cfg: AppConfig,
  ) {}

  get providerName(): string {
    return `${this.stt.name}+${this.extractor.name}`;
  }

  async process(audio: Buffer, mime: string, hint?: string): Promise<AiOutcome> {
    const { transcript } = await this.stt.transcribe(audio, mime, this.cfg.aiProvider === 'mock' ? hint : undefined);
    return this.processText(transcript);
  }

  /** Văn bản đã có sẵn (STT trên thiết bị) -> bỏ qua bước STT, chỉ trích xuất + chuẩn hoá. */
  async processText(transcript: string): Promise<AiOutcome> {
    if (!transcript || transcript.replace(/[\s.,!?…]/g, '').length < 3) {
      return {
        transcript,
        provider: this.providerName,
        candidate: {
          guest_name: null,
          relationship_label: null,
          amount_vnd: null,
          currency: 'VND',
          needs_review: true,
          warnings: ['no_content'],
        },
      };
    }
    const raw = await this.extractor.extract(transcript);
    return { transcript, provider: this.providerName, candidate: this.normalize(raw, transcript) };
  }

  /** Chuẩn hoá + kiểm tra schema phía server; mọi nghi ngờ => needs_review. */
  normalize(raw: Partial<Candidate> | null | undefined, transcript: string): Candidate {
    const warnings = new Set<string>(Array.isArray(raw?.warnings) ? raw!.warnings.filter((w) => typeof w === 'string') : []);

    let name = typeof raw?.guest_name === 'string' ? raw.guest_name.replace(/\s+/g, ' ').trim() : '';
    if (!name || ['null', 'unknown', 'không rõ', 'khong ro'].includes(fold(name))) name = '';
    if (name.length > 200) name = name.slice(0, 200);

    let rel = typeof raw?.relationship_label === 'string' ? raw.relationship_label.trim() : '';
    if (rel.length > 100) rel = rel.slice(0, 100);

    let amount: number | null =
      typeof raw?.amount_vnd === 'number' && Number.isInteger(raw.amount_vnd) && raw.amount_vnd > 0
        ? raw.amount_vnd
        : null;

    // Cross-check bằng bộ phân tích xác định.
    const rule = parseVnAmount(transcript);
    if (rule.ambiguous) {
      amount = null; // "năm trăm" - không đoán đơn vị
      warnings.add('amount_ambiguous');
    } else if (rule.amount !== null) {
      // luật xác định đọc được rõ ràng (vd "200 nghìn") -> bỏ cảnh báo mơ hồ do LLM tự thêm
      if (amount === rule.amount || amount === null) warnings.delete('amount_ambiguous');
      if (amount === null) amount = rule.amount;
      else if (amount !== rule.amount) {
        warnings.add('amount_mismatch');
        amount = rule.amount; // luật xác định ưu tiên hơn LLM, vẫn buộc duyệt tay
      }
    }
    if (rule.multiple) warnings.add('self_correction');

    if (amount !== null && amount > this.cfg.maxAmountVnd) {
      amount = null;
      warnings.add('amount_out_of_range');
    }
    if (amount === null && !warnings.has('amount_ambiguous') && !warnings.has('amount_out_of_range')) {
      warnings.add('amount_missing');
    }
    if (!name) warnings.add('name_missing');
    // LLM tự đánh dấu "không chắc" mà không nêu lý do: chỉ chấp nhận bỏ qua khi bằng chứng xác định
    // đủ mạnh (số tiền khớp bộ đọc số xác định VÀ tên xuất hiện nguyên văn trong câu nói).
    const evidence =
      amount !== null && rule.amount === amount && !!name && fold(transcript).includes(fold(name));
    if (raw?.needs_review === true && warnings.size === 0 && !evidence) warnings.add('model_unsure');

    return {
      guest_name: name || null,
      relationship_label: rel || null,
      amount_vnd: amount,
      currency: 'VND',
      needs_review: warnings.size > 0,
      warnings: [...warnings],
    };
  }
}
