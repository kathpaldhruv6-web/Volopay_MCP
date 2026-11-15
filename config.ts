import 'dotenv/config';
import { z } from 'zod';

// CHANGE v0.3: centralized runtime validation; missing configuration fails at startup
// instead of silently falling back to mock identity or privileged credentials.
const schema = z.object({
  SUPABASE_URL: z.string().url(),
  SUPABASE_ANON_KEY: z.string().min(20),
  PORT: z.coerce.number().int().min(1).max(65535).default(8788),
  CORS_ORIGIN: z.string().default('http://localhost:5173'),
  CURSOR_HMAC_SECRET: z.string().min(32)
});
const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  throw new Error(`Invalid environment configuration: ${parsed.error.message}`);
}
export const config = parsed.data;
