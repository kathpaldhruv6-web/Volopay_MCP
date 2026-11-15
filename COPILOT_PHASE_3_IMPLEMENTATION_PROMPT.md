# Copilot Prompt — Phase 3: Implement One Approved Change at a Time

Use this prompt only AFTER the owner has reviewed and approved the Phase 2 specification review and the specific implementation task.

## Approved task
[OWNER: Replace this line with ONE specific approved task and its requirement IDs.]

## Rules
1. Implement only the approved task. Do not opportunistically refactor unrelated code.
2. Before editing, show:
   - current files that will change;
   - proposed files to add;
   - migration impact;
   - API contract impact;
   - security/authorization impact;
   - tests to add/update;
   - rollback strategy.
3. Wait for explicit owner approval before applying a database migration, changing hosted resources, deploying, or performing destructive actions.
4. Preserve all existing uncommitted work. Never reset, stash, clean, or overwrite unrelated changes.
5. Never place secrets in source code, chat, logs, or frontend bundles.
6. Never use a service-role key as a shortcut for user-scoped operations.
7. Do not claim a test passed unless you ran it and can show the command and result.
8. Distinguish static checks from unit, database, integration, MCP, and browser E2E tests.
9. If the implementation requires an unapproved product decision, stop and ask one focused question.
10. Keep changes small and explain every changed file.

## Required workflow
### Step 1 — Plan
Inspect the exact code paths and produce a short change plan. Do not edit yet.

### Step 2 — Approval
Wait for owner approval of the plan.

### Step 3 — Implement
Make only the approved changes. Use additive migrations. Do not modify applied migration history; add a new migration if needed.

### Step 4 — Verify
Run relevant tests and report:
- exact commands;
- pass/fail counts;
- skipped tests;
- environment limitations;
- files changed;
- remaining risks.

### Step 5 — Review
Show a concise diff summary and explain how to manually verify the change.

Stop after this one task. Do not start the next task until the owner approves it.
