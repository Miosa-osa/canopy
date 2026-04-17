# Sessions — Session Persistence & Compaction

> Conversation state across runs. A session preserves an agent's context when working
> on a task — maintained between heartbeat cycles so the agent does not start from
> scratch every time it wakes up.

---

## Overview

Without sessions, every agent wake would be amnesiac. The agent would need to re-read
every file, re-understand every decision, re-load every context. Sessions solve this
by persisting conversation state between runs and managing the inevitable growth of
that state through compaction.

Sessions are scoped to **agent + task**. Each task gets its own session per agent.
This prevents context pollution between unrelated work items.

---

## Session Lifecycle

```
NEW TASK ASSIGNED
  │
  ▼
┌─────────────────┐
│ Create Session   │ ← Fresh session, no prior state
└────────┬────────┘
         ▼
┌─────────────────┐     ┌─────────────────┐
│ Run 1: Execute   │────→│ Serialize State  │ ← Save at run end
└─────────────────┘     └────────┬────────┘
                                 ▼
┌─────────────────┐     ┌─────────────────┐
│ Deserialize      │←────│ Stored State    │ ← Restore at run start
└────────┬────────┘     └─────────────────┘
         ▼
┌─────────────────┐     ┌─────────────────┐
│ Run 2: Execute   │────→│ Serialize State  │
└─────────────────┘     └────────┬────────┘
                                 ▼
                        ┌─────────────────┐
                        │ Compaction       │ ← Check after every run
                        │ Check            │
                        └────────┬────────┘
                          │           │
                    UNDER LIMIT   OVER LIMIT
                          │           │
                          ▼           ▼
                    Continue     Rotate Session
                    session      (handoff + fresh)
```

---

## Task-Scoped Sessions

Each agent-task pair gets its own independent session.

```
Agent "alice"
  ├── Task LUN-042 → Session sess-abc (12 runs, 180K tokens)
  ├── Task LUN-043 → Session sess-def (3 runs, 45K tokens)
  └── Task LUN-044 → Session sess-ghi (1 run, 15K tokens)
```

### Task Key Resolution

The task key is derived from the wake context in priority order:

1. `contextSnapshot.taskKey`
2. `contextSnapshot.taskId`
3. `contextSnapshot.issueId`
4. `payload.taskKey`
5. `payload.taskId`
6. `payload.issueId`

If no task key is found, the run uses the agent's **general session** (not task-scoped).

### Session Lookup

```
Given: agentId + adapterType + taskKey
  → Query agent_task_sessions table
  → Found? → Deserialize and resume
  → Not found? → Create new session
```

---

## Session Compaction Policy

When a session grows too large, it is **rotated** — the old session is archived and
a new session starts with a handoff note summarizing the prior work.

### Compaction Triggers

| Threshold | Default | Description |
|-----------|---------|-------------|
| `maxSessionRuns` | 20 | Maximum heartbeat runs in one session |
| `maxRawInputTokens` | 500,000 | Maximum cumulative input tokens across all runs |
| `maxSessionAgeHours` | 24 | Maximum hours since session creation |

Any single threshold exceeded triggers compaction.

### Policy Resolution Order

Compaction thresholds are resolved in this priority:

1. **Runtime config** — Explicitly set in the agent's adapter config for this run
2. **Adapter defaults** — Default values defined by the adapter type
3. **Legacy fallback** — System-wide defaults (20 runs, 500K tokens, 24 hours)

This allows per-agent tuning. A simple summarization agent might compact every 5 runs.
A deep research agent might tolerate 50 runs before compacting.

### Compaction Process

```
Session exceeds threshold
  │
  ▼
1. Detect which threshold was exceeded
   (reason: "max_runs_exceeded" | "max_tokens_exceeded" | "max_age_exceeded")
  │
  ▼
2. Extract summary from the latest run's result
   (look for: result.summary → result.message → result.error → "No summary available")
  │
  ▼
3. Generate handoff markdown:
   ┌─────────────────────────────────────────────────────────────────┐
   │ OSA session handoff:                                            │
   │ - Previous session: {session_display_id}                       │
   │ - Issue: {task_key}                                            │
   │ - Rotation reason: Session exceeded {threshold} ({value})      │
   │ - Last run summary: {extracted_summary}                        │
   │                                                                 │
   │ Continue from the current task state.                           │
   │ Rebuild only the minimum context you need.                     │
   │ Do not re-read files you've already processed unless needed.   │
   └─────────────────────────────────────────────────────────────────┘
  │
  ▼
4. Archive old session
   (preserve in agent_task_sessions table with archived flag)
  │
  ▼
5. Next run starts with fresh session + handoff injected as initial context
```

### What Compaction Preserves vs. Loses

| Preserved | Lost |
|-----------|------|
| Handoff summary of progress and decisions | Raw conversation turns |
| Current task state and status | Intermediate reasoning chains |
| Key decisions (extracted into summary) | Tool call history |
| Issue context and identifiers | Cached file contents from prior reads |
| Session lineage (which session preceded this one) | Working memory key-value pairs |

Compaction is **intentionally lossy for intermediate reasoning**. Reasoning is noise
once a decision is made. Decisions and progress are signal — those survive.

### Compaction Policy Schema

```yaml
session:
  compaction_enabled: true           # false to disable rotation entirely
  max_session_runs: 20               # 0 = unlimited
  max_raw_input_tokens: 500000       # 0 = unlimited
  max_session_age_hours: 24          # 0 = unlimited
```

---

## Session Codec

The session codec handles serialization and deserialization of conversation state.
Each adapter type defines its own codec (see `adapters.md`).

### Serialize (Run End)

Called after every successful run. Captures:

| Data | What Gets Saved |
|------|----------------|
| Session ID | Unique identifier for this session |
| Session params | Adapter-specific state (conversation file path, session token, etc.) |
| Display ID | Human-readable session identifier for the UI |
| Working directory | Where the session was executing |
| Workspace ID | Which project workspace (if any) |

### Deserialize (Run Start)

Called before every run that has a prior session:

```
Stored session params (JSON)
  → Adapter codec deserialize
    → Live session state
      → Injected into adapter invocation context
```

### Display ID

Truncated, human-readable identifier shown in the dashboard. The codec extracts
this from session params (usually the session ID or a derived short string).
Max length: 128 characters.

---

## Agent Runtime State

Beyond task-scoped sessions, each agent maintains cumulative runtime state:

```typescript
interface AgentRuntimeState {
  // Session tracking
  currentSessionId: string | null;
  sessionCount: number;             // Total sessions created

  // Cumulative metrics
  totalInputTokens: number;
  totalOutputTokens: number;
  totalCostUsd: number;
  totalRuns: number;

  // Error tracking
  consecutiveErrors: number;        // Reset on successful run
  lastErrorCode: string | null;
  lastErrorAt: timestamp | null;

  // State
  updatedAt: timestamp;
}
```

This state persists across session rotations and task changes. It provides the
agent-level view of cumulative resource consumption and health.

---

## Fresh Session Triggers

A fresh session is created (discarding any existing session) when:

| Trigger | Reason |
|---------|--------|
| `forceFreshSession: true` in wake context | Explicit request (board, manual) |
| `wakeReason: "issue_assigned"` | New task assignment = clean start |
| No prior session exists for this task | First run on this task |
| Session compaction rotated | Old session archived, new one created |

---

## Session Migration

When a workspace changes (e.g., project workspace becomes available after clone),
the session migrates.

### Migration Rules

| Condition | Action |
|-----------|--------|
| Previous session in agent home directory | Migrate to project workspace |
| Previous session in different project workspace | Keep current (no auto-migrate) |
| Previous workspace ID differs from current | Keep current |
| Project workspace matches session workspace | No migration needed |

### Migration Process

```
Previous session: cwd = /home/agents/alice (fallback)
Project workspace now available: /workspaces/project-abc/repo

  → Session params updated:
    - cwd: /workspaces/project-abc/repo
    - workspaceId: ws-123
    - repoUrl: https://github.com/org/repo
    - repoRef: main

  → Warning logged: "Project workspace is now available.
     Attempting to resume session in new workspace."
```

---

## Session Storage

### Task Session Table

```
agent_task_sessions
  ├── company_id        (uuid)
  ├── agent_id          (uuid)
  ├── adapter_type      (string)
  ├── task_key          (string)      ← Composite lookup key
  ├── session_params    (jsonb)       ← Adapter-specific state
  ├── session_display_id (string)     ← Human-readable ID
  ├── archived          (boolean)     ← True after compaction
  ├── handoff_note      (text)        ← Compaction summary
  ├── predecessor_id    (uuid)        ← Previous session (lineage chain)
  ├── run_count         (integer)     ← Runs in this session
  ├── total_input_tokens (integer)    ← Cumulative tokens
  ├── created_at        (timestamp)
  └── updated_at        (timestamp)
```

### Runtime State Table

For non-task-scoped sessions (general heartbeat):

```
agent_runtime_state
  ├── agent_id          (uuid)
  ├── session_id        (string)      ← Current general session
  ├── total_input_tokens (integer)
  ├── total_output_tokens (integer)
  ├── total_cost_usd    (decimal)
  ├── total_runs        (integer)
  ├── consecutive_errors (integer)
  ├── last_error_code   (string)
  ├── last_error_at     (timestamp)
  └── updated_at        (timestamp)
```

---

## Cross-Agent State Sharing

Agents share state **only through tasks and handoffs**. Direct state sharing between
agents is not permitted. All inter-agent communication goes through:

1. Task creation and assignment (delegation)
2. Task comments (coordination)
3. Workflow handoff templates (phase transitions)

This ensures every state transfer is logged in the activity log and subject to
governance rules. No hidden side channels.

---

## Related Docs

- [heartbeat.md](heartbeat.md) — Session restore (step 6) and persist (step 8) in the cycle
- [adapters.md](adapters.md) — Session codec defined per adapter type
- [tasks.md](tasks.md) — Task keys that scope sessions
- [workspaces.md](workspaces.md) — Workspace migration triggers session migration

---

*Session Persistence v2.0 — Conversation state management with compaction policy*
