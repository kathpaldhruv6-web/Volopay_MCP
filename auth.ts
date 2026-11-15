import type { Request, Response, NextFunction } from 'express';
import { ApiError } from './errors';
import { createUserClient } from './supabase';
import type { WorkspaceRole } from './types';

const roles: WorkspaceRole[] = ['admin', 'implementation_manager', 'team_member'];

// CHANGE v0.3: authenticate bearer JWT with Supabase Auth, then independently resolve
// current workspace membership. X-Workspace-Context selects a workspace; it grants none.
export async function requireAuth(req: Request, _res: Response, next: NextFunction) {
  try {
    const header = req.header('authorization');
    if (!header?.startsWith('Bearer ')) throw new ApiError(401, 'AUTH_REQUIRED', 'Bearer token required');
    const token = header.slice(7).trim();
    if (!token) throw new ApiError(401, 'AUTH_REQUIRED', 'Bearer token required');

    const workspaceId = req.header('x-workspace-context');
    if (!workspaceId) throw new ApiError(400, 'WORKSPACE_CONTEXT_REQUIRED', 'Select an active workspace');

    const supabase = createUserClient(token);
    const { data: userData, error: userError } = await supabase.auth.getUser(token);
    if (userError || !userData.user) throw new ApiError(401, 'AUTH_INVALID_TOKEN', 'Token is invalid or expired');

    const { data: membership, error: membershipError } = await supabase
      .from('workspace_memberships')
      .select('role, active')
      .eq('workspace_id', workspaceId)
      .eq('user_id', userData.user.id)
      .eq('active', true)
      .maybeSingle();

    if (membershipError) throw new ApiError(500, 'AUTHORIZATION_LOOKUP_FAILED', 'Could not verify workspace membership');
    if (!membership || !roles.includes(membership.role as WorkspaceRole)) {
      throw new ApiError(403, 'WORKSPACE_ACCESS_DENIED', 'You do not have access to this workspace');
    }

    req.authContext = {
      userId: userData.user.id,
      workspaceId,
      role: membership.role as WorkspaceRole,
      supabase
    };
    next();
  } catch (error) { next(error); }
}
