import { randomUUID } from 'crypto';
import { Logger } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';

const log = new Logger('HTTP');

/** Gắn correlation id (client gửi x-correlation-id, hoặc tự sinh). */
export function requestIdMiddleware(req: Request & { requestId?: string }, res: Response, next: NextFunction) {
  const incoming = req.header('x-correlation-id');
  const id = incoming && /^[A-Za-z0-9-]{8,64}$/.test(incoming) ? incoming : randomUUID();
  req.requestId = id;
  res.setHeader('x-request-id', id);
  // Log truy cập: chỉ method + đường dẫn (bỏ query) + status + thời gian. Không log body/header (PII, token).
  const started = Date.now();
  res.on('finish', () => {
    const path = req.originalUrl.split('?')[0];
    if (path.startsWith('/health')) return;
    log.log(`${req.method} ${path} -> ${res.statusCode} (${Date.now() - started}ms) ip=${req.ip}`);
  });
  next();
}
