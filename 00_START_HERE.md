# Volopay — Specification Pack v1.0

## What this pack is
This is a GitHub-ready product and engineering specification pack for the Volopay onboarding operations register. It is designed to be added to the **root of the existing repository** and used by GitHub Copilot in Codespaces.

It does not contain application code and does not authorize Copilot to change application code. Its first purpose is to make the current project and the desired product agree on a precise, testable target.

## Important scope note
The current-state assessment reported that the repository contains a backend foundation but no frontend or Agent 1 MCP server. It also reported that the original assignment brief was not found in the repository. Therefore:
- This pack describes the proposed target product based on the project context and inspected repository.
- It labels decisions that need confirmation as `PROPOSED` or `OPEN`.
- It does not claim that every item is an original assignment requirement.
- Before final submission, compare this pack with the actual assignment brief and adjust scope accordingly.

## Add these files
Copy the files in this folder into the repository root, preserving their names:
- `PRODUCT_SPEC.md`
- `TECHNICAL_SPEC.md`
- `FEATURE_GAP_MATRIX.csv`
- `ACCEPTANCE_TESTS.md`
- `IMPLEMENTATION_PLAN.md`
- `COPILOT_PHASE_2_SPEC_REVIEW_PROMPT.md`
- `COPILOT_PHASE_3_IMPLEMENTATION_PROMPT.md`
- `DECISION_LOG.md`

Do not overwrite existing source files. If a file with the same name already exists, keep a backup or ask before replacing it.

## Recommended sequence
1. Add this pack to the GitHub repository.
2. Open Copilot Chat in Codespaces.
3. Paste the entire contents of `COPILOT_PHASE_2_SPEC_REVIEW_PROMPT.md`.
4. Ask Copilot to review the specification against the current repository **without changing application code**.
5. Read its report and resolve open decisions.
6. Only after you approve the specification, use `COPILOT_PHASE_3_IMPLEMENTATION_PROMPT.md` for one small implementation stage at a time.

## Rules for Copilot
- Do not rewrite the project or replace its architecture.
- Do not create a frontend, MCP server, database migration, or endpoint merely because it appears in the target specification. First identify the exact gap and dependencies.
- Preserve working code and existing user changes.
- Never use a Supabase service-role key in browser code or as a shortcut.
- Never ask the owner to paste secrets into chat.
- Do not deploy, create paid resources, enable billing, or change hosted data without explicit approval.
- If a requirement conflicts with the current implementation, explain the conflict and propose the smallest safe change.
