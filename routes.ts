import { Router, type Request, type Response, type NextFunction } from 'express';
import { z } from 'zod';
import { ApiError } from './errors';
import { context } from './validation';
import { decodeCursor, encodeCursor } from './pagination';
import { proposalBodySchema } from './proposal-validation';

export const router = Router();

function asyncRoute(fn: (req: Request, res: Response) => Promise<void>) {
  return (req: Request, res: Response, next: NextFunction) => { void fn(req, res).catch(next); };
}
function getContext(req: Request) { return context(req); }
function pageArgs(req: Request, scope: string) {
  const c=getContext(req);
  const limit = Math.min(50, Math.max(1, Number(req.query.limit ?? 20)));
  if (!Number.isInteger(limit) || limit < 1) throw new ApiError(400, 'VALIDATION_ERROR', 'limit must be an integer between 1 and 50');
  const cursor = typeof req.query.cursor === 'string' ? req.query.cursor : undefined;
  const offset=decodeCursor(cursor,{userId:c.userId,workspaceId:c.workspaceId,scope});
  return { limit, offset };
}
function pageWithCursor<T>(data:T[], total:number, limit:number, offset:number, scope:string, c:{userId:string;workspaceId:string}) {
  const hasMore=offset+data.length<total;
  return {data,page:{nextCursor:hasMore?encodeCursor({userId:c.userId,workspaceId:c.workspaceId,scope,offset:offset+data.length}):null,hasMore},asOf:new Date().toISOString()};
}
function safeError(error: unknown): never {
  const e=error as {code?:unknown;message?:unknown};
  const code=String(e?.message??e?.code??'');
  if(code.includes('AUTH_REQUIRED')) throw new ApiError(401,'AUTH_REQUIRED','Authentication required');
  if(code.includes('WORKSPACE_ACCESS_DENIED')||code.includes('ONBOARDING_ACCESS_DENIED')) throw new ApiError(403,'WORKSPACE_ACCESS_DENIED','Access denied');
  if(code.includes('APPROVAL_FORBIDDEN')||code.includes('SELF_APPROVAL_FORBIDDEN')) throw new ApiError(403,'APPROVAL_FORBIDDEN','You cannot approve or reject this proposal');
  if(code.includes('RESOURCE_NOT_FOUND')||e?.code==='PGRST116'||e?.code==='P0002') throw new ApiError(404,'RESOURCE_NOT_FOUND','Resource not found');
  if(code.includes('VERSION_CONFLICT')||code.includes('PROPOSAL_NOT_PENDING')) throw new ApiError(409,'RECORD_VERSION_CONFLICT','The record or proposal has changed; refresh and retry');
  if(code.includes('IDEMPOTENCY_CONFLICT')) throw new ApiError(409,'IDEMPOTENCY_CONFLICT','This idempotency key was already used with a different request');
  if(code.includes('INVALID_')||code.includes('UNKNOWN_PROPOSAL_FIELD')||e?.code==='22023') throw new ApiError(400,'VALIDATION_ERROR','The request failed validation');
  throw new ApiError(500,'DATABASE_OPERATION_FAILED','The database operation could not be completed');
}
async function queryList(req: Request, table: string, onboardingColumn = 'onboarding_id') {
  const c = getContext(req); const scope=`${table}|${String(req.query.onboardingId??'')}|${String(req.query.status??'')}`;
  const { limit, offset } = pageArgs(req,scope);
  const projections:Record<string,string>={
    commitments:'id,onboarding_id,title,status,due_date,created_at,updated_at,version',
    tasks:'id,onboarding_id,title,status,priority,due_date,created_at,updated_at,version'
  };
  const projection=projections[table];
  if(!projection) throw new ApiError(400,'UNSUPPORTED_LIST','Unsupported list');
  let q = c.supabase.from(table).select(projection,{count:'exact'}).eq('workspace_id', c.workspaceId).order('created_at',{ascending:false}).order('id',{ascending:true}).range(offset,offset+limit-1);
  if (typeof req.query.onboardingId === 'string') q = q.eq(onboardingColumn, req.query.onboardingId);
  if (typeof req.query.status === 'string') q = q.eq('status', req.query.status);
  const { data, error, count } = await q;
  if (error) safeError(error);
  return pageWithCursor(data??[],count??0,limit,offset,scope,c);
}

// 1. list_onboardings — changed from mock-only fixtures to RLS-scoped database reads.
router.get('/onboardings', asyncRoute(async (req,res) => {
  const c=getContext(req); const scope=`onboardings|${String(req.query.status??'')}|${String(req.query.q??'')}`; const {limit,offset}=pageArgs(req,scope);
  let q=c.supabase.from('onboardings').select('id,workspace_id,customer_id,name,status,start_date,target_date,created_at,updated_at,version',{count:'exact'})
    .eq('workspace_id',c.workspaceId).order('updated_at',{ascending:false}).order('id',{ascending:true});
  if(typeof req.query.status==='string') q=q.eq('status',req.query.status);
  if(typeof req.query.q==='string') q=q.ilike('name',`%${req.query.q.slice(0,120)}%`);
  const {data,error,count}=await q.range(offset,offset+limit-1); if(error) safeError(error); res.json(pageWithCursor(data??[],count??0,limit,offset,scope,c));
}));

// 2. get_onboarding_details — explicit detail endpoint absent from the Agent 2 draft OpenAPI.
router.get('/onboardings/:onboardingId', asyncRoute(async(req,res)=>{
  const c=getContext(req);
  const {data,error}=await c.supabase.from('onboardings').select('id,workspace_id,customer_id,name,status,start_date,target_date,created_at,updated_at,version')
    .eq('workspace_id',c.workspaceId).eq('id',req.params.onboardingId).maybeSingle();
  if(error) safeError(error); if(!data) throw new ApiError(404,'RESOURCE_NOT_FOUND','Resource not found'); res.json({data,asOf:new Date().toISOString()});
}));

// 3. search_records — only allowlisted record types and approved structured columns.
router.get('/records/search', asyncRoute(async(req,res)=>{
  const c=getContext(req); const scope=`search|${String(req.query.query??'')}|${String(req.query.type??'')}|${String(req.query.onboardingId??'')}`; const {limit,offset}=pageArgs(req,scope);
  const query=String(req.query.query??'').trim().slice(0,120);
  if(!query) throw new ApiError(400,'VALIDATION_ERROR','query is required');
  const type=String(req.query.type??'');
  const tables: Record<string,string>={onboarding:'onboardings',event:'events',commitment:'commitments',task:'tasks',decision:'decisions',reference:'external_references'};
  const selected=type?[[type,tables[type]] as [string,string|undefined]]:Object.entries(tables);
  const results: Array<{type:string;id:string;onboardingId:string|null;title:string;status?:string}>=[];
  for(const [kind,table] of selected){
    if(!table) throw new ApiError(400,'VALIDATION_ERROR','Unsupported record type');
    if(kind==='onboarding') {
      const {data,error}=await c.supabase.from(table).select('id,name,status').eq('workspace_id',c.workspaceId).ilike('name',`%${query}%`).limit(100);
      if(error) safeError(error);
      for(const row of data??[]) results.push({type:kind,id:row.id,onboardingId:null,title:row.name,status:row.status});
    } else {
      let q=c.supabase.from(table).select('id,onboarding_id,title,status').eq('workspace_id',c.workspaceId).ilike('title',`%${query}%`).limit(100);
      if(typeof req.query.onboardingId==='string') q=q.eq('onboarding_id',req.query.onboardingId);
      const {data,error}=await q; if(error) safeError(error);
      for(const row of data??[]) results.push({type:kind,id:row.id,onboardingId:row.onboarding_id??null,title:row.title,status:row.status});
    }
  }
  results.sort((a,b)=>a.type.localeCompare(b.type)||a.id.localeCompare(b.id));
  res.json(pageWithCursor(results.slice(offset,offset+limit),results.length,limit,offset,scope,c));
}));

// 4. get_commitments — workspace-wide list, optional onboarding filter as in Agent 1.
router.get('/commitments', asyncRoute(async(req,res)=>res.json(await queryList(req,'commitments'))));
// 5. get_tasks — workspace-wide list, optional onboarding/status filter.
router.get('/tasks', asyncRoute(async(req,res)=>res.json(await queryList(req,'tasks'))));

// 6. get_overdue_items — workspace timezone logic is not guessed in this API increment.
router.get('/overdue-items', asyncRoute(async(req,res)=>{
  const c=getContext(req); const {limit,offset}=pageArgs(req,'overdue-items');
  const {data:ws,error:wsErr}=await c.supabase.from('workspaces').select('timezone').eq('id',c.workspaceId).maybeSingle();
  if(wsErr) safeError(wsErr); if(!ws) throw new ApiError(404,'RESOURCE_NOT_FOUND','Workspace not found');
  let localToday:string;
  try {
    const parts=new Intl.DateTimeFormat('en-CA',{timeZone:ws.timezone,year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date());
    const part=(type:string)=>parts.find(p=>p.type===type)?.value;
    localToday=`${part('year')}-${part('month')}-${part('day')}`;
    if(!/^\\d{4}-\\d{2}-\\d{2}$/.test(localToday)) throw new Error('bad date');
  } catch { throw new ApiError(500,'INVALID_WORKSPACE_TIMEZONE','Workspace timezone is invalid'); }
  const terminal=['Completed','Cancelled'];
  const [tasks,commitments]=await Promise.all([
    c.supabase.from('tasks').select('id,onboarding_id,title,status,due_date,priority').eq('workspace_id',c.workspaceId).lt('due_date',localToday).not('status','in',`(${terminal.join(',')})`).limit(Math.min(5000,offset+limit)),
    c.supabase.from('commitments').select('id,onboarding_id,title,status,due_date').eq('workspace_id',c.workspaceId).lt('due_date',localToday).not('status','in',`(${terminal.join(',')})`).limit(Math.min(5000,offset+limit))
  ]);
  if(tasks.error) safeError(tasks.error); if(commitments.error) safeError(commitments.error);
  const all=[...(tasks.data??[]).map(x=>({...x,recordType:'task'})),...(commitments.data??[]).map(x=>({...x,recordType:'commitment'}))]
    .sort((a,b)=>String(a.due_date).localeCompare(String(b.due_date))||String(a.id).localeCompare(String(b.id)));
  res.json({...pageWithCursor(all.slice(offset,offset+limit),all.length,limit,offset,'overdue-items',c),workspaceLocalDate:localToday});
}));

// 7. get_onboarding_summary — summary counts are computed from RLS-scoped records.
router.get('/onboardings/:onboardingId/summary', asyncRoute(async(req,res)=>{
  const c=getContext(req); const oid=req.params.onboardingId;
  const {data:onboarding,error:oErr}=await c.supabase.from('onboardings').select('id,status,version').eq('workspace_id',c.workspaceId).eq('id',oid).maybeSingle();
  if(oErr) safeError(oErr); if(!onboarding) throw new ApiError(404,'RESOURCE_NOT_FOUND','Resource not found');
  const [tasks,commitments]=await Promise.all([
    c.supabase.from('tasks').select('id,status,due_date').eq('workspace_id',c.workspaceId).eq('onboarding_id',oid),
    c.supabase.from('commitments').select('id,status,due_date').eq('workspace_id',c.workspaceId).eq('onboarding_id',oid)
  ]);
  if(tasks.error) safeError(tasks.error); if(commitments.error) safeError(commitments.error);
  const open=(x:{status:string})=>!['Completed','Cancelled'].includes(x.status);
  res.json({data:{onboardingId:oid,status:onboarding.status,version:onboarding.version,openTasks:(tasks.data??[]).filter(open).length,openCommitments:(commitments.data??[]).filter(open).length},asOf:new Date().toISOString()});
}));

// 8. get_activity_history — activity-specific result, never reuse generic record DTO.
router.get('/activity', asyncRoute(async(req,res)=>{
  const c=getContext(req); const scope=`activity|${String(req.query.onboardingId??'')}`; const {limit,offset}=pageArgs(req,scope);
  let q=c.supabase.from('audit_events').select('id,entity_type,entity_id,action,occurred_at,entity_version,source',{count:'exact'}).eq('workspace_id',c.workspaceId).order('occurred_at',{ascending:false}).order('id',{ascending:true});
  if(typeof req.query.onboardingId==='string') {
    const oid=req.query.onboardingId;
    const [onb,ev,cm,tk,dc,co,rf]=await Promise.all([
      c.supabase.from('onboardings').select('id').eq('workspace_id',c.workspaceId).eq('id',oid),
      c.supabase.from('events').select('id').eq('workspace_id',c.workspaceId).eq('onboarding_id',oid),
      c.supabase.from('commitments').select('id').eq('workspace_id',c.workspaceId).eq('onboarding_id',oid),
      c.supabase.from('tasks').select('id').eq('workspace_id',c.workspaceId).eq('onboarding_id',oid),
      c.supabase.from('decisions').select('id').eq('workspace_id',c.workspaceId).eq('onboarding_id',oid),
      c.supabase.from('comments').select('id').eq('workspace_id',c.workspaceId).eq('onboarding_id',oid),
      c.supabase.from('external_references').select('id').eq('workspace_id',c.workspaceId).eq('onboarding_id',oid)
    ]);
    for(const result of [onb,ev,cm,tk,dc,co,rf]) if(result.error) safeError(result.error);
    const ids=[...(onb.data??[]),...(ev.data??[]),...(cm.data??[]),...(tk.data??[]),...(dc.data??[]),...(co.data??[]),...(rf.data??[])].map(x=>x.id);
    if(ids.length===0) throw new ApiError(404,'RESOURCE_NOT_FOUND','Resource not found');
    q=q.in('entity_id',ids);
  }
  const {data,error,count}=await q.range(offset,offset+limit-1); if(error) safeError(error);
  res.json(pageWithCursor((data??[]).map(x=>({eventId:x.id,entityType:x.entity_type,entityId:x.entity_id,action:x.action,timestamp:x.occurred_at,summary:null,version:x.entity_version,source:x.source})),count??0,limit,offset,scope,c));
}));

// 9. submit_change_proposal — pending-only, durable idempotency in PostgreSQL.
router.post('/proposals', asyncRoute(async(req,res)=>{
  const c=getContext(req);
  // v0.6 CHANGE FROM v0.5: validate each proposal payload against the exact
  // SQL allowlist before invoking the transactional RPC.
  const parsed=proposalBodySchema.safeParse(req.body);
  if(!parsed.success) throw new ApiError(400,'VALIDATION_ERROR',parsed.error.issues.map(i=>`${i.path.join('.')}: ${i.message}`).join('; '));
  const idempotencyKey=req.header('idempotency-key');
  if(!idempotencyKey || idempotencyKey.length<16 || idempotencyKey.length>128) throw new ApiError(400,'INVALID_IDEMPOTENCY_KEY','Idempotency-Key header must be 16–128 characters');
  const {data,error}=await c.supabase.rpc('submit_change_proposal',{
    p_workspace_id:c.workspaceId,p_onboarding_id:parsed.data.onboardingId,p_kind:parsed.data.kind,
    p_operation:parsed.data.operation,p_target_record_id:parsed.data.targetRecordId??null,
    p_base_record_version:parsed.data.baseRecordVersion??null,p_payload:parsed.data.payload,
    p_idempotency_key:idempotencyKey
  });
  if(error) safeError(error);
  res.status(202).json({data,asOf:new Date().toISOString()});
}));

// Human-only approval endpoint. The SQL function performs the record write, proposal
// transition, history and audit append in one database transaction.
router.post('/proposals/:proposalId/approve', asyncRoute(async(req,res)=>{
  const c=getContext(req);
  if(!['admin','implementation_manager'].includes(c.role)) throw new ApiError(403,'APPROVAL_FORBIDDEN','Only authorized approvers can approve proposals');
  const expected=Number((req.header('if-match')??'').replace(/^\"|\"$/g,''));
  if(!Number.isInteger(expected)||expected<1) throw new ApiError(428,'IF_MATCH_REQUIRED','If-Match proposal version is required');
  const {data,error}=await c.supabase.rpc('approve_change_proposal',{
    p_workspace_id:c.workspaceId,p_proposal_id:req.params.proposalId,p_expected_proposal_version:expected
  });
  if(error) safeError(error);
  res.json({data,asOf:new Date().toISOString()});
}));

// Human approval queue; RLS returns proposer-owned and approver-visible proposals only.
router.get('/proposals', asyncRoute(async(req,res)=>{
  const c=getContext(req); const {limit}=pageArgs(req,'proposals');
  const {data,error}=await c.supabase.from('proposals')
    .select('id,target_onboarding_id,kind,operation,target_record_id,base_record_version,payload,status,proposer_user_id,submitted_at,expires_at,version')
    .eq('workspace_id',c.workspaceId).order('submitted_at',{ascending:false}).limit(limit);
  if(error) safeError(error);
  res.json({data:data??[],asOf:new Date().toISOString()});
}));

router.post('/proposals/:proposalId/reject', asyncRoute(async(req,res)=>{
  const c=getContext(req);
  if(!['admin','implementation_manager'].includes(c.role)) throw new ApiError(403,'APPROVAL_FORBIDDEN','Only authorized approvers can reject proposals');
  const expected=Number((req.header('if-match')??'').replace(/^\"|\"$/g,''));
  if(!Number.isInteger(expected)||expected<1) throw new ApiError(428,'IF_MATCH_REQUIRED','If-Match proposal version is required');
  const reason=typeof req.body?.reason==='string'?req.body.reason.slice(0,1000):'';
  const {data,error}=await c.supabase.rpc('reject_change_proposal',{
    p_workspace_id:c.workspaceId,p_proposal_id:req.params.proposalId,p_expected_proposal_version:expected,p_reason:reason
  });
  if(error) safeError(error);
  res.json({data,asOf:new Date().toISOString()});
}));
