-- Volopay v0.2: RLS, scoped helpers, and integrity constraints.
-- CHANGE FROM DRAFT: adds RLS enablement/policies, same-onboarding comment checks,
-- custom-field ownership/type checks, and task dependency same-onboarding/cycle checks.
-- Requires Supabase Auth and the schema migration immediately before this file.
-- Functions are SECURITY DEFINER only to read membership tables without RLS recursion.
begin;

create or replace function public.is_active_workspace_member(p_workspace_id uuid)
returns boolean
language sql stable security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from public.workspace_memberships wm
    where wm.workspace_id = p_workspace_id
      and wm.user_id = auth.uid()
      and wm.active = true
  );
$$;

create or replace function public.has_workspace_role(p_workspace_id uuid, p_roles public.workspace_role[])
returns boolean
language sql stable security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from public.workspace_memberships wm
    where wm.workspace_id = p_workspace_id
      and wm.user_id = auth.uid()
      and wm.active = true
      and wm.role = any(p_roles)
  );
$$;

create or replace function public.can_access_onboarding(p_workspace_id uuid, p_onboarding_id uuid)
returns boolean
language sql stable security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from public.onboardings o
    where o.workspace_id = p_workspace_id
      and o.id = p_onboarding_id
      and public.is_active_workspace_member(p_workspace_id)
      and (
        public.has_workspace_role(p_workspace_id, array['admin','implementation_manager']::public.workspace_role[])
        or exists (
          select 1 from public.onboarding_memberships om
          where om.workspace_id = p_workspace_id
            and om.onboarding_id = p_onboarding_id
            and om.user_id = auth.uid()
        )
      )
  );
$$;

revoke all on function public.is_active_workspace_member(uuid) from public;
revoke all on function public.has_workspace_role(uuid, public.workspace_role[]) from public;
revoke all on function public.can_access_onboarding(uuid, uuid) from public;
grant execute on function public.is_active_workspace_member(uuid) to authenticated;
grant execute on function public.has_workspace_role(uuid, public.workspace_role[]) to authenticated;
grant execute on function public.can_access_onboarding(uuid, uuid) to authenticated;

-- Enable RLS on every tenant table, including the workspace root.
alter table public.workspaces enable row level security;
alter table public.user_profiles enable row level security;
alter table public.workspace_memberships enable row level security;
alter table public.customers enable row level security;
alter table public.onboardings enable row level security;
alter table public.onboarding_memberships enable row level security;
alter table public.events enable row level security;
alter table public.commitments enable row level security;
alter table public.tasks enable row level security;
alter table public.task_dependencies enable row level security;
alter table public.decisions enable row level security;
alter table public.comments enable row level security;
alter table public.external_references enable row level security;
alter table public.custom_field_definitions enable row level security;
alter table public.custom_field_values enable row level security;
alter table public.proposals enable row level security;
alter table public.proposal_approval_history enable row level security;
alter table public.audit_events enable row level security;
alter table public.in_app_notifications enable row level security;

-- Workspace and identity records.
create policy workspaces_select_member on public.workspaces
for select to authenticated using (public.is_active_workspace_member(id));

create policy profiles_select_self_or_colleague on public.user_profiles
for select to authenticated using (
  user_id = auth.uid()
  or exists (
    select 1 from public.workspace_memberships mine
    join public.workspace_memberships theirs on theirs.workspace_id = mine.workspace_id
    where mine.user_id = auth.uid() and mine.active
      and theirs.user_id = user_profiles.user_id and theirs.active
  )
);
create policy profiles_update_self on public.user_profiles
for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy workspace_memberships_select_scoped on public.workspace_memberships
for select to authenticated using (
  (user_id = auth.uid() and active)
  or public.has_workspace_role(workspace_id, array['admin','implementation_manager']::public.workspace_role[])
);
-- Membership/role changes are intentionally not exposed as generic table writes.
-- They must go through a reviewed backend transaction/RPC with last-admin protection.

create policy customers_select_scoped on public.customers
for select to authenticated using (
  public.has_workspace_role(workspace_id, array['admin','implementation_manager']::public.workspace_role[])
  or exists (
    select 1 from public.onboardings o
    where o.workspace_id = customers.workspace_id
      and o.customer_id = customers.id
      and public.can_access_onboarding(o.workspace_id,o.id)
  )
);
create policy onboardings_select_scoped on public.onboardings
for select to authenticated using (public.can_access_onboarding(workspace_id,id));

create policy onboarding_memberships_select_scoped on public.onboarding_memberships
for select to authenticated using (
  user_id = auth.uid()
  or public.has_workspace_role(workspace_id, array['admin','implementation_manager']::public.workspace_role[])
  or public.can_access_onboarding(workspace_id,onboarding_id)
);

-- Operational tables: scoped to onboarding access.
create policy events_select_scoped on public.events
for select to authenticated using (public.can_access_onboarding(workspace_id,onboarding_id));
create policy commitments_select_scoped on public.commitments
for select to authenticated using (public.can_access_onboarding(workspace_id,onboarding_id));
create policy tasks_select_scoped on public.tasks
for select to authenticated using (public.can_access_onboarding(workspace_id,onboarding_id));
create policy task_dependencies_select_scoped on public.task_dependencies
for select to authenticated using (
  exists (select 1 from public.tasks t
    where t.workspace_id = task_dependencies.workspace_id
      and t.id = task_dependencies.task_id
      and public.can_access_onboarding(t.workspace_id,t.onboarding_id))
);
create policy decisions_select_scoped on public.decisions
for select to authenticated using (public.can_access_onboarding(workspace_id,onboarding_id));
create policy comments_select_scoped on public.comments
for select to authenticated using (public.can_access_onboarding(workspace_id,onboarding_id));
create policy external_references_select_scoped on public.external_references
for select to authenticated using (public.can_access_onboarding(workspace_id,onboarding_id));

create policy custom_field_definitions_select_scoped on public.custom_field_definitions
for select to authenticated using (
  public.is_active_workspace_member(workspace_id)
  and (active or public.has_workspace_role(workspace_id,array['admin']::public.workspace_role[]))
);
create policy custom_field_values_select_scoped on public.custom_field_values
for select to authenticated using (
  case entity_type
    when 'onboarding' then public.can_access_onboarding(workspace_id,entity_id)
    when 'event' then exists(select 1 from public.events x where x.workspace_id=custom_field_values.workspace_id and x.id=custom_field_values.entity_id and public.can_access_onboarding(x.workspace_id,x.onboarding_id))
    when 'commitment' then exists(select 1 from public.commitments x where x.workspace_id=custom_field_values.workspace_id and x.id=custom_field_values.entity_id and public.can_access_onboarding(x.workspace_id,x.onboarding_id))
    when 'task' then exists(select 1 from public.tasks x where x.workspace_id=custom_field_values.workspace_id and x.id=custom_field_values.entity_id and public.can_access_onboarding(x.workspace_id,x.onboarding_id))
    when 'decision' then exists(select 1 from public.decisions x where x.workspace_id=custom_field_values.workspace_id and x.id=custom_field_values.entity_id and public.can_access_onboarding(x.workspace_id,x.onboarding_id))
    else false
  end
);

-- Proposal visibility: proposer sees own; approvers see workspace queue; onboarding access always required.
create policy proposals_select_scoped on public.proposals
for select to authenticated using (
  public.can_access_onboarding(workspace_id,target_onboarding_id)
  and (proposer_user_id = auth.uid()
    or public.has_workspace_role(workspace_id,array['admin','implementation_manager']::public.workspace_role[]))
);
create policy proposal_history_select_scoped on public.proposal_approval_history
for select to authenticated using (
  exists(select 1 from public.proposals p
    where p.workspace_id=proposal_approval_history.workspace_id
      and p.id=proposal_approval_history.proposal_id
      and public.can_access_onboarding(p.workspace_id,p.target_onboarding_id)
      and (p.proposer_user_id=auth.uid()
        or public.has_workspace_role(p.workspace_id,array['admin','implementation_manager']::public.workspace_role[])))
);
create policy audit_events_select_scoped on public.audit_events
for select to authenticated using (
  public.has_workspace_role(workspace_id,array['admin','implementation_manager']::public.workspace_role[])
  or (public.is_active_workspace_member(workspace_id)
      and exists (
        select 1 from public.onboardings o
        where o.workspace_id=audit_events.workspace_id and o.id=audit_events.entity_id
          and public.can_access_onboarding(o.workspace_id,o.id)
      ))
);
create policy notifications_select_self on public.in_app_notifications
for select to authenticated using (
  recipient_user_id=auth.uid() and public.is_active_workspace_member(workspace_id)
);
create policy notifications_update_self on public.in_app_notifications
for update to authenticated using (
  recipient_user_id=auth.uid() and public.is_active_workspace_member(workspace_id)
) with check (
  recipient_user_id=auth.uid() and public.is_active_workspace_member(workspace_id)
);

-- No broad INSERT/UPDATE/DELETE policies are granted here. Backend business services
-- and narrowly scoped RPCs will be added in a later stage after transactional rules
-- and actor attribution have tests. RLS therefore fails closed for direct writes.

-- Validate custom-field definition/entity agreement and same-workspace entity ownership.
create or replace function public.validate_custom_field_value()
returns trigger language plpgsql security definer
set search_path = public
as $$
declare
  v_entity_type text;
  v_exists boolean := false;
begin
  select d.entity_type into v_entity_type
  from public.custom_field_definitions d
  where d.workspace_id = new.workspace_id
    and d.id = new.definition_id
    and d.active = true;
  if v_entity_type is null or v_entity_type <> new.entity_type then
    raise exception 'CUSTOM_FIELD_DEFINITION_ENTITY_MISMATCH' using errcode='23514';
  end if;

  if new.entity_type='onboarding' then
    select exists(select 1 from public.onboardings x where x.workspace_id=new.workspace_id and x.id=new.entity_id) into v_exists;
  elsif new.entity_type='event' then
    select exists(select 1 from public.events x where x.workspace_id=new.workspace_id and x.id=new.entity_id) into v_exists;
  elsif new.entity_type='commitment' then
    select exists(select 1 from public.commitments x where x.workspace_id=new.workspace_id and x.id=new.entity_id) into v_exists;
  elsif new.entity_type='task' then
    select exists(select 1 from public.tasks x where x.workspace_id=new.workspace_id and x.id=new.entity_id) into v_exists;
  elsif new.entity_type='decision' then
    select exists(select 1 from public.decisions x where x.workspace_id=new.workspace_id and x.id=new.entity_id) into v_exists;
  end if;
  if not v_exists then
    raise exception 'CUSTOM_FIELD_ENTITY_NOT_FOUND' using errcode='23503';
  end if;

  if (new.value_text is not null)::int
     + (new.value_number is not null)::int
     + (new.value_date is not null)::int
     + (new.value_boolean is not null)::int
     + (new.value_json is not null)::int <> 1 then
    raise exception 'CUSTOM_FIELD_VALUE_CARDINALITY' using errcode='23514';
  end if;
  return new;
end;
$$;
create trigger custom_field_value_integrity
before insert or update on public.custom_field_values
for each row execute function public.validate_custom_field_value();

-- Ensure comments' parent belongs to the same onboarding, not just the same workspace.
create or replace function public.validate_comment_parent_onboarding()
returns trigger language plpgsql security definer
set search_path = public
as $$
declare v_parent_onboarding uuid;
begin
  if new.event_id is not null then
    select onboarding_id into v_parent_onboarding from public.events where workspace_id=new.workspace_id and id=new.event_id;
  elsif new.commitment_id is not null then
    select onboarding_id into v_parent_onboarding from public.commitments where workspace_id=new.workspace_id and id=new.commitment_id;
  elsif new.task_id is not null then
    select onboarding_id into v_parent_onboarding from public.tasks where workspace_id=new.workspace_id and id=new.task_id;
  elsif new.decision_id is not null then
    select onboarding_id into v_parent_onboarding from public.decisions where workspace_id=new.workspace_id and id=new.decision_id;
  end if;
  if v_parent_onboarding is null or v_parent_onboarding <> new.onboarding_id then
    raise exception 'COMMENT_PARENT_ONBOARDING_MISMATCH' using errcode='23514';
  end if;
  return new;
end;
$$;
create trigger comment_parent_onboarding_integrity
before insert or update on public.comments
for each row execute function public.validate_comment_parent_onboarding();

-- Dependencies must connect tasks in the same onboarding and remain acyclic.
create or replace function public.validate_task_dependency()
returns trigger language plpgsql security definer
set search_path = public
as $$
declare v_onboarding_a uuid; v_onboarding_b uuid; v_cycle boolean;
begin
  select onboarding_id into v_onboarding_a from public.tasks
    where workspace_id=new.workspace_id and id=new.task_id;
  select onboarding_id into v_onboarding_b from public.tasks
    where workspace_id=new.workspace_id and id=new.depends_on_task_id;
  if v_onboarding_a is null or v_onboarding_b is null or v_onboarding_a <> v_onboarding_b then
    raise exception 'TASK_DEPENDENCY_CROSS_ONBOARDING' using errcode='23514';
  end if;
  with recursive reachable(id) as (
    select new.depends_on_task_id
    union
    select td.depends_on_task_id
    from public.task_dependencies td
    join reachable r on td.task_id=r.id
    where td.workspace_id=new.workspace_id
  )
  select exists(select 1 from reachable where id=new.task_id) into v_cycle;
  if v_cycle then
    raise exception 'TASK_DEPENDENCY_CYCLE' using errcode='23514';
  end if;
  return new;
end;
$$;
create trigger task_dependency_integrity
before insert or update on public.task_dependencies
for each row execute function public.validate_task_dependency();

-- Actor IDs on custom-field rows must be workspace members, not merely global profiles.
alter table public.custom_field_definitions
  add constraint custom_field_definitions_created_member_fk
  foreign key(workspace_id,created_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict;
alter table public.custom_field_definitions
  add constraint custom_field_definitions_updated_member_fk
  foreign key(workspace_id,updated_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict;
alter table public.custom_field_values
  add constraint custom_field_values_created_member_fk
  foreign key(workspace_id,created_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict;
alter table public.custom_field_values
  add constraint custom_field_values_updated_member_fk
  foreign key(workspace_id,updated_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict;

commit;
