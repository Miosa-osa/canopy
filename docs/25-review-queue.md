# Review Queue

The Review module is the human gate for work that should not silently proceed.
It is backed by the `reviews` database table and rendered at `/review`.

## What Creates Reviews

Reviews are activated by inserting a pending row through one of these paths:

```text
POST /api/v1/reviews
review.request_artifact
review.request_tool_call
Canopy.Reviews.request_artifact/1
Canopy.Reviews.request_tool_call/4
Canopy.Reviews.request_hire_agent/5
Canopy.Governance.Reviewer
Canopy.Agents.Tools approval gates
```

The queue does not scan files by itself. Something must explicitly request review.

## Kinds

```text
artifact    doc, task, issue, pr, file, kb_chunk
tool_call   dangerous or approval-gated tool invocation
hire_agent  approval gate before spawning a child/sub-agent
```

## Lifecycle

```text
pending
  -> approved
  -> rejected
  -> changes_requested
changes_requested
  -> pending       via resubmit, increments revision_count
```

Only `pending` reviews can be approved, rejected, or moved to changes requested.
Only `changes_requested` reviews can be resubmitted.

## Persistence

Rows are saved in Postgres through `Canopy.Reviews.Review`.

Important fields:

```text
workspace_slug
kind
artifact_type
artifact_id
artifact_preview
tool_name
tool_args
session_id
agent_id
reviewer_id
status
feedback
requested_at
decided_at
expires_at
revision_count
created_by_run_id
```

Decisions update the same row. They do not create a second object.

## API

```text
GET  /api/v1/reviews
GET  /api/v1/reviews/summary
GET  /api/v1/reviews/:id
POST /api/v1/reviews
POST /api/v1/reviews/:id/approve
POST /api/v1/reviews/:id/reject
POST /api/v1/reviews/:id/request_changes
POST /api/v1/reviews/:id/resubmit
```

List filters:

```text
workspace_slug
status
kind
agent_id
session_id
```

The summary endpoint returns real database aggregates for dashboards and agent
planning:

```text
total
pending_count
decided_count
changes_requested_count
by_status
by_kind
by_workspace
by_agent
oldest_pending_at
next_expiry_at
recent
```

## UI

`/review` has four views:

```text
Overview  real database summary, timing, workspace, agent, and recent rows
Queue     searchable/filterable human review rows
Routing   agent/MCP/API paths that can create or consume reviews
Git       worktree diff/commit panel for active session worktrees
```

The queue can create manual artifact or tool-call reviews, then approve, reject,
request changes, or resubmit them through the same API used by agent gates.

## Agent Tool Contract

These tools are registered in the shared Canopy tool registry and are exposed to
agents through MCP/prompt tool surfaces:

```text
review.list
review.summary
review.get
review.request_artifact
review.request_tool_call
review.approve
review.reject
review.request_changes
review.resubmit
```

Legacy session agents can also call:

```text
canopy.request_review
```

That legacy tool accepts `kind: artifact` or defaults to a tool-call review. It
preserves `workspace_slug`, `agent_id`, and `session_id` so the queue can show
where the review came from.
