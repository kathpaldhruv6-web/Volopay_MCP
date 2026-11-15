import { z } from 'zod';
import { ApiError } from './errors';

export const pageQuery = z.object({
  limit: z.coerce.number().int().min(1).max(50).default(20),
  cursor: z.string().max(2048).optional()
});
export const uuid = z.string().uuid();

export function parse<T>(schema: z.ZodType<T>, value: unknown): T {
  const result = schema.safeParse(value);
  if (!result.success) throw new ApiError(400, 'VALIDATION_ERROR', result.error.issues.map(i => i.message).join('; '));
  return result.data;
}
export function context(req: Express.Request) {
  if (!req.authContext) throw new ApiError(401, 'AUTH_REQUIRED', 'Authentication required');
  return req.authContext;
}
