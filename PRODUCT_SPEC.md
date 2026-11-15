# Product Specification — Volopay Onboarding Operations Register

**Version:** 1.0  
**Status:** Proposed target specification; requires owner review  
**Product type:** Internal B2B workflow application  
**Primary users:** Customer implementation/onboarding teams

## 1. Product summary

Volopay is a shared operational register for managing customer onboarding. It gives implementation teams one structured place to understand onboarding progress, important events, commitments, tasks, dependencies, decisions, comments, and changes requiring human approval.

It complements systems such as Jira, spreadsheets, email, and document repositories. It is not intended to replace those systems or become a general-purpose project-management suite.

## 2. Problem to solve

Onboarding work is often spread across multiple tools and conversations. Teams can lose track of:
- What has happened with a customer onboarding.
- Which commitments were made, by whom, and by when.
- Which tasks are blocked and what they depend on.
- Which decisions were made and why.
- What changed, who changed it, and whether the change was approved.
- What needs attention today.

The product should provide a trustworthy operational view and a controlled change process.

## 3. Product goals

1. Give implementation teams a reliable, workspace-scoped register of onboarding work.
2. Make progress, ownership, deadlines, blockers, and decisions visible.
3. Preserve an auditable history of important changes.
4. Support safe AI-agent assistance through read-only tools and proposal-only writes.
5. Keep humans in control of operational changes.
6. Make the core workflow understandable in a short product demo.

## 4. Non-goals

- Replacing Jira, CRM, email, chat, or document management.
- Processing payments or handling financial transactions.
- Storing sensitive employee or customer credentials.
- Allowing an AI agent to approve its own proposed changes.
- Giving an AI agent unrestricted database or file access.
- Building a complex workflow automation platform in the first release.

## 5. Users and roles

### Admin
- Manage workspace membership and roles.
- View all onboarding records in the workspace.
- Configure workspace-level settings where supported.
- Review and decide proposals.
- View audit/activity information.

### Implementation Manager
- View and coordinate onboarding work in the workspace.
- Create and update operational records through supported app workflows.
- Assign owners and monitor overdue or blocked work.
- Review and decide proposals if the authorization policy permits it.

### Team Member
- View onboardings they are authorized to access.
- View related tasks, commitments, events, and decisions.
- Update only records and fields allowed by the permission policy.
- Submit proposals where direct mutation is not permitted.

**Authorization principle:** UI visibility is not security. Every protected operation must be authorized by the backend and enforced by database policies where applicable.

## 6. Core domain objects

- **Workspace:** Tenant boundary for users and onboarding data.
- **Workspace membership:** User-to-workspace relationship and role.
- **Customer onboarding:** A customer implementation record with status, owner, dates, and metadata.
- **Event:** A dated milestone or meaningful onboarding occurrence.
- **Commitment:** A promise/action agreed with a person or organization, with owner, due date, and status.
- **Task:** Work item with owner, status, priority, due date, and optional dependencies.
- **Task dependency:** Directed relationship indicating one task must wait for another.
- **Decision:** A recorded decision with context, outcome, and decision date/owner.
- **Comment:** Discussion attached to exactly one supported parent record.
- **Custom field definition/value:** Workspace-configured extension fields, subject to type validation.
- **Proposal:** A requested create/update operation awaiting a human decision.
- **Proposal history:** Durable record of submission and decision lifecycle.
- **Activity/audit event:** Append-only record of meaningful actions.
- **Notification:** In-app signal that an authorized user needs to know about an event.

The existing database schema is the starting point. Copilot must map these concepts to actual table names and identify discrepancies rather than assuming names.

## 7. Primary workflows

### 7.1 Find and open an onboarding
1. User signs in.
2. Backend verifies identity and active workspace membership.
3. User sees only onboarding records permitted by their role and membership.
4. User filters/searches by customer, status, owner, or relevant dates.
5. User opens an onboarding detail view.
6. Detail view presents status, owner, dates, key events, commitments, tasks, decisions, recent activity, and blockers.

### 7.2 Track commitments and tasks
1. Authorized user opens an onboarding.
2. User reviews commitments and tasks.
3. User can identify owner, status, due date, and overdue/blocked state.
4. User opens a task to inspect dependencies.
5. A task cannot be marked ready/completed if business rules explicitly require unresolved dependencies to be completed first. The precise allowed status transition must be documented before enforcement.

### 7.3 Record an event or decision
1. Authorized user chooses the record type.
2. User supplies required fields.
3. Backend validates workspace/onboarding relationship and field constraints.
4. Record is created or updated.
5. Activity/audit history records the actor, action, target, timestamp, and relevant safe change summary.

### 7.4 AI-agent change proposal
1. An authenticated, delegated user asks an AI agent to make a change.
2. MCP server verifies the delegated user identity; it must not trust caller-supplied user/workspace headers.
3. Agent reads only approved AI-safe projections.
4. Agent submits a typed proposal with target, operation, payload, idempotency key, and expected version where applicable.
5. Backend validates permission, schema, scope, and record version.
6. Proposal is stored as pending; no operational record is changed yet.
7. Authorized human opens the approval centre and reviews the proposed change.
8. Human approves or rejects.
9. Approval transaction checks pending state, expiry, permission, self-approval policy, and version; then applies the change and writes proposal history and audit atomically.
10. User sees the outcome.

### 7.5 Audit and activity
Users with permission can inspect who did what and when. Audit entries must be append-only from normal application paths. Do not expose secrets or sensitive personal data in audit payloads.

## 8. Functional requirements

### FR-01 Workspace isolation
All workspace-owned records must be scoped to the authenticated user's active workspace and authorized membership. Cross-workspace identifiers must not disclose whether a record exists.

### FR-02 Onboarding list
Provide a paginated list of authorized onboardings with documented filters, stable ordering, and a detail route.

### FR-03 Onboarding detail
Provide a single detail response/view with related records and clearly defined safe projections.

### FR-04 Operational records
Support the agreed create/update/read lifecycle for events, commitments, tasks, decisions, and comments. The initial release may implement these through proposal workflows where appropriate; do not add direct mutation routes without an explicit permission decision.

### FR-05 Tasks and dependencies
Validate that dependency edges connect tasks within the same onboarding/workspace, reject self-dependencies and cycles, and document allowed status transitions.

### FR-06 Commitments
Track owner, due date, status, and the party/description of the commitment. Overdue calculations must use the onboarding/workspace timezone and an explicitly defined set of terminal statuses.

### FR-07 Search and filtering
Support useful structured filters. Search must be scoped before pagination and must use deterministic ordering. Document whether search is substring, prefix, or full-text; do not describe it as full-text unless implemented.

### FR-08 Activity and audit
Record meaningful operational changes and proposal lifecycle events. Distinguish user-facing activity from security/audit events if they have different retention or visibility rules.

### FR-09 Approval centre
Show pending proposals to authorized reviewers with target, requested operation, proposer, submission time, safe before/after summary, and validation/version conflicts. Provide approve/reject actions with reason capture where required.

### FR-10 Custom fields
Validate value type against field definition, entity compatibility, cardinality, and workspace scope. Unknown or unsupported field types must fail closed.

### FR-11 Notifications
At minimum, define in-app notifications for assignment, proposal submission/decision, and relevant overdue events. Email/push delivery is out of initial scope unless explicitly approved.

### FR-12 User and membership management
Define invitation, activation/deactivation, role changes, and last-admin protection. Implement only the operations explicitly approved for the first release.

### FR-13 AI-safe access
AI/MCP reads must use explicit allowlisted projections. Default-deny unclassified fields. Exclude secrets, credentials, personal identifiers, financial account details, raw HR files, and unreviewed free text.

### FR-14 Proposal-only AI writes
MCP must not directly create/update/delete operational records or approve/reject proposals. Its only write operation is submission of a typed pending proposal.

### FR-15 Observability and error handling
Return stable machine-readable error codes and request IDs. Do not leak SQL errors, tokens, or internal stack traces.

## 9. MVP prioritization

### P0 — required for a credible demo
- Authenticated workspace-scoped access.
- Onboarding list and detail.
- Tasks and commitments visible with owners/status/due dates.
- At least one create/update operational workflow.
- Proposal submission and human approval/rejection.
- Activity/audit record for approved change.
- Clear validation and error states.
- Seed/demo data that is synthetic and clearly labelled.

### P1 — important if time permits
- Search/filter improvements.
- Events and decisions management.
- Task dependency visualization and validation.
- In-app notifications.
- Custom fields with complete type validation.
- Basic membership/role management.

### P2 — defer unless the assignment explicitly requires them
- Email/push notifications.
- Advanced analytics.
- Bulk operations/import/export.
- Full-text search infrastructure.
- Complex workflow automation.
- Production-grade multi-environment deployment and SSO.

## 10. Product success criteria

For a demo, a reviewer should be able to:
1. Understand the onboarding portfolio at a glance.
2. Open one customer onboarding and identify its current status and next actions.
3. Identify an overdue or blocked item and its owner.
4. See a proposed change awaiting approval.
5. Approve or reject it as an authorized human.
6. See the resulting record state and audit/activity history.
7. Understand that an AI agent cannot bypass human approval.

## 11. Open product decisions

Do not silently invent answers. Record owner decisions in `DECISION_LOG.md`:
- Exact status values and allowed transitions for each entity.
- Whether Implementation Managers can approve proposals they did not submit.
- Whether a proposer can ever approve their own proposal (recommended: no).
- Which Team Member operations are direct edits versus proposals.
- Whether comments are AI-readable (recommended initial default: no).
- Required fields for each record type.
- Whether notifications are P0 or P1.
- Whether the demo needs a frontend, an MCP-only flow, or both, based on the actual assignment brief.
