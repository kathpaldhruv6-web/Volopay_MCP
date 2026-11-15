# Backend API status v0.4

## Added
- HMAC-signed opaque pagination cursors bound to user, workspace, query scope and expiry.
- Workspace-local date calculation using the workspace IANA timezone for overdue commitments/tasks.
- Explicit safe field projections for task/commitment list routes (no `select *`).
- Search fixes for onboarding-specific column shapes and stable result ordering.
- Activity filtering resolves record IDs belonging to an onboarding before filtering audit rows.
- Durable proposal submission via PostgreSQL RPC, user+workspace idempotency key, request hash replay/conflict handling.
- Human-only proposal approval and rejection RPCs with row locks, version checks, self-approval denial, operational write, proposal history and audit in one transaction.
- HTTP routes for proposal queue, submission, approval and rejection.
- Common error mapping for authorization, conflict and validation failures.

## Still unverified / incomplete
- No npm dependency installation or TypeScript compilation has been run.
- No migration has been executed on PostgreSQL/Supabase; SQL syntax and function semantics remain unverified.
- No RLS/JWT/role integration test or proposal concurrency test has run.
- No production delegated-token integration with Agent 1 has been run.
- Search currently fetches a bounded candidate set per type before sorting/paging; not a scalable full-text search implementation.
- Overdue list currently fetches up to 5,000 candidates per entity type for offset paging; this needs a database-side union/view for scale.
- Proposal JSON field type/value validation is partly enforced by DB casts/constraints; further field-by-field Zod validation and lifecycle tests are required.
- Proposal rejection implemented; withdraw and expiry worker remain pending.
- Pagination uses signed offset cursors; records changing during paging can shift offsets. A keyset cursor is preferred before production for high-churn tables.
- `get_activity_history` uses entity ID expansion and needs database integration tests for each entity type.
- Approval audit uses a generated request ID inside SQL; propagate a true request ID in the next revision.
- Human API direct update/create/archive/member-management endpoints are not yet implemented.

## Required next validation
Run `npm install`, `npm run typecheck`, `npm run build`, and `npm run test:static`; then apply migrations to a disposable local Supabase instance and run RLS, proposal replay, conflict, concurrency and rollback tests. Do not deploy before these pass.

## Operational configuration
- `CURSOR_HMAC_SECRET` is required and must be a random secret of at least 32 characters. Generate/store it locally; do not send it in chat or commit it.
- `If-Match` may be sent as either `2` or the standard quoted value `"2"`.
- Proposal submission requires `Idempotency-Key` (16–128 characters).
