import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { config } from './config';

// CHANGE v0.3: every request gets an anon-key client carrying that user's bearer JWT.
// This lets Postgres auth.uid() and RLS evaluate the real user. No service-role key.
export function createUserClient(accessToken: string): SupabaseClient {
  return createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    global: { headers: { Authorization: `Bearer ${accessToken}` } }
  });
}
