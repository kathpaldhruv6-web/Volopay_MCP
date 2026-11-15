# Copilot Prompt — Phase 2: Specification Review (NO APPLICATION CODE CHANGES)

You are reviewing the Volopay repository and the specification pack now present at its root.

## Absolute rules
1. This phase is READ-ONLY for application code.
2. Do not edit, create, delete, rename, format, or move any application/source/config/migration/test files.
3. Do not install packages or change dependencies.
4. Do not run migrations or connect to hosted/production databases.
5. Do not deploy or create external resources.
6. Do not make assumptions silently. Mark each as FACT, INFERENCE, PROPOSED, or OPEN QUESTION.
7. Preserve all pre-existing uncommitted changes. Do not reset, stash, checkout, clean, or overwrite anything.

## Read these files first
- `00_START_HERE.md`
- `PRODUCT_SPEC.md`
- `TECHNICAL_SPEC.md`
- `FEATURE_GAP_MATRIX.csv`
- `ACCEPTANCE_TESTS.md`
- `IMPLEMENTATION_PLAN.md`
- `DECISION_LOG.md`

Then inspect the actual repository source, migrations, tests, package scripts, and Git status.

## Your task
Produce a detailed specification compatibility review. Do not implement anything.

For every requirement in `PRODUCT_SPEC.md` and `TECHNICAL_SPEC.md`:
- Give requirement ID/name.
- State whether the current repository supports it: COMPLETE / PARTIAL / MISSING / CONFLICT / NOT VERIFIABLE.
- Cite exact file path, function, route, migration, and/or test.
- Explain actual current behavior, not intended behavior in comments.
- Identify security and data-integrity implications.
- State the smallest change needed, if any.
- Identify dependencies and regression risks.
- Propose test cases.

## Required report sections
A. Repository baseline: branch, commit, dirty worktree summary; do not modify it.
B. Specification items confirmed by source.
C. Conflicts between specification and current schema/API/tests.
D. P0 requirements for a credible end-to-end demo.
E. P1/P2 items that should be deferred.
F. Product decisions requiring owner approval.
G. Existing tests that genuinely verify each requirement.
H. Missing tests and exact suggested test names/cases.
I. Proposed implementation sequence with small independently reviewable steps.
J. Risks, unknowns, and any assignment requirements that cannot be verified.

## Special checks
- Investigate the known partial-update defect where API update schemas may omit `title` but SQL proposal RPC reportedly raises `TITLE_REQUIRED`.
- Check approval vs rejection expiry behavior.
- Check custom-field value type validation.
- Check whether all workspace and onboarding access checks are enforced in both API and RLS.
- Check whether cursors bind user, workspace, filters, and expiry.
- Check proposal idempotency, base-version concurrency, self-approval, and audit atomicity.
- Check whether there is any actual frontend or MCP implementation. Do not treat adapter notes as a working adapter.
- Check whether the original assignment brief is present. If absent, explicitly say assignment coverage cannot be definitively certified.

## Output format
Write the report in the Copilot Chat response only. Do not create or modify report files in this phase. End with:
`NO FILES CHANGED. Awaiting owner approval.`

Do not begin implementation after producing the report.
