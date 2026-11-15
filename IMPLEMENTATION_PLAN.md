# Implementation Plan — Volopay

**Status:** Proposed sequencing; do not execute until specification review is approved.

## Stage 0 — Protect the current project
- Capture `git status`, current branch, and latest commit.
- Preserve all existing user modifications.
- Confirm current tests and exact SQL failure.
- Do not reset, clean, stash, or overwrite existing changes without owner approval.

**Exit:** Baseline is reproducible and current modifications are understood.

## Stage 1 — Resolve backend correctness defects
1. Fix partial-update API/SQL contract mismatch.
2. Align proposal expiry behavior for approve/reject.
3. Add custom-field value type validation if custom fields remain in MVP.
4. Rerun typecheck, static tests, disposable SQL suite.
5. Update status/report docs to reflect actual test outcomes.

**Exit:** All relevant tests pass; no claim of hosted verification.

## Stage 2 — Verify backend critical path
- Verify auth and workspace membership.
- Verify onboarding list/detail.
- Verify task/commitment reads.
- Verify proposal create/update, idempotency, stale version conflict.
- Verify approval/rejection and atomic audit.
- Use disposable test resources only.

**Exit:** Backend critical path has reproducible integration evidence.

## Stage 3 — Decide and build demo interface
- Confirm whether assignment requires a web UI, MCP server, or both.
- If UI is needed, design the smallest coherent experience:
  1. Sign-in/demo access.
  2. Onboarding portfolio.
  3. Onboarding detail.
  4. Task/commitment views.
  5. Proposal approval centre.
  6. Activity/audit panel.
- Reuse existing backend contracts; do not create mock-only screens that imply real persistence.

**Exit:** A reviewer can complete the demo journey end-to-end.

## Stage 4 — MCP integration (only if required)
- Obtain and inspect Agent 1 source.
- Map all eight read tools and proposal submission tool to backend API.
- Verify delegated user identity propagation.
- Test field allowlists and error semantics.
- Do not enable writes if identity forwarding is unresolved.

**Exit:** Agent can read approved data and submit proposals, but cannot approve.

## Stage 5 — Final hardening and submission
- Run all test layers that are feasible.
- Prepare synthetic demo data.
- Rehearse demo from a clean session.
- Prepare architecture diagram, product story, limitations, and roadmap.
- Make explicit which features are implemented, mocked, or unverified.

## Priority rule
If time is limited, prioritize a reliable end-to-end core journey over adding more entity types or advanced features.
