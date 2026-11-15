# Agent 1 adapter notes — v0.3

Do not change Agent 1 MCP source in this package.

Expected transport:
- `Authorization: Bearer <delegated end-user Supabase access token>`
- `X-Workspace-Context: <active workspace UUID>` (backend currently accepts URL workspace selector; never expose it as a model-controlled tool argument)
- Call `/v1/workspaces/{workspaceId}/...`

Agent 1 must not send `x-mock-user` or `x-mock-workspace` to this service.
The backend currently does not accept mock identity headers.
The backend does not yet provide working signed cursor pagination, overdue items, or proposal submission. Do not point a production MCP server at it until those are complete and the live JWT/RLS integration suite passes.
