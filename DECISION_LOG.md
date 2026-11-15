# Product and Engineering Decision Log

Use this file to record decisions. Do not let Copilot silently decide product policy.

| ID | Decision | Proposed default | Status | Owner rationale |
|---|---|---|---|---|
| D-01 | Primary product scope | Shared onboarding operations register, complements Jira/spreadsheets | Proposed | Confirm against assignment |
| D-02 | Initial demo journey | Portfolio → onboarding detail → overdue item → proposal → human approval → audit | Proposed | Shows operational value and governance |
| D-03 | AI write permission | Agent may submit proposals only; cannot approve/reject | Proposed | Human-in-the-loop safety |
| D-04 | Self-approval | Proposer cannot approve own proposal | Proposed | Separation of duties |
| D-05 | AI free-text access | Deny comments and unreviewed free text by default | Proposed | Reduce sensitive-data exposure |
| D-06 | Direct writes | Only explicitly authorized human app flows; agent writes proposal only | Proposed | Preserve approval workflow |
| D-07 | Notifications | In-app first; email/push deferred | Proposed | Keep MVP small |
| D-08 | Search | Structured filters first; do not claim full-text search | Proposed | Avoid premature complexity |
| D-09 | Custom fields | Defer unless assignment needs them; enforce type correctness if enabled | Open | Confirm scope |
| D-10 | Frontend | Build minimal frontend only if assignment/demo requires it | Open | Current repo has no frontend |
| D-11 | MCP | Integrate only if assignment requires it and delegated auth can be verified | Open | Agent 1 source absent |
| D-12 | Status values | Must match schema and be documented per entity | Open | Avoid inconsistent states |
| D-13 | Workspace timezone | Use configured IANA timezone for overdue/date calculations | Proposed | Avoid UTC date errors |
| D-14 | Comments in AI context | Excluded initially | Proposed | Free-text safety |
