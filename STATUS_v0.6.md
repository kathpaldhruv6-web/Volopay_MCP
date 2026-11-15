# v0.6 implementation status

## Completed in source
- Strict HTTP proposal schema per record kind and operation.
- Cross-field checks for create/update metadata and exactly-one comment parent.
- Database-side empty-payload guard.
- Explicit-null update semantics for nullable fields.
- Static tests for the schema-to-SQL guardrails.

## Verification
- Static tests: run `npm run test:static` after dependencies are installed.
- Dependency installation: attempted with `npm install --ignore-scripts --no-audit --no-fund`; timed out.
- TypeScript build/typecheck: not run (dependencies unavailable).
- PostgreSQL migrations: not executed (no local `psql` or Docker available).
- Live Supabase/JWT/RLS/concurrency tests: not run.

## Still required before production
- Install dependencies and run typecheck/build/Vitest or equivalent.
- Apply all migrations to a disposable Supabase/PostgreSQL project and inspect every SQL function.
- Integration-test each create/update payload, null-clearing, foreign parent IDs, workspace isolation, idempotent replay, self-approval and concurrent approval.
- Confirm delegated end-user identity from Agent 1/MCP to backend. Do not use shared service credentials or caller-supplied identity headers as a fallback.
