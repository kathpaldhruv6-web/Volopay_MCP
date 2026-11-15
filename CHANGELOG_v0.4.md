# Change log — v0.4

- `src/pagination.ts`: changed from rejecting all cursors to HMAC-signed cursors. Cursor binds user, workspace, scope and expiry; requires `CURSOR_HMAC_SECRET` (32+ chars).
- `src/routes.ts`: added timezone-aware overdue calculation; replaced `select *` on task/commitment lists with explicit safe columns; corrected onboarding-specific search projection; added proposal queue, submit, approve and reject routes.
- `20261115000300_proposal_transactions.sql`: added durable idempotent proposal submission, replay/conflict behavior, typed operation allowlists, transactional approval/rejection, row locking, optimistic version checks, self-approval prevention, approval history and audit writes.
- Agent 1 source remains unchanged. Existing tool names are still the integration target.
- Known limitations are recorded in `STATUS_v0.4.md`.
