import type { ErrorRequestHandler, Request, Response, NextFunction } from 'express';
import { randomUUID } from 'node:crypto';

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string
  ) { super(message); }
}

export function requestId(req: Request, res: Response, next: NextFunction) {
  req.requestId = randomUUID();
  res.setHeader('X-Request-Id', req.requestId);
  next();
}

// CHANGE v0.3: errors use one stable envelope; never hide a failure inside a 200/data result.
export const errorHandler: ErrorRequestHandler = (err, req, res, _next) => {
  const e = err instanceof ApiError ? err : new ApiError(500, 'INTERNAL_ERROR', 'An unexpected error occurred');
  if (e.status >= 500) console.error({ requestId: req.requestId, error: err });
  res.status(e.status).json({
    error: { code: e.code, message: e.message, requestId: req.requestId ?? null }
  });
};
