# Heartbeat — Agent Execution Protocol

> The heartbeat is a **protocol**, not a runtime. It defines the 9-step execution cycle
> every agent follows: wake, check, claim, understand, execute, report, persist, delegate.
> What the agent does during execution is entirely up to the agent.

---

## Overview

The heartbeat solves the "how do agents run" problem. Without it, agents would need
custom scheduling, custom concurrency, custom error handling. The heartbeat standardizes
all of that into one protocol that any adapter can implement.

Every agent run — whether triggered by a timer, a task assignment, or a human click —
follows the same 9-step cycle. The steps are sequential and atomic: if step N fails,
step N+1 does not execute.

---

## The 9-Step Cycle

```
WAKE (trigger fires)
  │
  ▼
┌──────────────────────┐
│ 1. Identity Retrieval │──── Load agent config, role, system prompt, adapter type
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 2. Check Approvals   │──── Any pending approval requests for this agent?
└──────────┬───────────┘     If yes → process approvals before task work
           ▼
┌──────────────────────┐
│ 3. Fetch Assigned    │──── Query inbox: assigned tasks, comments, pending work
│    Tasks             │     Priority sort: in_progress > blocked-resolved > new > comments
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 4. Select Highest    │──── Pick the single highest-priority work item
│    Priority Work     │     If no work → execute general heartbeat duties or idle
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 5. Atomic Checkout   │──── POST checkout with runId
│                      │     409 = another agent owns it → MOVE ON, NEVER RETRY
│                      │     200 = claimed, proceed
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 6. Understand        │──── Read task history, comments, parent chain
│    Context           │     Load session state, restore conversation
│                      │     Resolve workspace (project → session → agent home)
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 7. Execute Work      │──── The actual work happens here
│                      │     Duration is agent-controlled (unbounded)
│                      │     Adapter invokes the agent runtime
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 8. Update & Comment  │──── ALWAYS comment before exiting
│                      │     Update task status, record result
│                      │     Persist session state, log cost
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 9. Delegate          │──── Create subtasks for reports if needed
│                      │     Subtasks require parentId + goalId
│                      │     Cross-team delegation follows governance rules
└──────────────────────┘
```

### Step Details

| Step | What Happens | Failure Mode |
|------|-------------|-------------|
| **1. Identity Retrieval** | Load agent definition: name, role, adapter type, system prompt, config. This is "who am I" before doing anything. | Missing agent → abort run, log error. |
| **2. Check Approvals** | Query for pending approval requests where this agent is the approver. Process before task work (approvals unblock others). | Approval service down → skip, log warning. |
| **3. Fetch Assigned Tasks** | Query inbox for all assigned work: in-progress tasks, blocked tasks with resolved blockers, new assignments, unread comments, pending delegations. | Empty inbox → general heartbeat or idle. |
| **4. Select Priority** | Rank inbox items and pick one. Priority order: resume in-progress > unblock resolved > highest-priority new > comments needing response > general duties. | No selectable work → run completes with no-op. |
| **5. Atomic Checkout** | POST checkout with `{runId, agentId, taskId}`. Database enforces single-owner atomically. 409 Conflict returns the current owner's ID. **Never retry a 409. Move to next task.** | 409 → pick different task. DB error → abort run. |
| **6. Understand Context** | Read task description, full comment history, parent task chain (for sub-issues). Load session state via adapter codec. Resolve workspace directory. Check compaction thresholds. | Session restore fails → fresh session. Workspace fails → agent home fallback. |
| **7. Execute Work** | Call `adapter.invoke(config, context)`. The agent runs. Duration is unbounded and agent-controlled. The heartbeat protocol does not time out execution — that's the adapter's job. | Process crash → run marked `errored`. |
| **8. Update & Comment** | **Rule: always comment before exiting.** Post a comment on the task summarizing what was done, what's next, any blockers. Update task status. Record token usage and cost. Serialize session state. | Comment fails → log warning (work still done). Cost missing → recorded as $0. |
| **9. Delegate** | If the work requires sub-tasks, create them now. Each sub-task needs `parentId` (links to parent) and `goalId` (links to initiative). Assign to appropriate reports. Cross-team tasks follow governance rules in `governance.md`. | Delegation fails → log error, parent task stays in-progress. |

---

## Invariant Rules

These rules are absolute. Violating any of them is a protocol error.

| Rule | Rationale |
|------|-----------|
| **Always checkout before working** | Prevents two agents from working on the same task simultaneously. The checkout is the concurrency primitive. |
| **Never retry a 409** | If another agent owns the task, they own it. Retrying creates contention. Move to the next task in your inbox. |
| **Always comment before exiting** | Comments are the audit trail. Every run must leave a trace of what happened, even if the answer is "no work done." |
| **Subtasks need parentId + goalId** | parentId links the sub-task to its parent for rollup. goalId links it to the initiative for strategic alignment. Without both, the task is orphaned. |
| **Cross-team cancellation requires manager** | An agent cannot unilaterally cancel a task created by another team. Only the originator, their manager, or the Board can cancel. |

---

## Wake Triggers

An agent wakes up for one of these reasons. Every run records its wake source.

| Wake Source | Trigger Detail | Description |
|-------------|---------------|-------------|
| `timer` | `system` | Scheduled heartbeat (cron expression or interval) |
| `assignment` | `system` | New task assigned to this agent |
| `on_demand` | `manual` | Human clicked "Run" in the UI |
| `on_demand` | `ping` | Another agent pinged this agent (via task comment with @mention) |
| `on_demand` | `callback` | Human completed an agent-created task (pingback) |
| `automation` | `system` | Approval resolved, event hook fired, workflow trigger |
| `signal_intake` | `system` | New signal ingested that routes to this agent's domain |

### Wake Context Snapshot

Every wake carries a context snapshot — a JSON object recording why the agent woke
and what it should work on:

```json
{
  "wakeReason": "issue_assigned",
  "wakeSource": "assignment",
  "wakeTriggerDetail": "system",
  "issueId": "LUN-042",
  "taskId": "LUN-042",
  "taskKey": "LUN-042",
  "projectId": "proj-abc",
  "commentId": null,
  "forceFreshSession": false
}
```

### Fresh Session Triggers

A new session is created (instead of resuming) when:
- `forceFreshSession: true` in wake context
- `wakeReason: "issue_assigned"` (new task = fresh start)
- No prior session exists for this task

---

## Wakeup Coalescing

When multiple wake events fire for the same agent before it can process them,
coalescing prevents redundant runs.

### Idempotency Keys

Each wakeup request carries an idempotency key derived from:
- Agent ID + Task ID + Wake Reason

If a pending (unprocessed) wakeup request exists with the same idempotency key,
the new request **merges into the existing one** rather than creating a duplicate.

### Merge Behavior

```
Existing pending wake: { taskId: "LUN-042", commentId: "c-001" }
New wake arrives:      { taskId: "LUN-042", commentId: "c-002" }

Result: { taskId: "LUN-042", commentId: "c-002" }
        (new values override old, latest context wins)
```

This ensures the agent gets the most recent context without processing the
same task twice.

---

## Run Lifecycle States

Every heartbeat execution creates a `heartbeat_run` record that transitions
through these states:

```
┌──────────┐     ┌─────────────┐     ┌─────────────┐
│ PENDING  │────→│   RUNNING   │────→│  COMPLETED  │
└──────────┘     └──────┬──────┘     └─────────────┘
                        │
                        ├────→ FAILED      (process crash, adapter error, unhandled exception)
                        │
                        ├────→ CANCELLED   (board pause, budget breach, manual stop)
                        │
                        └────→ TIMED_OUT   (adapter-level timeout exceeded)
```

| State | Entry Condition | Terminal? |
|-------|----------------|-----------|
| `pending` | Run created, waiting for execution slot | No |
| `running` | Adapter invoked, agent is executing | No |
| `completed` | Agent finished successfully (exit code 0) | Yes |
| `failed` | Process crash, adapter failure, unhandled error | Yes |
| `cancelled` | Board paused agent, budget hard ceiling hit, manual cancel | Yes |
| `timed_out` | Adapter timeout exceeded without completion | Yes |

### Run Record Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | uuid | Run identifier |
| `agentId` | uuid | Which agent |
| `companyId` | uuid | Which company |
| `invocationSource` | enum | Wake source (timer, assignment, on_demand, automation) |
| `triggerDetail` | string | Additional context (manual, ping, callback, system) |
| `status` | enum | pending, running, completed, failed, cancelled, timed_out |
| `startedAt` | timestamp | When execution started |
| `finishedAt` | timestamp | When execution ended |
| `exitCode` | integer | Process exit code (0 = success) |
| `signal` | string | Process signal if killed (SIGTERM, SIGKILL) |
| `usageJson` | jsonb | Token counts: input, cached, output |
| `resultJson` | jsonb | Adapter-specific result payload |
| `sessionIdBefore` | string | Session ID at run start |
| `sessionIdAfter` | string | Session ID at run end (may differ if compacted) |
| `contextSnapshot` | jsonb | Wake context (task, reason, etc.) |
| `logStore` | string | Where logs are stored (db, filesystem) |
| `logRef` | string | Reference to full log |
| `logBytes` | integer | Size of captured logs |
| `error` | text | Error message if run failed |
| `errorCode` | string | Structured error code |
| `wakeupRequestId` | uuid | Which wake request triggered this run |

### Run Events (Live Streaming)

During execution, the run emits events streamed to the UI:

| Event Type | Description |
|------------|-------------|
| `log_chunk` | Stdout/stderr output (max 8KB per chunk) |
| `status_change` | Run status transition |
| `usage_update` | Incremental token count update |
| `session_change` | Session rotated or created |
| `workspace_warning` | Workspace resolution fell back |

---

## Agent States

An agent (not a run) has a persistent state independent of any particular execution:

| State | Description | Can Run? |
|-------|-------------|----------|
| `active` | Normal operating state. Heartbeats fire on schedule. | Yes |
| `idle` | Active but no pending work. Waiting for next trigger. | Yes (when triggered) |
| `running` | Currently executing a heartbeat run. | N/A (already running) |
| `error` | Last run failed. Agent still active but flagged. | Yes (next heartbeat) |
| `paused` | Board or budget system paused this agent. No heartbeats fire. | No |
| `terminated` | Permanently removed from the org. | No |

### State Transitions

```
          ┌────────────────────────┐
          │                        │
  ┌───────▼──┐    ┌──────┐    ┌───┴────┐
  │  ACTIVE  │◄──→│ IDLE │◄──→│ RUNNING│
  └───┬──┬───┘    └──────┘    └───┬────┘
      │  │                        │
      │  └──────┐          ┌──────┘
      │         ▼          ▼
      │      ┌──────┐  ┌───────┐
      │      │PAUSED│  │ ERROR │
      │      └──┬───┘  └───────┘
      │         │
      ▼         ▼
  ┌────────────────┐
  │  TERMINATED    │  (terminal — no return)
  └────────────────┘
```

---

## Concurrency

### Max Concurrent Runs

Each agent has a configurable concurrency limit.

| Setting | Value |
|---------|-------|
| Default | 1 (sequential execution) |
| Maximum | 10 |
| Configured in | Agent adapter config |

When the limit is reached, new wake requests are **deferred** (queued), not dropped.

### Agent Start Lock

Prevents duplicate spawns of the same agent. Per-agent promise chain that serializes
start attempts:

```
Agent A receives wake request
  → Acquire start lock for Agent A
  → Check concurrent run count
  → If under limit: create run, invoke adapter
  → If at limit: defer wake request
  → Release start lock
```

The lock serializes the decision, not the execution. Two simultaneous wake requests
cannot both pass the concurrency check.

### Deferred Work Queue

When an agent is busy (at concurrency limit), wake requests enter the deferred queue.

- Stored in `agent_wakeup_requests` table
- Processed FIFO when a run completes
- Each request carries its full context snapshot
- Coalescing: same-task wakes merge context snapshots (see Wakeup Coalescing above)
- Deferred context stored under `_osaWakeContext` key

---

## Orphaned Run Detection

Runs can become orphaned when agent process crashes, network partitions, or machine
goes offline mid-run.

### Detection

A run is considered orphaned when:
- Status is `running`
- No activity (log output, status update, heartbeat ping) for a configurable threshold
- Process liveness check fails (for local adapters)

### Recovery Policy

**The system does NOT auto-fix orphaned runs.** It surfaces them.

```
Orphaned run detected
  → Surface in dashboard with "stale" indicator
  → Alert escalation chain (if configured)
  → Human or manager agent decides: retry, reassign, or cancel
```

Automatic recovery hides failures. Good visibility lets the right entity decide.
See `governance.md` for the crash recovery philosophy.

---

## Pause Behavior

When the Board (or budget system) pauses an agent:

```
1. Signal current execution   → Send graceful termination to running process/session
2. Grace period               → Agent has time to wrap up, save state, report status
3. Force-kill after timeout   → If agent doesn't stop within grace period, terminate
4. Stop future heartbeats     → No new runs fire until agent is resumed
5. Drain deferred queue       → Pending wakes remain queued (not discarded)
```

When resumed:
- Deferred wakes are processed
- Scheduled heartbeat resumes at next interval
- Agent picks up where it left off (session restored)

---

## Configuration

Heartbeat behavior is configured per-agent in the adapter config:

```yaml
adapter_config:
  heartbeat:
    schedule: "*/15 * * * *"       # Cron: every 15 minutes (optional)
    max_concurrent_runs: 1          # 1-10
    grace_period_seconds: 30        # Pause grace period
    context_delivery: thin          # thin | fat (see adapters.md)
    wake_on_assignment: true        # Auto-wake when task assigned
    wake_on_mention: true           # Auto-wake when @mentioned in comment
```

---

## Feedback Loop Position

The heartbeat protocol implements **Layer 6 (The Feedback Loop)** of the Optimal System.

- The wake → execute → persist cycle IS circular causality — results feed back into the system as new data
- Step 8 ("always comment before exiting") enforces **Wiener's constraint**: every execution closes its feedback loop. An agent that exits without reporting has created an open loop — a Wiener violation.
- Orphaned run detection IS a feedback failure made visible — the system detects when loops fail to close
- The 9-step protocol ensures that no agent execution is a broadcast without confirmation

See `architecture/optimal-system-mapping.md` for the full 7-layer mapping.

---

## Related Docs

- [adapters.md](adapters.md) — How the agent runtime is invoked (step 7)
- [sessions.md](sessions.md) — How conversation state persists across runs (step 6, 8)
- [tasks.md](tasks.md) — How tasks are fetched, checked out, and updated (steps 3-5, 8-9)
- [budgets.md](budgets.md) — Budget checks that gate execution
- [governance.md](governance.md) — Board controls that can pause/terminate agents
- [workspaces.md](workspaces.md) — How the working directory is resolved (step 6)
- [self-healing.md](self-healing.md) — Step 7 failures (state: failed, errored) trigger healing episode creation; orphaned run detection feeds the healing subsystem
- [context-mesh.md](context-mesh.md) — Step 6 (Understand Context) reads from the team's keeper; step 8 (Update and Comment) writes discoveries to the keeper
- [peer-protocol.md](peer-protocol.md) — Step 3 inbox polling processes handoffs and review requests delivered by peer agents
- [decision-graph.md](decision-graph.md) — Step 8 creates decision nodes for significant choices made during execution; step 6 loads decision context for the current task

---

*Heartbeat Protocol v2.0 — The 9-step execution cycle for agent orchestration*
