-- Volopay v0.4: durable proposal submission and transactional human approval.
-- CHANGE FROM v0.3: replaces the 501 proposal placeholder with DB transactions.
-- SECURITY: actor is always auth.uid(); caller cannot supply proposer/approver identity.
begin;

create or replace function public.submit_change_proposal(
  p_workspace_id uuid,
  p_onboarding_id uuid,
  p_kind public.proposal_kind,
  p_operation public.proposal_operation,
  p_target_record_id uuid,
  p_base_record_version integer,
  p_payload jsonb,
  p_idempotency_key text
) returns public.proposals
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_actor uuid := auth.uid();
  v_role public.workspace_role;
  v_hash text;
  v_existing public.proposals;
  v_result public.proposals;
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
  if length(coalesce(p_idempotency_key,'')) < 16 or length(p_idempotency_key)>128 then
    raise exception 'INVALID_IDEMPOTENCY_KEY' using errcode='22023';
  end if;
  -- v0.6 CHANGE FROM v0.5: reject empty/non-object payloads at the database boundary too;
  -- API Zod validation is defense in depth, not the only enforcement layer.
  if jsonb_typeof(p_payload) <> 'object' or jsonb_object_length(p_payload)=0 then
    raise exception 'INVALID_PROPOSAL_PAYLOAD' using errcode='22023';
  end if;

  select role into v_role from public.workspace_memberships
    where workspace_id=p_workspace_id and user_id=v_actor and active=true;
  if v_role is null then raise exception 'WORKSPACE_ACCESS_DENIED' using errcode='42501'; end if;

  if not public.can_access_onboarding(p_workspace_id,p_onboarding_id) then
    raise exception 'ONBOARDING_ACCESS_DENIED' using errcode='42501';
  end if;

  if (p_operation='create' and (p_target_record_id is not null or p_base_record_version is not null))
     or (p_operation='update' and (p_target_record_id is null or p_base_record_version is null or p_base_record_version<1)) then
    raise exception 'INVALID_PROPOSAL_OPERATION' using errcode='22023';
  end if;

  -- Strict field allowlists prevent arbitrary JSON from becoming database writes.
  if p_kind='event' and exists(select 1 from jsonb_object_keys(p_payload) k where k not in ('title','eventType','description','occurredAt')) then
    raise exception 'UNKNOWN_PROPOSAL_FIELD' using errcode='22023';
  elsif p_kind='commitment' and exists(select 1 from jsonb_object_keys(p_payload) k where k not in ('title','description','ownerUserId','status','dueDate','externalStatus')) then
    raise exception 'UNKNOWN_PROPOSAL_FIELD' using errcode='22023';
  elsif p_kind='task' and exists(select 1 from jsonb_object_keys(p_payload) k where k not in ('title','details','ownerUserId','status','priority','dueDate','externalStatus')) then
    raise exception 'UNKNOWN_PROPOSAL_FIELD' using errcode='22023';
  elsif p_kind='decision' and exists(select 1 from jsonb_object_keys(p_payload) k where k not in ('title','rationale','decisionStatus','decidedAt')) then
    raise exception 'UNKNOWN_PROPOSAL_FIELD' using errcode='22023';
  elsif p_kind='comment' and exists(select 1 from jsonb_object_keys(p_payload) k where k not in ('body','eventId','commitmentId','taskId','decisionId')) then
    raise exception 'UNKNOWN_PROPOSAL_FIELD' using errcode='22023';
  end if;

  if not (p_payload ? 'title' OR p_kind='comment') then raise exception 'TITLE_REQUIRED' using errcode='22023'; end if;
  if p_kind='comment' and p_operation='create' and
     (not (p_payload ? 'body') or num_nonnulls(p_payload->>'eventId',p_payload->>'commitmentId',p_payload->>'taskId',p_payload->>'decisionId')<>1) then
    raise exception 'INVALID_COMMENT_PARENT' using errcode='22023';
  end if;
  if p_kind in ('commitment','task') and nullif(p_payload->>'ownerUserId','') is not null
     and not exists(select 1 from public.workspace_memberships wm
       where wm.workspace_id=p_workspace_id and wm.user_id=(p_payload->>'ownerUserId')::uuid and wm.active=true) then
    raise exception 'INVALID_RECORD_OWNER' using errcode='22023';
  end if;
  v_hash := encode(digest(p_workspace_id::text||p_onboarding_id::text||p_kind::text||p_operation::text||
                    coalesce(p_target_record_id::text,'')||coalesce(p_base_record_version::text,'')||p_payload::text,'sha256'),'hex');

  select * into v_existing from public.proposals
    where workspace_id=p_workspace_id and proposer_user_id=v_actor and idempotency_key=p_idempotency_key;
  if found then
    if v_existing.request_hash <> v_hash then raise exception 'IDEMPOTENCY_CONFLICT' using errcode='23505'; end if;
    return v_existing;
  end if;

  if p_operation='update' then
    -- Confirm target belongs to requested onboarding and current version at submission.
    if p_kind='event' and not exists(select 1 from public.events where workspace_id=p_workspace_id and onboarding_id=p_onboarding_id and id=p_target_record_id and version=p_base_record_version) then raise exception 'RECORD_VERSION_CONFLICT' using errcode='40001';
    elsif p_kind='commitment' and not exists(select 1 from public.commitments where workspace_id=p_workspace_id and onboarding_id=p_onboarding_id and id=p_target_record_id and version=p_base_record_version) then raise exception 'RECORD_VERSION_CONFLICT' using errcode='40001';
    elsif p_kind='task' and not exists(select 1 from public.tasks where workspace_id=p_workspace_id and onboarding_id=p_onboarding_id and id=p_target_record_id and version=p_base_record_version) then raise exception 'RECORD_VERSION_CONFLICT' using errcode='40001';
    elsif p_kind='decision' and not exists(select 1 from public.decisions where workspace_id=p_workspace_id and onboarding_id=p_onboarding_id and id=p_target_record_id and version=p_base_record_version) then raise exception 'RECORD_VERSION_CONFLICT' using errcode='40001';
    elsif p_kind='comment' and not exists(select 1 from public.comments where workspace_id=p_workspace_id and onboarding_id=p_onboarding_id and id=p_target_record_id and version=p_base_record_version) then raise exception 'RECORD_VERSION_CONFLICT' using errcode='40001';
    end if;
  end if;

  insert into public.proposals(workspace_id,target_onboarding_id,kind,operation,target_record_id,base_record_version,payload,
      proposer_user_id,idempotency_key,request_hash,expires_at)
  values(p_workspace_id,p_onboarding_id,p_kind,p_operation,p_target_record_id,p_base_record_version,p_payload,
      v_actor,p_idempotency_key,v_hash,now()+interval '7 days')
  on conflict (workspace_id,proposer_user_id,idempotency_key) do nothing
  returning * into v_result;

  -- Concurrent retry: unique constraint serializes the key; replay only if the normalized
  -- request hash matches. Do not create duplicate pending proposals.
  if v_result.id is null then
    select * into v_existing from public.proposals
      where workspace_id=p_workspace_id and proposer_user_id=v_actor and idempotency_key=p_idempotency_key;
    if v_existing.request_hash <> v_hash then raise exception 'IDEMPOTENCY_CONFLICT' using errcode='23505'; end if;
    return v_existing;
  end if;

  insert into public.proposal_approval_history(workspace_id,proposal_id,actor_user_id,action,to_status,proposal_version,safe_diff)
  values(p_workspace_id,v_result.id,v_actor,'submitted','PENDING',v_result.version,
      jsonb_build_object('kind',p_kind,'operation',p_operation,'fields',(select coalesce(jsonb_agg(k),'[]'::jsonb) from jsonb_object_keys(p_payload) as k)));
  return v_result;
end;
$$;

create or replace function public.approve_change_proposal(
  p_workspace_id uuid,
  p_proposal_id uuid,
  p_expected_proposal_version integer
) returns public.proposals
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_actor uuid := auth.uid();
  v_role public.workspace_role;
  v_proposal public.proposals;
  v_record_id uuid;
  v_new_version integer;
  v_audit_entity text;
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
  select role into v_role from public.workspace_memberships
    where workspace_id=p_workspace_id and user_id=v_actor and active=true;
  if v_role is null or v_role not in ('admin','implementation_manager') then raise exception 'APPROVAL_FORBIDDEN' using errcode='42501'; end if;

  select * into v_proposal from public.proposals
    where workspace_id=p_workspace_id and id=p_proposal_id for update;
  if not found then raise exception 'RESOURCE_NOT_FOUND' using errcode='P0002'; end if;
  if v_proposal.proposer_user_id=v_actor then raise exception 'SELF_APPROVAL_FORBIDDEN' using errcode='42501'; end if;
  if v_proposal.status <> 'PENDING' or v_proposal.expires_at <= now() then raise exception 'PROPOSAL_NOT_PENDING' using errcode='55000'; end if;
  if v_proposal.version <> p_expected_proposal_version then raise exception 'PROPOSAL_VERSION_CONFLICT' using errcode='40001'; end if;
  if not public.can_access_onboarding(p_workspace_id,v_proposal.target_onboarding_id) then raise exception 'ONBOARDING_ACCESS_DENIED' using errcode='42501'; end if;

  if v_proposal.operation='create' then
    if v_proposal.kind='event' then
      insert into public.events(workspace_id,onboarding_id,title,event_type,description,occurred_at,created_by,updated_by)
      values(p_workspace_id,v_proposal.target_onboarding_id,v_proposal.payload->>'title',coalesce(v_proposal.payload->>'eventType','general'),
        v_proposal.payload->>'description',coalesce((v_proposal.payload->>'occurredAt')::timestamptz,now()),v_actor,v_actor) returning id,version into v_record_id,v_new_version;
    elsif v_proposal.kind='commitment' then
      insert into public.commitments(workspace_id,onboarding_id,title,description,owner_user_id,status,due_date,external_status,created_by,updated_by)
      values(p_workspace_id,v_proposal.target_onboarding_id,v_proposal.payload->>'title',v_proposal.payload->>'description',
        nullif(v_proposal.payload->>'ownerUserId','')::uuid,coalesce((v_proposal.payload->>'status')::public.item_status,'Open'),
        nullif(v_proposal.payload->>'dueDate','')::date,v_proposal.payload->>'externalStatus',v_actor,v_actor) returning id,version into v_record_id,v_new_version;
    elsif v_proposal.kind='task' then
      insert into public.tasks(workspace_id,onboarding_id,title,details,owner_user_id,status,priority,due_date,external_status,created_by,updated_by)
      values(p_workspace_id,v_proposal.target_onboarding_id,v_proposal.payload->>'title',v_proposal.payload->>'details',
        nullif(v_proposal.payload->>'ownerUserId','')::uuid,coalesce((v_proposal.payload->>'status')::public.item_status,'Open'),
        coalesce(v_proposal.payload->>'priority','Normal'),nullif(v_proposal.payload->>'dueDate','')::date,
        v_proposal.payload->>'externalStatus',v_actor,v_actor) returning id,version into v_record_id,v_new_version;
    elsif v_proposal.kind='decision' then
      insert into public.decisions(workspace_id,onboarding_id,title,rationale,decision_status,decided_at,created_by,updated_by)
      values(p_workspace_id,v_proposal.target_onboarding_id,v_proposal.payload->>'title',v_proposal.payload->>'rationale',
        coalesce(v_proposal.payload->>'decisionStatus','Proposed'),nullif(v_proposal.payload->>'decidedAt','')::timestamptz,v_actor,v_actor)
        returning id,version into v_record_id,v_new_version;
    elsif v_proposal.kind='comment' then
      insert into public.comments(workspace_id,onboarding_id,event_id,commitment_id,task_id,decision_id,body,created_by,updated_by)
      values(p_workspace_id,v_proposal.target_onboarding_id,
        nullif(v_proposal.payload->>'eventId','')::uuid,nullif(v_proposal.payload->>'commitmentId','')::uuid,
        nullif(v_proposal.payload->>'taskId','')::uuid,nullif(v_proposal.payload->>'decisionId','')::uuid,
        v_proposal.payload->>'body',v_actor,v_actor) returning id,version into v_record_id,v_new_version;
    end if;
  else
    -- v0.6 CHANGE FROM v0.5: nullable columns now distinguish an omitted key
    -- (leave unchanged) from an explicit JSON null (clear the stored value).
    if v_proposal.kind='event' then
      update public.events set title=coalesce(v_proposal.payload->>'title',title),event_type=coalesce(v_proposal.payload->>'eventType',event_type),
        description=case when v_proposal.payload ? 'description' then v_proposal.payload->>'description' else description end,occurred_at=case when v_proposal.payload ? 'occurredAt' then (v_proposal.payload->>'occurredAt')::timestamptz else occurred_at end,
        updated_at=now(),updated_by=v_actor,version=version+1
      where workspace_id=p_workspace_id and onboarding_id=v_proposal.target_onboarding_id and id=v_proposal.target_record_id and version=v_proposal.base_record_version
      returning id,version into v_record_id,v_new_version;
    elsif v_proposal.kind='commitment' then
      update public.commitments set title=coalesce(v_proposal.payload->>'title',title),description=case when v_proposal.payload ? 'description' then v_proposal.payload->>'description' else description end,
        status=coalesce((v_proposal.payload->>'status')::public.item_status,status),due_date=case when v_proposal.payload ? 'dueDate' then nullif(v_proposal.payload->>'dueDate','')::date else due_date end,
        owner_user_id=case when v_proposal.payload ? 'ownerUserId' then nullif(v_proposal.payload->>'ownerUserId','')::uuid else owner_user_id end,external_status=case when v_proposal.payload ? 'externalStatus' then v_proposal.payload->>'externalStatus' else external_status end,
        updated_at=now(),updated_by=v_actor,version=version+1
      where workspace_id=p_workspace_id and onboarding_id=v_proposal.target_onboarding_id and id=v_proposal.target_record_id and version=v_proposal.base_record_version
      returning id,version into v_record_id,v_new_version;
    elsif v_proposal.kind='task' then
      update public.tasks set title=coalesce(v_proposal.payload->>'title',title),details=case when v_proposal.payload ? 'details' then v_proposal.payload->>'details' else details end,
        status=coalesce((v_proposal.payload->>'status')::public.item_status,status),priority=coalesce(v_proposal.payload->>'priority',priority),
        due_date=case when v_proposal.payload ? 'dueDate' then nullif(v_proposal.payload->>'dueDate','')::date else due_date end,
        owner_user_id=case when v_proposal.payload ? 'ownerUserId' then nullif(v_proposal.payload->>'ownerUserId','')::uuid else owner_user_id end,
        external_status=case when v_proposal.payload ? 'externalStatus' then v_proposal.payload->>'externalStatus' else external_status end,updated_at=now(),updated_by=v_actor,version=version+1
      where workspace_id=p_workspace_id and onboarding_id=v_proposal.target_onboarding_id and id=v_proposal.target_record_id and version=v_proposal.base_record_version
      returning id,version into v_record_id,v_new_version;
    elsif v_proposal.kind='decision' then
      update public.decisions set title=coalesce(v_proposal.payload->>'title',title),rationale=case when v_proposal.payload ? 'rationale' then v_proposal.payload->>'rationale' else rationale end,
        decision_status=coalesce(v_proposal.payload->>'decisionStatus',decision_status),decided_at=case when v_proposal.payload ? 'decidedAt' then nullif(v_proposal.payload->>'decidedAt','')::timestamptz else decided_at end,
        updated_at=now(),updated_by=v_actor,version=version+1
      where workspace_id=p_workspace_id and onboarding_id=v_proposal.target_onboarding_id and id=v_proposal.target_record_id and version=v_proposal.base_record_version
      returning id,version into v_record_id,v_new_version;
    elsif v_proposal.kind='comment' then
      update public.comments set body=coalesce(v_proposal.payload->>'body',body),updated_at=now(),updated_by=v_actor,version=version+1
      where workspace_id=p_workspace_id and onboarding_id=v_proposal.target_onboarding_id and id=v_proposal.target_record_id and version=v_proposal.base_record_version
      returning id,version into v_record_id,v_new_version;
    end if;
  end if;

  if v_record_id is null then raise exception 'RECORD_VERSION_CONFLICT' using errcode='40001'; end if;

  update public.proposals set status='APPROVED',updated_at=now(),version=version+1
    where workspace_id=p_workspace_id and id=p_proposal_id returning * into v_proposal;
  insert into public.proposal_approval_history(workspace_id,proposal_id,actor_user_id,action,from_status,to_status,proposal_version,safe_diff)
  values(p_workspace_id,p_proposal_id,v_actor,'approved','PENDING','APPROVED',v_proposal.version,
    jsonb_build_object('recordId',v_record_id,'recordVersion',v_new_version));
  v_audit_entity := v_proposal.kind::text;
  insert into public.audit_events(workspace_id,actor_user_id,action,entity_type,entity_id,request_id,source,entity_version)
  values(p_workspace_id,v_actor,'proposal_approved',v_audit_entity,v_record_id,gen_random_uuid(),'mcp_approved',v_new_version);
  return v_proposal;
end;
$$;


create or replace function public.reject_change_proposal(
  p_workspace_id uuid,
  p_proposal_id uuid,
  p_expected_proposal_version integer,
  p_reason text
) returns public.proposals
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_actor uuid := auth.uid();
  v_role public.workspace_role;
  v_proposal public.proposals;
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
  select role into v_role from public.workspace_memberships
    where workspace_id=p_workspace_id and user_id=v_actor and active=true;
  if v_role is null or v_role not in ('admin','implementation_manager') then
    raise exception 'APPROVAL_FORBIDDEN' using errcode='42501';
  end if;
  select * into v_proposal from public.proposals
    where workspace_id=p_workspace_id and id=p_proposal_id for update;
  if not found then raise exception 'RESOURCE_NOT_FOUND' using errcode='P0002'; end if;
  if v_proposal.proposer_user_id=v_actor then raise exception 'SELF_APPROVAL_FORBIDDEN' using errcode='42501'; end if;
  if v_proposal.status <> 'PENDING' then raise exception 'PROPOSAL_NOT_PENDING' using errcode='55000'; end if;
  if v_proposal.version <> p_expected_proposal_version then raise exception 'PROPOSAL_VERSION_CONFLICT' using errcode='40001'; end if;
  update public.proposals set status='REJECTED',updated_at=now(),version=version+1
    where workspace_id=p_workspace_id and id=p_proposal_id returning * into v_proposal;
  insert into public.proposal_approval_history(workspace_id,proposal_id,actor_user_id,action,from_status,to_status,reason,proposal_version)
    values(p_workspace_id,p_proposal_id,v_actor,'rejected','PENDING','REJECTED',left(coalesce(p_reason,''),1000),v_proposal.version);
  insert into public.audit_events(workspace_id,actor_user_id,action,entity_type,entity_id,request_id,source,entity_version)
    values(p_workspace_id,v_actor,'proposal_rejected','proposal',p_proposal_id,gen_random_uuid(),'human',v_proposal.version);
  return v_proposal;
end;
$$;

revoke all on function public.submit_change_proposal(uuid,uuid,public.proposal_kind,public.proposal_operation,uuid,integer,jsonb,text) from public;
revoke all on function public.approve_change_proposal(uuid,uuid,integer) from public;
revoke all on function public.reject_change_proposal(uuid,uuid,integer,text) from public;
grant execute on function public.submit_change_proposal(uuid,uuid,public.proposal_kind,public.proposal_operation,uuid,integer,jsonb,text) to authenticated;
grant execute on function public.approve_change_proposal(uuid,uuid,integer) to authenticated;
grant execute on function public.reject_change_proposal(uuid,uuid,integer,text) to authenticated;

commit;
