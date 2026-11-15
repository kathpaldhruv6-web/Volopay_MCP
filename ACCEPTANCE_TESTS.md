# Acceptance Test Catalogue — Volopay

**Status:** Proposed acceptance criteria. Update these after reviewing the actual assignment brief.

## A. Authentication and tenant isolation (P0)

- [ ] A request without a valid bearer token is rejected.
- [ ] An expired/invalid token is rejected.
- [ ] An authenticated user without active membership in the requested workspace is denied.
- [ ] A user cannot read another workspace's onboarding by guessing its ID.
- [ ] A Team Member cannot access an onboarding they are not authorized to access.
- [ ] No service-role key or privileged secret is present in frontend bundles or MCP client configuration.

## B. Onboarding list and detail (P0)

- [ ] An authorized user can list onboardings in their workspace.
- [ ] Filters combine according to documented AND/OR semantics.
- [ ] Pagination does not duplicate or skip records in a stable dataset.
- [ ] Cursor reuse with a different user, workspace, or filter scope is rejected.
- [ ] Detail response includes only the fields and related records approved for that role.
- [ ] A record outside the user's scope is not disclosed.

## C. Tasks and commitments (P0)

- [ ] Task list shows owner, status, priority, due date, and onboarding relationship.
- [ ] Commitment list shows owner, due date, status, and description/party as approved.
- [ ] Overdue calculation uses the configured workspace/onboarding timezone.
- [ ] Terminal statuses are excluded from overdue counts according to the agreed policy.
- [ ] Invalid dates, statuses, IDs, or cross-onboarding relationships are rejected.
- [ ] A task dependency cannot point to itself, cross onboarding boundaries, or create a cycle.

## D. Proposals (P0)

- [ ] Each supported target type has a distinct create schema and update schema.
- [ ] A valid partial update may omit unchanged fields, including title when title is not being changed.
- [ ] Explicit null clears a field only if the field is nullable and clearable.
- [ ] An empty/no-op update is rejected.
- [ ] Update requires target ID and expected/base record version.
- [ ] Stale base version returns a stable conflict error and does not mutate the record.
- [ ] Same idempotency key + same request returns the original proposal result.
- [ ] Same idempotency key + different request returns a conflict.
- [ ] Proposal submission does not mutate the target operational record.
- [ ] MCP cannot approve/reject a proposal.

## E. Human approval and rejection (P0)

- [ ] Only authorized human roles can approve/reject.
- [ ] Proposer cannot approve their own proposal if the no-self-approval rule is adopted.
- [ ] Expired proposals cannot be approved or rejected according to one consistent lifecycle policy.
- [ ] Only pending proposals can be decided.
- [ ] Concurrent decisions cannot apply the same proposal twice.
- [ ] Approval checks the target version inside the transaction.
- [ ] Successful approval applies the record mutation, proposal status/history, and audit atomically.
- [ ] Rejection records reviewer, timestamp, and reason if required.
- [ ] Failed approval leaves the target record and proposal history unchanged.

## F. Activity and audit (P0)

- [ ] Every successful proposal decision creates an audit event.
- [ ] Audit event identifies actor, workspace, action, entity, timestamp, and request ID.
- [ ] Failed/unauthorized attempts do not leak sensitive values in logs.
- [ ] Ordinary users cannot edit or delete audit records.

## G. AI/MCP safety (P0 if agent integration is required)

- [ ] MCP read calls use verified delegated user identity.
- [ ] Caller-supplied user/workspace headers are never treated as authentication.
- [ ] Unclassified fields are excluded by default.
- [ ] Comments/free text are excluded unless explicitly reviewed and allowlisted.
- [ ] MCP write surface contains only `submit_change_proposal`.
- [ ] MCP tool errors use protocol error semantics.
- [ ] No direct MCP database access exists.

## H. Custom fields and notifications (P1)

- [ ] Custom-field value type matches the field definition.
- [ ] Custom-field entity type and workspace match the target record.
- [ ] Invalid or unknown field type fails closed.
- [ ] In-app notifications are scoped to the recipient and workspace.
- [ ] Retried event processing does not create duplicate notifications.

## I. Demo end-to-end scenario (P0)

Use synthetic customer data only.

1. [ ] Sign in as an authorized implementation user.
2. [ ] Open the onboarding portfolio.
3. [ ] Open a sample customer onboarding.
4. [ ] Identify one overdue commitment or blocked task and its owner.
5. [ ] Submit a proposed change to a task or commitment.
6. [ ] Confirm the original record has not changed while the proposal is pending.
7. [ ] Sign in/use an authorized reviewer and approve the proposal.
8. [ ] Confirm the record changed exactly once.
9. [ ] Confirm activity/audit history shows proposer, reviewer, action, and timestamp.
10. [ ] Demonstrate that an unauthorized user or agent cannot approve the proposal.

## Test reporting rule
Every test report must distinguish:
- Static/source checks.
- Unit tests.
- Disposable database contract tests.
- Hosted Supabase integration tests.
- MCP integration tests.
- Browser end-to-end tests.
- Manual demo checks.

Never label a static check as an end-to-end test.
