# Change log — v0.3

This is a new backend API service. It does not modify Agent 1 MCP source.

- Added `src/auth.ts`: replaces any mock-header identity assumption with Supabase JWT verification plus live membership lookup.
- Added `src/supabase.ts`: request-scoped client uses anon key and end-user bearer JWT; no service-role key.
- Added `src/routes.ts`: adds HTTP route surfaces corresponding to Agent 1's nine tool names.
- Added `src/errors.ts`: consistent HTTP error envelope; no success-shaped embedded errors.
- Added `src/config.ts`: validates required environment variables at startup.
- Added `src/pagination.ts`: rejects cursors until signed, user/workspace/filter-scoped cursor support is implemented.
- Overdue items returns 501 until workspace-timezone semantics are implemented.
- Proposal submission returns 501 until durable idempotency and transactional human approval are implemented.
