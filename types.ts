import type { SupabaseClient } from '@supabase/supabase-js';

export type WorkspaceRole = 'admin' | 'implementation_manager' | 'team_member';

export interface AuthContext {
  userId: string;
  workspaceId: string;
  role: WorkspaceRole;
  supabase: SupabaseClient;
}

declare global {
  namespace Express {
    interface Request {
      authContext?: AuthContext;
      requestId?: string;
    }
  }
}
