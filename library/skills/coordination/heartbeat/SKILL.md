---
name: heartbeat
description: >
  Agent wake-up and health monitoring protocol. 9-step startup cycle that grounds
  the agent in identity, fetches tasks, selects work, and begins execution. Also
  serves as a periodic health check — detect stalled or dead agents. Scheduled or
  event-triggered.
  Triggers on: "heartbeat", "wake up", "agent health", "check agents"
---

# /heartbeat

> Agent wake-up protocol and health monitoring.

## Purpose

Two functions in one. First: the startup ritual every agent runs when it wakes up — a 9-step cycle that establishes identity, checks approvals, fetches available work, selects a task, locks it, understands context, executes, updates status, and optionally delegates sub-work. Second: a monitoring heartbeat that detects stalled, crashed, or unresponsive agents and triggers recovery.

## Usage

```bash
# Run the wake-up cycle (agent runs this on startup)
/heartbeat

# Run heartbeat for a specific agent
/heartbeat --agent researcher

# Check health of all running agents
/heartbeat --check-all

# Set heartbeat interval
/heartbeat --interval 60s

# View heartbeat history
/heartbeat --history --last 10

# Force wake-up of a stalled agent
/heartbeat --wake researcher
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--agent` | string | self | Agent to run heartbeat for |
| `--check-all` | flag | false | Health check all registered agents |
| `--interval` | duration | `60s` | Time between heartbeat pings |
| `--timeout` | duration | `180s` | Mark agent as stalled after this silence |
| `--history` | flag | false | Show heartbeat event history |
| `--last` | int | 10 | Number of history entries to show |
| `--wake` | string | — | Force wake-up of a specific agent |
| `--on-stall` | enum | `warn` | Action on stall: `warn`, `restart`, `reassign`, `kill` |

## Workflow

### Wake-Up Cycle (9 steps)

1. **Identity** — Load agent identity: name, role, capabilities, system prompt. Confirm workspace scope and permissions.
2. **Approvals** — Check for any pending approval requests (from `/approve`). Process approvals before starting new work.
3. **Fetch tasks** — Query task store for available tasks matching this agent's capabilities. Filter by priority and dependencies.
4. **Select work** — Pick the highest-priority task that isn't locked. Consider: deadline proximity, complexity match, budget remaining.
5. **Checkout** — Lock the selected task via `/checkout`. If lock fails (409), return to step 4.
6. **Understand** — Load task context: read referenced files, check parent chain, review related messages in inbox.
7. **Execute** — Perform the task. Use available commands within scope. Track token consumption.
8. **Update** — Write result to task store. Update status: `in_progress` → `complete` or `blocked`. Send result message to parent.
9. **Delegate** — If sub-tasks were identified during execution, create them via `/delegate`. Return to step 3 if more work available.

### Health Monitoring

1. **Ping** — Each agent writes a heartbeat file with timestamp every `--interval`.
2. **Check** — Monitor reads all heartbeat files. Flag any agent whose last heartbeat exceeds `--timeout`.
3. **Respond** — Based on `--on-stall`: warn (log + alert), restart (kill + respawn), reassign (release tasks + redistribute), kill (terminate).

## Output

### Wake-up cycle output
```markdown
## Heartbeat — researcher (agent-a1b2)

| Step | Status | Detail |
|------|--------|--------|
| 1. Identity | done | researcher / Market Analyst / scope: read-only |
| 2. Approvals | done | 0 pending |
| 3. Fetch tasks | done | 3 available tasks |
| 4. Select work | done | task-d4e5: "Analyze competitor pricing" (priority: high) |
| 5. Checkout | done | Lock acquired |
| 6. Understand | done | Loaded 4 context files (8,200 tokens) |
| 7. Execute | running | ... |
```

### Health check output
```markdown
## Agent Health — All Agents

| Agent | Status | Last Heartbeat | Current Task | Budget Used |
|-------|--------|---------------|--------------|-------------|
| researcher | healthy | 12s ago | task-d4e5 | 23,400/50,000 |
| writer | healthy | 8s ago | task-f6g7 | 11,200/30,000 |
| analyst | stalled | 4m 12s ago | task-h8i9 | 45,100/50,000 |
| coder | idle | 3s ago | — | 0/100,000 |

### Alerts
- analyst: STALLED (exceeded 180s timeout). Last activity: writing to processed/report.md. Action: warn.
```

## Dependencies

- Agent registry
- `/checkout` — Task locking (step 5)
- `/inbox` — Message checking (step 2) and result delivery (step 8)
- `/delegate` — Sub-task creation (step 9)
- `/budget` — Budget tracking
- File system for heartbeat files
