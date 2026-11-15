# Technical Specification — Volopay

**Version:** 1.0  
**Status:** Proposed; map against existing code before implementation

## 1. Architecture principles

1. Preserve the existing TypeScript/Express/Supabase foundation unless a concrete issue justifies a change.
2. Use PostgreSQL as the source of truth.
3. Authenticate users through Supabase Auth or the approved identity provider.
4. Authorize every request using verified identity, workspace membership, role, and onboarding access.
5. Use request-scoped Supabase clients with the end-user JWT and anon/publishable key for user-scoped operations.
6. Never expose a service-role key to frontend or MCP clients.
7. Keep MCP separate from the core API and use the API's authorization boundary.
8. Use transactions for proposal approval, record mutation, proposal history, and audit.
9. Prefer additive migrations; do not rewrite applied migrations.
10. Keep demo fixtures synthetic and isolated from production data.

## 2. Target component map

- **Web client (not currently present per assessment):** React/TypeScript or existing selected frontend framework. Calls backend API only.
- **Backend API (present):** Express/TypeScript service. Owns authentication context, authorization, validation, business rules, and database access.
- **Database (migrations present):** Supabase PostgreSQL. Owns relational integrity, RLS, and transactional proposal operations.
- **MCP adapter (not present per assessment):** Exposes approved read tools and one proposal-submission tool. It must forward/verify delegated end-user identity.
- **External tools:** Jira/spreadsheets/document links remain references; do not ingest unrestricted files in MVP.

## 3. API contract principles

- All routes require authenticated identity unless explicitly public for health checks.
- Workspace identifier in route/header is only a selector; backend must verify the authenticated user's active membership.
- Use consistent JSON envelopes and stable error codes.
- Validate request bodies with Zod (or the existing validation library).
- Use ISO 8601 timestamps with timezone offsets at API boundaries.
- Use UUID format for IDs if the database uses UUIDs.
- Paginated lists must use opaque, tamper-resistant cursors bound to user, workspace, filter scope, and expiry.
- Do not silently ignore unknown write fields.
- Use optimistic concurrency (`expected_version`/`base_record_version`) for updates.

## 4. Security and authorization

### Authentication
- Verify bearer tokens with the identity provider.
- Never accept `x-mock-user`, `x-mock-workspace`, or caller-supplied identity as proof of identity in non-test environments.
- Test identities must be enabled only in isolated test mode and impossible to enable accidentally in production.

### Workspace authorization
- Verify active membership for every request.
- Verify onboarding membership/access where applicable.
- Do not rely on frontend route hiding.
- Use RLS as defence in depth.
- Cross-tenant access attempts should return a safe not-found/forbidden response according to one consistent policy.

### Sensitive data
Default-deny fields not explicitly approved for AI or normal list responses. Never expose passwords, tokens, API keys, OAuth secrets, bank credentials, PAN/Aadhaar, salary/bank details, or raw HR documents.

### Audit
Capture actor ID, workspace ID, action, entity type/ID, timestamp, request/correlation ID, and safe change summary. Avoid logging secrets or unrestricted payloads.

## 5. Proposal contract

A proposal should contain:
- `id`
- `workspace_id` (derived/verified server-side, not trusted from the caller)
- `proposer_user_id` (derived from verified identity)
- `target_type`
- `operation` (`create` or `update`)
- `target_record_id` for updates
- typed `payload`
- `base_record_version` for updates
- `idempotency_key`
- `status` (`pending`, `approved`, `rejected`, plus any explicitly designed terminal states)
- `submitted_at`, `decided_at`, `decided_by`
- optional decision reason and expiry timestamp

Rules:
- Validate each target type with a separate schema.
- Create and update schemas must be distinct.
- Updates may omit unchanged fields; omitted fields mean unchanged.
- Explicit `null` means clear a nullable field only when the field allows clearing.
- Reject empty/no-op update payloads.
- Require target ID and base version for updates.
- Idempotency key must be durable and scoped to workspace + proposer; same key/same request returns original result, same key/different request returns conflict.
- Approval must re-check authorization, proposal status, expiry, and target version inside the transaction.
- Apply record change, proposal status/history, and audit atomically.
- Reject must enforce the same pending/expiry lifecycle policy as approve.
- No MCP approval or rejection tool.

## 6. MCP contract

### Read tools
- `list_onboardings`
- `get_onboarding_details`
- `search_records`
- `get_commitments`
- `get_tasks`
- `get_overdue_items`
- `get_onboarding_summary`
- `get_activity_history`

### Write tool
- `submit_change_proposal`

MCP requirements:
- No direct database access.
- No unrestricted file storage access.
- No service-role credential.
- Verify delegated end-user identity and workspace membership.
- If provider identity forwarding cannot be verified, do not enable live MCP writes; report the blocker.
- Explicit allowlist of fields per tool and record type.
- Do not expose comments or arbitrary free text unless separately reviewed and approved.
- Return MCP errors as errors, not success-shaped objects containing an error string.
- Pagination cursors must remain scoped to authenticated user/workspace and query filters.

## 7. Database requirements

- Every tenant-owned table has workspace scope directly or through a verified parent relationship.
- Foreign keys enforce parent/child integrity.
- Task dependencies cannot cross onboarding/workspace boundaries, self-reference, or form cycles.
- Comment must reference exactly one valid parent; parent must be in the same workspace/onboarding.
- Custom field values must match configured field type and entity type.
- RLS is enabled on tenant-owned tables.
- Direct writes are denied unless an explicitly authorized application path or RPC permits them.
- Security-definer functions must set a safe search path, validate caller context, and have least-privilege execute grants.
- Migrations must be additive and tested against a disposable database before use.

## 8. Testing layers

1. **Static checks:** source/contract invariants; useful but not proof of runtime correctness.
2. **Unit tests:** validation, cursor signing, date/time logic, error mapping, permission rules.
3. **Database contract tests:** migrations, RLS, triggers, RPC behavior, rollback and concurrency where practical.
4. **API integration tests:** real test database and identity provider test users.
5. **MCP contract tests:** schemas, auth context, error semantics, allowlist and proposal-only write.
6. **Browser E2E:** only after frontend exists; test the critical demo journey.
7. **Manual demo rehearsal:** fresh user/session and synthetic data.

## 9. Environment and cost controls

- Local/test configuration must be separate from hosted production configuration.
- Do not commit `.env` or credentials.
- `.env.example` contains names and safe placeholders only.
- Keep GitHub Codespaces spending/billing disabled or within the user's approved free allowance.
- Do not create paid Supabase resources or enable billing without explicit approval.
- Do not run destructive migrations against a shared/production database.
