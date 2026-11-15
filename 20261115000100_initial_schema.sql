-- Volopay v0.2 database foundation. Derived from Agent 2 draft schema in supplied handoff.
-- CHANGE FROM SOURCE: promoted Agent 2 draft schema into a versioned migration; no table semantics
-- were silently rewritten in this import. Review follow-up migration for security/integrity additions.
-- Review before applying to any shared/production project. This migration has NOT been run against Supabase.
-- Volopay contract v1.0.0-draft; PostgreSQL 15+ / Supabase-compatible primitives.
-- Apply via reviewed migrations, not manually to production. All fixtures must be synthetic.
create extension if not exists pgcrypto;
create type public.workspace_role as enum ('admin','implementation_manager','team_member');
create type public.onboarding_status as enum ('Draft','Active','On Hold','Completed','Archived');
create type public.item_status as enum ('Draft','Open','In Progress','Blocked','Completed','Cancelled','On Hold');
create type public.proposal_status as enum ('PENDING','NEEDS_REVIEW','APPROVED','REJECTED','EXPIRED','INVALID','WITHDRAWN');
create type public.proposal_kind as enum ('event','commitment','task','decision','comment');
create type public.proposal_operation as enum ('create','update');
create type public.custom_field_type as enum ('text','number','date','boolean','single_select');

create table public.workspaces (
  id uuid primary key default gen_random_uuid(), name text not null check (length(trim(name)) between 1 and 160),
  timezone text not null default 'UTC', created_at timestamptz not null default now(), updated_at timestamptz not null default now(), version int not null default 1 check(version > 0)
);
-- Supabase auth.users is the identity source; no password is copied here.
create table public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete restrict,
  display_name text not null check(length(trim(display_name)) between 1 and 160), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.workspace_memberships (
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  user_id uuid not null references public.user_profiles(user_id) on delete restrict,
  role public.workspace_role not null, active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), version int not null default 1 check(version > 0),
  primary key(workspace_id,user_id)
);
create index workspace_memberships_user_active on public.workspace_memberships(user_id,active,workspace_id);
create table public.customers (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete restrict,
  display_name text not null check(length(trim(display_name)) between 1 and 200), created_at timestamptz not null default now(), created_by uuid not null references public.user_profiles(user_id),
  updated_at timestamptz not null default now(), updated_by uuid not null references public.user_profiles(user_id), version int not null default 1 check(version > 0),
  unique(workspace_id,id)
);
create table public.onboardings (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete restrict,
  customer_id uuid not null, name text not null check(length(trim(name)) between 1 and 200), owner_user_id uuid not null,
  status public.onboarding_status not null default 'Draft', start_date date, target_date date, description text,
  created_at timestamptz not null default now(), created_by uuid not null, updated_at timestamptz not null default now(), updated_by uuid not null,
  archived_at timestamptz, version int not null default 1 check(version > 0),
  unique(workspace_id,id),
  foreign key(workspace_id,customer_id) references public.customers(workspace_id,id) on delete restrict,
  foreign key(workspace_id,owner_user_id) references public.workspace_memberships(workspace_id,user_id) on delete restrict,
  foreign key(workspace_id,created_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict,
  foreign key(workspace_id,updated_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict,
  check((status='Archived') = (archived_at is not null))
);
create index onboardings_workspace_status_updated on public.onboardings(workspace_id,status,updated_at desc,id);
create index onboardings_workspace_customer on public.onboardings(workspace_id,customer_id);
create table public.onboarding_memberships (
  workspace_id uuid not null, onboarding_id uuid not null, user_id uuid not null, access_level text not null default 'member' check(access_level in ('owner','member')),
  created_at timestamptz not null default now(), created_by uuid not null,
  primary key(workspace_id,onboarding_id,user_id),
  foreign key(workspace_id,onboarding_id) references public.onboardings(workspace_id,id) on delete restrict,
  foreign key(workspace_id,user_id) references public.workspace_memberships(workspace_id,user_id) on delete restrict,
  foreign key(workspace_id,created_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict
);
create index onboarding_memberships_user on public.onboarding_memberships(workspace_id,user_id,onboarding_id);

create table public.events (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null, onboarding_id uuid not null,
  title text not null check(length(trim(title)) between 1 and 240), event_type text not null check(length(event_type) between 1 and 80),
  description text, occurred_at timestamptz not null, created_at timestamptz not null default now(), created_by uuid not null,
  updated_at timestamptz not null default now(), updated_by uuid not null, version int not null default 1 check(version>0),
  unique(workspace_id,id), foreign key(workspace_id,onboarding_id) references public.onboardings(workspace_id,id) on delete restrict,
  foreign key(workspace_id,created_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict,
  foreign key(workspace_id,updated_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict
);
create index events_onboarding_time on public.events(workspace_id,onboarding_id,occurred_at desc);
create table public.commitments (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null, onboarding_id uuid not null,
  title text not null check(length(trim(title)) between 1 and 240), description text, owner_user_id uuid,
  status public.item_status not null default 'Open', due_date date, external_status text,
  created_at timestamptz not null default now(), created_by uuid not null, updated_at timestamptz not null default now(), updated_by uuid not null, version int not null default 1 check(version>0),
  unique(workspace_id,id), foreign key(workspace_id,onboarding_id) references public.onboardings(workspace_id,id) on delete restrict,
  foreign key(workspace_id,owner_user_id) references public.workspace_memberships(workspace_id,user_id) on delete restrict,
  foreign key(workspace_id,created_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict,
  foreign key(workspace_id,updated_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict
);
create index commitments_due_status on public.commitments(workspace_id,due_date,status,onboarding_id);
create table public.tasks (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null, onboarding_id uuid not null,
  title text not null check(length(trim(title)) between 1 and 240), details text, owner_user_id uuid,
  status public.item_status not null default 'Open', priority text not null default 'Normal' check(priority in ('Low','Normal','High','Urgent')),
  due_date date, external_status text, created_at timestamptz not null default now(), created_by uuid not null,
  updated_at timestamptz not null default now(), updated_by uuid not null, version int not null default 1 check(version>0),
  unique(workspace_id,id), foreign key(workspace_id,onboarding_id) references public.onboardings(workspace_id,id) on delete restrict,
  foreign key(workspace_id,owner_user_id) references public.workspace_memberships(workspace_id,user_id) on delete restrict,
  foreign key(workspace_id,created_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict,
  foreign key(workspace_id,updated_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict
);
create index tasks_due_status on public.tasks(workspace_id,due_date,status,onboarding_id);
create table public.task_dependencies (
  workspace_id uuid not null, task_id uuid not null, depends_on_task_id uuid not null,
  created_at timestamptz not null default now(), created_by uuid not null,
  primary key(workspace_id,task_id,depends_on_task_id), check(task_id <> depends_on_task_id),
  foreign key(workspace_id,task_id) references public.tasks(workspace_id,id) on delete restrict,
  foreign key(workspace_id,depends_on_task_id) references public.tasks(workspace_id,id) on delete restrict,
  foreign key(workspace_id,created_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict
);
create table public.decisions (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null, onboarding_id uuid not null,
  title text not null check(length(trim(title)) between 1 and 240), rationale text, decision_status text not null default 'Proposed' check(decision_status in ('Proposed','Decided','Superseded')),
  decided_at timestamptz, created_at timestamptz not null default now(), created_by uuid not null,
  updated_at timestamptz not null default now(), updated_by uuid not null, version int not null default 1 check(version>0),
  unique(workspace_id,id), foreign key(workspace_id,onboarding_id) references public.onboardings(workspace_id,id) on delete restrict,
  foreign key(workspace_id,created_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict,
  foreign key(workspace_id,updated_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict
);
create table public.comments (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null, onboarding_id uuid not null,
  event_id uuid, commitment_id uuid, task_id uuid, decision_id uuid,
  body text not null check(length(trim(body)) between 1 and 10000), created_at timestamptz not null default now(), created_by uuid not null,
  updated_at timestamptz not null default now(), updated_by uuid not null, version int not null default 1 check(version>0),
  unique(workspace_id,id), check(num_nonnulls(event_id,commitment_id,task_id,decision_id)=1),
  foreign key(workspace_id,onboarding_id) references public.onboardings(workspace_id,id) on delete restrict,
  foreign key(workspace_id,event_id) references public.events(workspace_id,id) on delete restrict,
  foreign key(workspace_id,commitment_id) references public.commitments(workspace_id,id) on delete restrict,
  foreign key(workspace_id,task_id) references public.tasks(workspace_id,id) on delete restrict,
  foreign key(workspace_id,decision_id) references public.decisions(workspace_id,id) on delete restrict,
  foreign key(workspace_id,created_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict,
  foreign key(workspace_id,updated_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict
);
create index comments_parent on public.comments(workspace_id,onboarding_id,event_id,commitment_id,task_id,decision_id);
create table public.external_references (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null, onboarding_id uuid not null,
  title text not null check(length(trim(title)) between 1 and 240), url text not null check(length(url)<=2048),
  source_type text not null check(length(source_type) between 1 and 80), verification_status text not null default 'unverified' check(verification_status in ('unverified','verified','stale','broken')),
  last_verified_at timestamptz, verified_by uuid, created_at timestamptz not null default now(), created_by uuid not null,
  updated_at timestamptz not null default now(), updated_by uuid not null, version int not null default 1 check(version>0),
  unique(workspace_id,id), foreign key(workspace_id,onboarding_id) references public.onboardings(workspace_id,id) on delete restrict,
  foreign key(workspace_id,verified_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict,
  foreign key(workspace_id,created_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict,
  foreign key(workspace_id,updated_by) references public.workspace_memberships(workspace_id,user_id) on delete restrict,
  check((verification_status='verified') = (last_verified_at is not null))
);
create table public.custom_field_definitions (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete restrict,
  entity_type text not null check(entity_type in ('onboarding','event','commitment','task','decision')),
  field_key text not null check(field_key ~ '^[a-z][a-z0-9_]{0,62}$'), label text not null check(length(trim(label)) between 1 and 100),
  field_type public.custom_field_type not null, required boolean not null default false, options jsonb,
  ai_policy text not null default 'AI_BLOCKED' check(ai_policy in ('AI_ALLOWED','AI_REDACT','AI_BLOCKED')),
  active boolean not null default true, created_at timestamptz not null default now(), created_by uuid not null references public.user_profiles(user_id),
  updated_at timestamptz not null default now(), updated_by uuid not null references public.user_profiles(user_id), version int not null default 1 check(version>0),
  unique(workspace_id,id), unique(workspace_id,entity_type,field_key),
  check((field_type='single_select' and jsonb_typeof(options)='array') or (field_type<>'single_select'))
);
create table public.custom_field_values (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null, definition_id uuid not null,
  entity_type text not null check(entity_type in ('onboarding','event','commitment','task','decision')), entity_id uuid not null,
  value_text text, value_number numeric, value_date date, value_boolean boolean, value_json jsonb,
  created_at timestamptz not null default now(), created_by uuid not null references public.user_profiles(user_id),
  updated_at timestamptz not null default now(), updated_by uuid not null references public.user_profiles(user_id), version int not null default 1 check(version>0),
  unique(workspace_id,definition_id,entity_type,entity_id),
  foreign key(workspace_id,definition_id) references public.custom_field_definitions(workspace_id,id) on delete restrict,
  check(num_nonnulls(value_text,value_number,value_date,value_boolean,value_json)=1)
);
create index custom_field_values_entity on public.custom_field_values(workspace_id,entity_type,entity_id);
-- Application transaction validates entity_id belongs to workspace and entity_type matches definition;
-- PostgreSQL polymorphic FK cannot express this without per-type child tables/triggers.

create table public.proposals (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null, target_onboarding_id uuid not null,
  kind public.proposal_kind not null, operation public.proposal_operation not null, target_record_id uuid,
  base_record_version int, payload jsonb not null check(jsonb_typeof(payload)='object'),
  status public.proposal_status not null default 'PENDING', proposer_user_id uuid not null,
  idempotency_key text not null check(length(idempotency_key) between 16 and 128), request_hash text not null,
  source text not null default 'mcp' check(source='mcp'), validation_json jsonb not null default '{"valid":true,"warnings":[]}'::jsonb,
  submitted_at timestamptz not null default now(), expires_at timestamptz not null, updated_at timestamptz not null default now(), version int not null default 1 check(version>0),
  unique(workspace_id,id), unique(workspace_id,proposer_user_id,idempotency_key),
  foreign key(workspace_id,target_onboarding_id) references public.onboardings(workspace_id,id) on delete restrict,
  foreign key(workspace_id,proposer_user_id) references public.workspace_memberships(workspace_id,user_id) on delete restrict,
  check((operation='create' and target_record_id is null and base_record_version is null) or
        (operation='update' and target_record_id is not null and base_record_version is not null and base_record_version>0))
);
create index proposals_queue on public.proposals(workspace_id,status,submitted_at desc);
create index proposals_expiry on public.proposals(status,expires_at) where status='PENDING';
create table public.proposal_approval_history (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null, proposal_id uuid not null,
  actor_user_id uuid not null, action text not null check(action in ('submitted','edited','approved','rejected','expired','conflict','withdrawn','revalidated','invalid')),
  from_status public.proposal_status, to_status public.proposal_status, reason text, occurred_at timestamptz not null default now(),
  proposal_version int not null check(proposal_version>0), safe_diff jsonb,
  foreign key(workspace_id,proposal_id) references public.proposals(workspace_id,id) on delete restrict,
  foreign key(workspace_id,actor_user_id) references public.workspace_memberships(workspace_id,user_id) on delete restrict
);
create index proposal_history_chronological on public.proposal_approval_history(workspace_id,proposal_id,occurred_at);
create table public.audit_events (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete restrict,
  actor_user_id uuid not null, action text not null, entity_type text not null, entity_id uuid not null,
  occurred_at timestamptz not null default now(), request_id uuid not null, source text not null check(source in ('human','mcp_approved','system')),
  before_values jsonb, after_values jsonb, entity_version int,
  foreign key(workspace_id,actor_user_id) references public.workspace_memberships(workspace_id,user_id) on delete restrict
);
create index audit_workspace_time on public.audit_events(workspace_id,occurred_at desc,id);
create index audit_entity_time on public.audit_events(workspace_id,entity_type,entity_id,occurred_at desc);
create table public.in_app_notifications (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null, recipient_user_id uuid not null,
  notification_type text not null, entity_type text, entity_id uuid, safe_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), read_at timestamptz,
  foreign key(workspace_id,recipient_user_id) references public.workspace_memberships(workspace_id,user_id) on delete restrict
);
create index notifications_inbox on public.in_app_notifications(workspace_id,recipient_user_id,read_at,created_at desc);

-- Production implementation requirements not fully represented by DDL:
-- 1. Enable RLS on every table; create narrowly scoped membership/role policies and test them.
-- 2. Browser writes use verified auth.uid(); never trust caller-supplied actor IDs.
-- 3. Revoke direct MCP DB access; MCP uses backend API, never service-role writes.
-- 4. Use transaction functions/business services for audit + write atomicity and proposal approval.
-- 5. Prevent UPDATE/DELETE of audit_events and approval history through app roles; privileged owner remains technically able.
-- 6. Validate comment parent belongs to same onboarding; validate custom field entity polymorphic ownership/type.
-- 7. Validate URL scheme/domain and scrub sensitive query components server-side.
-- 8. Define cascade/archive and membership-removal handling in migration/business logic; default FK behavior is restrictive.
