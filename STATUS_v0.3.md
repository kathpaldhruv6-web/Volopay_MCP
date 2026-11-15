# Backend API status v0.3

## Implemented in source
- Express HTTP service skeleton with health endpoint.
- Central environment validation.
- Bearer JWT validation through Supabase Auth `getUser`.
- Active workspace membership lookup on every authenticated request.
- Per-request Supabase client uses anon key + caller's bearer JWT so RLS can apply.
- Standard JSON error envelope and request IDs.
- Route surfaces for all nine MCP operations.
- Read implementations for onboarding list/detail, basic structured search, commitments, tasks, onboarding summary, and activity.
- Explicitly blocked overdue endpoint until workspace-local timezone calculation is implemented.
- Explicitly blocked proposal submission until durable idempotency, proposal RLS and atomic approval transaction exist.

## Important limitations
- No `npm install` or TypeScript build has been run in this environment.
- No PostgreSQL/Supabase migration has been executed.
- No live JWT, RLS, role, tenant isolation, or Agent 1 MCP integration tests have run.
- Pagination cursors are deliberately rejected until signed/scoped cursors are implemented.
- Search is basic structured title/name search, not full-text search.
- Summary currently counts open tasks and commitments; overdue counts are pending.
- Activity filtering is provisional and must be corrected to join entity-to-onboarding safely.
- Some query error handling is generic and needs production-hardening.
- The initial RLS migration's audit policy and helper functions require local Supabase validation.
- No proposal insert/update/approve/reject implementation yet.

## Run locally
1. Copy `.env.example` to `.env` and enter your own Supabase URL and anon key locally.
2. Install dependencies: `npm install`.
3. Typecheck: `npm run typecheck`.
4. Static checks: `npm run test:static`.
5. Start: `npm run dev`.

Do not deploy or use production data before SQL/RLS and integration tests pass.
