# v0.6 change log

- **Changed from v0.5:** proposal API no longer accepts arbitrary `z.record(z.unknown())` payloads. `src/proposal-validation.ts` now has strict per-kind and per-operation allowlists for events, commitments, tasks, decisions and comments.
- **Changed from v0.5:** update proposals must include a target record ID and base record version; create proposals cannot include update metadata; empty updates are rejected.
- **Changed from v0.5:** comment creation requires exactly one parent ID; task/commitment status, task priority, decision status, UUIDs, date-only values, timestamps and text lengths are validated before the RPC call.
- **Changed from v0.5:** SQL rejects empty JSON objects even if the RPC is called outside this HTTP API.
- **Changed from v0.5:** nullable update fields now distinguish omitted values (leave unchanged) from explicit JSON null (clear the value) for descriptions/details, owner, due date, external status, decision rationale and decided timestamp where applicable.
- Added a focused static guard suite for the above contracts.

## Validation limits

The dependency installation attempt timed out in this environment. Therefore TypeScript compilation, runtime Zod tests and PostgreSQL execution were not completed. Static source checks are not a substitute for those tests. No live credentials, database, deployment or paid service was used.
