---
name: board
description: >
  Visual task management dashboard. Terminal-based kanban board, tiled agent status
  view, and progress tracking. Shows all agents, their current tasks, budget
  consumption, and overall workspace health at a glance.
  Triggers on: "board", "dashboard", "kanban", "status board", "show agents"
---

# /board

> Visual task management — kanban board, agent status, progress dashboard.

## Purpose

The command center for multi-agent workspaces. Renders a terminal-based view of all active work: who's doing what, what's blocked, what's done, and how much budget remains. Three view modes: kanban (task-centric), agents (agent-centric), and summary (metrics-centric). Designed for the orchestrator to maintain situational awareness.

## Usage

```bash
# Default kanban view
/board

# Agent-centric view
/board agents

# Summary metrics view
/board summary

# Filter by status
/board --status in_progress

# Filter by agent
/board --agent researcher

# Watch mode (auto-refresh)
/board --watch

# Compact view (fits small terminals)
/board --compact
```

## Arguments

| Subcommand | Description |
|------------|-------------|
| (default) | Kanban board view |
| `agents` | Agent-centric tiled view |
| `summary` | Metrics dashboard |

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--status` | enum[] | `all` | Filter: `backlog`, `ready`, `in_progress`, `blocked`, `done` |
| `--agent` | string | `all` | Filter to specific agent |
| `--watch` | flag | false | Auto-refresh every 5 seconds |
| `--compact` | flag | false | Condensed view for small terminals |
| `--since` | duration | `24h` | Time window for completed tasks |
| `--show-budget` | flag | true | Show budget consumption bars |
| `--show-timeline` | flag | false | Show task timeline (Gantt-style) |

## Workflow

1. **Collect** — Read task store, agent registry, checkout locks, budget tracker, and heartbeat status.
2. **Aggregate** — Group tasks by status. Map tasks to agents. Calculate budget percentages. Detect anomalies (stalled agents, overdue tasks).
3. **Render** — Display in the requested view mode with ANSI colors for terminal rendering.
4. **Watch** — If `--watch`, clear and re-render every 5 seconds. Highlight changes since last refresh.

## Output

### Kanban view (default)
```
╔═══════════════════════════════════════════════════════════════════════════╗
║                        WORKSPACE BOARD                                   ║
║  Agents: 4 active | Tasks: 12 total | Budget: 67% remaining             ║
╠═══════════════╦═══════════════╦═══════════════╦═══════════════════════════╣
║  BACKLOG (3)  ║ IN PROGRESS(4)║  BLOCKED (1)  ║  DONE (4)               ║
╠═══════════════╬═══════════════╬═══════════════╬═══════════════════════════╣
║ Write docs    ║ ▶ Pricing     ║ ⚠ Revenue     ║ ✓ Competitor scan       ║
║   low         ║   researcher  ║   analyst     ║   researcher  12m       ║
║               ║   18m elapsed ║   waiting on  ║                         ║
║ Update tests  ║               ║   task-d4e5   ║ ✓ Draft pitch v1        ║
║   normal      ║ ▶ Refactor    ║               ║   writer      34m       ║
║               ║   coder       ║               ║                         ║
║ Design review ║   6m elapsed  ║               ║ ✓ Search endpoint       ║
║   low         ║               ║               ║   coder       22m       ║
║               ║ ▶ Pitch draft ║               ║                         ║
║               ║   writer      ║               ║ ✓ Market analysis       ║
║               ║   2m elapsed  ║               ║   analyst     45m       ║
╚═══════════════╩═══════════════╩═══════════════╩═══════════════════════════╝
```

### Agent view
```markdown
## Agents

### researcher (agent-a1b2) — healthy
- **Task:** Pricing benchmark analysis (18m elapsed)
- **Budget:** ████████░░ 23,400/50,000 (47%)
- **Completed today:** 2 tasks

### writer (agent-c3d4) — healthy
- **Task:** Pitch deck draft v2 (2m elapsed)
- **Budget:** ███░░░░░░░ 11,200/30,000 (37%)
- **Completed today:** 1 task

### analyst (agent-e5f6) — STALLED
- **Task:** Revenue report (blocked on task-d4e5)
- **Budget:** █████████░ 45,100/50,000 (90%)
- **Alert:** No heartbeat for 4m 12s

### coder (agent-g7h8) — idle
- **Task:** —
- **Budget:** ░░░░░░░░░░ 0/100,000 (0%)
- **Available for work**
```

### Summary view
```markdown
## Workspace Summary

| Metric | Value | Trend |
|--------|-------|-------|
| Active agents | 4 | — |
| Tasks completed (24h) | 4 | +2 vs yesterday |
| Tasks in progress | 4 | — |
| Tasks blocked | 1 | new |
| Total budget used | 79,700 / 230,000 | 35% |
| Avg task duration | 28m | -5m vs yesterday |
| Throughput | 1.2 tasks/hr | +0.3 |
```

## Dependencies

- Task store (for task data)
- Agent registry (for agent status)
- `/heartbeat` — Agent health data
- `/budget` — Budget consumption data
- `/checkout` — Lock status
- Terminal with ANSI color support (for visual rendering)
