import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryColumn,
  PrimaryGeneratedColumn,
} from 'typeorm';

/**
 * Entities viết portable cho PostgreSQL (prod) và sql.js (dev/test):
 * không dùng kiểu riêng của PG (jsonb/timestamptz) ở đây.
 */

@Entity('users')
@Index('uq_users_provider', ['authProvider', 'providerUserId'], { unique: true })
export class User {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column({ type: 'varchar', length: 20 }) authProvider: string;
  @Column({ type: 'varchar', length: 128 }) providerUserId: string;
  @Column({ type: 'varchar', length: 100, nullable: true }) displayName: string | null;
  @Column({ type: 'varchar', length: 20, default: 'free' }) plan: string;
  @CreateDateColumn() createdAt: Date;
}

@Entity('refresh_tokens')
export class RefreshToken {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Index('idx_refresh_user') @Column({ type: 'varchar', length: 36 }) userId: string;
  @Index('uq_refresh_hash', { unique: true }) @Column({ type: 'varchar', length: 64 }) tokenHash: string;
  @Column({ type: Date }) expiresAt: Date;
  @Column({ type: Date, nullable: true }) revokedAt: Date | null;
  @CreateDateColumn() createdAt: Date;
}

@Entity('events')
@Index('idx_events_owner_date', ['ownerId', 'eventDate'])
export class GiftEvent {
  @PrimaryColumn({ type: 'varchar', length: 36 }) id: string;
  @Column({ type: 'varchar', length: 36 }) ownerId: string;
  @Column({ type: 'varchar', length: 200 }) name: string;
  @Column({ type: 'varchar', length: 30, default: 'wedding' }) type: string;
  @Column({ type: 'varchar', length: 10 }) eventDate: string;
  @Column({ type: 'varchar', length: 300, nullable: true }) location: string | null;
  @Column({ type: 'varchar', length: 20, default: 'active' }) status: string;
  /** Tổng ngân sách dự kiến của kế hoạch sự kiện (VND), null = chưa đặt. */
  @Column({ type: 'integer', nullable: true }) budgetVnd: number | null;
  @Column({ type: Date }) createdAt: Date;
  @Column({ type: Date }) updatedAt: Date;
  @Column({ type: Date, nullable: true }) deletedAt: Date | null;
}

@Entity('gifts')
@Index('uq_gifts_owner_request', ['ownerId', 'clientRequestId'], { unique: true })
@Index('idx_gifts_event_status', ['eventId', 'status'])
@Index('idx_gifts_event_created', ['eventId', 'createdAt', 'id'])
export class Gift {
  @PrimaryColumn({ type: 'varchar', length: 36 }) id: string;
  @Column({ type: 'varchar', length: 36 }) eventId: string;
  @Column({ type: 'varchar', length: 36 }) ownerId: string;
  @Column({ type: 'varchar', length: 200, default: '' }) guestName: string;
  @Column({ type: 'varchar', length: 100, nullable: true }) relationshipLabel: string | null;
  @Column({ type: 'integer', default: 0 }) amountVnd: number;
  @Column({ type: 'varchar', length: 1000, nullable: true }) note: string | null;
  /** confirmed | pending_review (processing/failed chỉ tồn tại ở client) */
  @Column({ type: 'varchar', length: 20 }) status: string;
  @Column({ type: 'varchar', length: 10, default: 'manual' }) source: string;
  @Column({ type: 'varchar', length: 1000, nullable: true }) transcript: string | null;
  /** mine = khách của mình | parents = khách của bố mẹ */
  @Column({ type: 'varchar', length: 10, default: 'mine' }) side: string;
  @Column({ type: 'varchar', length: 36 }) clientRequestId: string;
  /** Chuẩn hoá không dấu để tìm kiếm tiếng Việt. */
  @Column({ type: 'varchar', length: 1400, default: '' }) searchKey: string;
  @Column({ type: Date }) createdAt: Date;
  @Column({ type: Date }) updatedAt: Date;
  @Column({ type: Date, nullable: true }) deletedAt: Date | null;
}

@Entity('voice_jobs')
@Index('uq_voice_owner_request', ['ownerId', 'requestId'], { unique: true })
export class VoiceJob {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column({ type: 'varchar', length: 36 }) ownerId: string;
  @Column({ type: 'varchar', length: 36 }) eventId: string;
  @Column({ type: 'varchar', length: 36 }) requestId: string;
  @Column({ type: 'integer', default: 0 }) durationMs: number;
  @Column({ type: 'varchar', length: 30, default: 'mock' }) provider: string;
  /** processing | confirmed | pending_review | failed */
  @Column({ type: 'varchar', length: 20 }) state: string;
  @Column({ type: 'varchar', length: 500, default: '' }) warningCodes: string;
  /** Phản hồi đã trả cho client - phát lại khi client gửi lại cùng request_id. */
  @Column({ type: 'text', nullable: true }) responseJson: string | null;
  @Column({ type: 'integer', nullable: true }) tokenUsage: number | null;
  @CreateDateColumn() createdAt: Date;
}

@Entity('audit_logs')
@Index('idx_audit_actor', ['actorId', 'createdAt'])
export class AuditLog {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column({ type: 'varchar', length: 36 }) actorId: string;
  @Column({ type: 'varchar', length: 30 }) entityType: string;
  @Column({ type: 'varchar', length: 36 }) entityId: string;
  @Column({ type: 'varchar', length: 30 }) action: string;
  /** Đã che PII: chỉ lưu trường kỹ thuật (status, amount), KHÔNG lưu tên khách. */
  @Column({ type: 'text', nullable: true }) beforeJson: string | null;
  @Column({ type: 'text', nullable: true }) afterJson: string | null;
  @CreateDateColumn() createdAt: Date;
}

@Entity('usage_quotas')
@Index('uq_quota_owner_period', ['ownerId', 'period'], { unique: true })
export class UsageQuota {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column({ type: 'varchar', length: 36 }) ownerId: string;
  /** YYYY-MM */
  @Column({ type: 'varchar', length: 7 }) period: string;
  @Column({ type: 'integer' }) quotaLimit: number;
  @Column({ type: 'integer', default: 0 }) used: number;
}

@Entity('export_jobs')
export class ExportJob {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Index('idx_export_owner') @Column({ type: 'varchar', length: 36 }) ownerId: string;
  @Column({ type: 'varchar', length: 36 }) eventId: string;
  @Column({ type: 'varchar', length: 300 }) filePath: string;
  @Column({ type: 'varchar', length: 200 }) fileName: string;
  @Column({ type: 'integer', default: 0 }) rows: number;
  @Column({ type: 'integer', default: 0 }) confirmedTotal: number;
  @Column({ type: Date }) expiresAt: Date;
  @CreateDateColumn() createdAt: Date;
}

/** Một khoản chi trong kế hoạch (ngân sách) của sự kiện. KHÔNG liên quan tiền mừng. */
@Entity('plan_items')
@Index('idx_plan_items_event', ['eventId', 'category'])
export class PlanItem {
  @PrimaryColumn({ type: 'varchar', length: 36 }) id: string;
  @Column({ type: 'varchar', length: 36 }) eventId: string;
  @Column({ type: 'varchar', length: 36 }) ownerId: string;
  @Column({ type: 'varchar', length: 30 }) category: string;
  @Column({ type: 'varchar', length: 200 }) name: string;
  @Column({ type: 'integer', default: 0 }) plannedVnd: number;
  @Column({ type: 'integer', default: 0 }) paidVnd: number;
  /** planned | deposit | paid */
  @Column({ type: 'varchar', length: 12, default: 'planned' }) status: string;
  @Column({ type: 'varchar', length: 200, nullable: true }) vendor: string | null;
  @Column({ type: 'varchar', length: 10, nullable: true }) dueDate: string | null;
  @Column({ type: 'varchar', length: 1000, nullable: true }) note: string | null;
  @Column({ type: Date }) createdAt: Date;
  @Column({ type: Date }) updatedAt: Date;
  @Column({ type: Date, nullable: true }) deletedAt: Date | null;
}

/** Khách mời DỰ KIẾN (danh sách lên kế hoạch trước lễ). Không có tiền mừng. */
@Entity('plan_guests')
@Index('idx_plan_guests_event', ['eventId', 'inviteStatus'])
export class PlanGuest {
  @PrimaryColumn({ type: 'varchar', length: 36 }) id: string;
  @Column({ type: 'varchar', length: 36 }) eventId: string;
  @Column({ type: 'varchar', length: 36 }) ownerId: string;
  @Column({ type: 'varchar', length: 200 }) name: string;
  @Column({ type: 'varchar', length: 100, nullable: true }) relationship: string | null;
  /** mine | parents (khách của mình / của bố mẹ) */
  @Column({ type: 'varchar', length: 10, default: 'mine' }) side: string;
  /** Số người đi cùng (tính cả khách), tối thiểu 1. */
  @Column({ type: 'integer', default: 1 }) partySize: number;
  /** planned | invited | confirmed | declined */
  @Column({ type: 'varchar', length: 12, default: 'planned' }) inviteStatus: string;
  @Column({ type: 'varchar', length: 30, nullable: true }) phone: string | null;
  @Column({ type: 'varchar', length: 1000, nullable: true }) note: string | null;
  @Column({ type: 'varchar', length: 400, default: '' }) searchKey: string;
  @Column({ type: Date }) createdAt: Date;
  @Column({ type: Date }) updatedAt: Date;
  @Column({ type: Date, nullable: true }) deletedAt: Date | null;
}

export const ALL_ENTITIES = [
  User,
  RefreshToken,
  GiftEvent,
  Gift,
  VoiceJob,
  AuditLog,
  UsageQuota,
  ExportJob,
  PlanItem,
  PlanGuest,
];
