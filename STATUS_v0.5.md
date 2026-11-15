# Backend API status v0.5

## Changes from v0.4
- Updated the older static contract test: it incorrectly expected proposal submission to remain a 501 placeholder. v0.4 already replaced that placeholder with PostgreSQL RPC-backed submission, approval and rejection; v0.5 aligns the test with the current implementation.
- Bumped package version to 0.5.0.
- Added this validation report and retained prior source comments/changelogs so agents can see what changed between versions.

## Validation actually performed in this environment
- `node tests/v0.4-static-checks.mjs`: PASS.
- `node tests/static-contract-checks.mjs`: PASS after correcting its stale v0.3 expectation.
- `npm install --no-audit --no-fund`: attempted, but timed out before completion; `node_modules` was not installed.
- `npm run typecheck` and `npm run build`: NOT RUN because dependencies were unavailable.
- PostgreSQL/Supabase migration execution: NOT RUN; no local `psql`, Docker or Podman executable was available.

## Important limitations
- Passing static text checks is not proof that TypeScript compiles or SQL executes.
- No live JWT, workspace isolation, RLS, proposal replay, concurrency, rollback or Agent 1 MCP integration tests have been run.
- Proposal payload is currently checked for top-level shape and database field allowlists; detailed per-field Zod schemas remain a follow-up.
- Human approval/rejection and proposal submission are implemented in source but remain unverified against a real PostgreSQL instance.
- No deployment, external account connection, or production credential was used.

## Required next gate
1. Run `npm ci` in a network-enabled local environment.
2. Run `npm run typecheck`, `npm run build`, and `npm run test:static`.
3. Apply migrations to a disposable PostgreSQL/Supabase project.
4. Test JWT identity, workspace isolation, Team Member vs Manager/Admin permissions, RLS, proposal idempotency replay/conflict, concurrent approvals, rollback, and audit consistency.
5. Only then connect the Agent 1 MCP adapter using verified delegated end-user identity. Never substitute shared credentials or mock identity headers.
