import { createHmac, timingSafeEqual } from 'node:crypto';
import { ApiError } from './errors';

const secret = process.env.CURSOR_HMAC_SECRET;
if (!secret || secret.length < 32) {
  // Fail closed: cursor pagination is unavailable until a strong secret is configured.
}
type CursorPayload = { v: 1; userId: string; workspaceId: string; scope: string; offset: number; exp: number };
function signature(body: string) {
  if (!secret || secret.length < 32) throw new ApiError(503,'CURSOR_NOT_CONFIGURED','Cursor pagination is not configured');
  return createHmac('sha256',secret).update(body).digest('base64url');
}
export function encodeCursor(input: Omit<CursorPayload,'v'|'exp'>, ttlSeconds=3600): string {
  const body=Buffer.from(JSON.stringify({ ...input, v:1, exp:Math.floor(Date.now()/1000)+ttlSeconds })).toString('base64url');
  return `${body}.${signature(body)}`;
}
export function decodeCursor(token: string | undefined, expected: {userId:string;workspaceId:string;scope:string}): number {
  if(!token) return 0;
  if(token.length>2048) throw new ApiError(400,'INVALID_CURSOR','Invalid cursor');
  const parts=token.split('.');
  if(parts.length!==2 || !parts[0] || !parts[1]) throw new ApiError(400,'INVALID_CURSOR','Invalid cursor');
  const body=parts[0]; const sig=parts[1];
  const expectedSig=signature(body);
  const a=Buffer.from(sig); const b=Buffer.from(expectedSig);
  if(a.length!==b.length || !timingSafeEqual(a,b)) throw new ApiError(400,'INVALID_CURSOR','Invalid cursor');
  let payload: CursorPayload;
  try { payload=JSON.parse(Buffer.from(body,'base64url').toString('utf8')) as CursorPayload; }
  catch { throw new ApiError(400,'INVALID_CURSOR','Invalid cursor'); }
  if(payload.v!==1 || payload.exp<Math.floor(Date.now()/1000) || payload.offset<0 || payload.offset>5000 ||
     payload.userId!==expected.userId || payload.workspaceId!==expected.workspaceId || payload.scope!==expected.scope) {
    throw new ApiError(400,'INVALID_CURSOR','Cursor is expired or does not match this query');
  }
  return payload.offset;
}
