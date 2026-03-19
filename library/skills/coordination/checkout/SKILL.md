---
name: checkout
description: >
  Atomic task locking. Ensures only one agent works on a task at a time. Returns
  409 Conflict if already locked. Auto-releases on agent death or timeout. Prevents
  double-work and wasted compute in multi-agent systems.
  Triggers on: "checkout", "lock task", "claim task", "reserve"
---

# /checkout

> Atomic task locking — one agent per task, no double-work.

## Purpose

Prevent two agents from working on the same task simultaneously. When an agent selects a task, it must check it out first. The checkout is atomic: if two agents race for the same task, exactly one wins and the other gets a 409 Conflict. Locks auto-release on agent death (detected via heartbeat), explicit release, or timeout.

## Usage

```bash
# Check out a task
/checkout task-d4e5

# Check out with explicit timeout
/checkout task-d4e5 --timeout 30m

# Release a checkout
/checkout release task-d4e5

# Force-release (admin override)
/checkout release task-d4e5 --force

# List all active checkouts
/checkout list

# Check if a task is locked
/checkout status task-d4e5
```

## Arguments

| Subcommand | Description |
|------------|-------------|
| `<task-id>` | Check out (lock) a task |
| `release <task-id>` | Release a checkout |
| `list` | Show all active checkouts |
| `status <task-id>` | Check lock status of a specific task |

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--timeout` | duration | `30m` | Auto-release after this duration |
| `--force` | flag | false | Force-release even if held by another agent (admin only) |
| `--agent` | string | self | Agent identity for the checkout |
| `--reason` | string | — | Why this task is being checked out |

## Workflow

### Checkout (Lock)
1. **Validate** — Confirm task exists in task store. Confirm requesting agent is registered.
2. **Atomic lock** — Attempt to create lock file: `.locks/{task-id}.lock`. Use OS-level atomic file creation (O_CREAT | O_EXCL) to guarantee only one writer succeeds.
3. **Write lock metadata** — `{task_id, agent_id, agent_name, locked_at, timeout, reason}`.
4. **Respond** — 200 OK with lock confirmation, or 409 Conflict with current holder info.
5. **Schedule auto-release** — Set timer for `--timeout`. On expiry, release lock and log warning.

### Release
1. **Validate** — Confirm lock exists. Confirm releasing agent is the holder (unless `--force`).
2. **Remove lock file** — Delete `.locks/{task-id}.lock`.
3. **Log** — Record release event with duration held.
4. **Notify** — If other agents are queued for this task, notify via inbox.

### Auto-release (on agent death)
1. **Heartbeat monitor** detects agent stall/death.
2. **Scan locks** — Find all locks held by the dead agent.
3. **Release all** — Remove lock files. Log as auto-release with reason "agent_death".
4. **Reassign** — Notify orchestrator that tasks are available.

## Output

### Successful checkout
```
Checkout acquired: task-d4e5
  Agent: researcher (agent-a1b2)
  Locked at: 2026-03-20T14:35:00Z
  Timeout: 30m (auto-release at 15:05)
```

### Conflict (409)
```
Checkout DENIED: task-d4e5
  Held by: writer (agent-c3d4)
  Locked at: 2026-03-20T14:30:00Z
  Timeout: 15m (auto-release at 14:45)
  Suggestion: wait or pick another task
```

### List output
```markdown
## Active Checkouts

| Task | Agent | Locked At | Timeout | Remaining |
|------|-------|-----------|---------|-----------|
| task-d4e5 | researcher | 14:35 | 30m | 22m |
| task-f6g7 | writer | 14:30 | 15m | 7m |
| task-h8i9 | analyst | 14:20 | 30m | 12m |
```

## Dependencies

- File system with atomic file creation (POSIX O_CREAT|O_EXCL or equivalent)
- `/heartbeat` — Detects dead agents for auto-release
- Agent registry — Validates agent identity
- Task store — Validates task existence
