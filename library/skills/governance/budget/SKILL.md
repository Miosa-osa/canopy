---
name: budget
description: >
  3-tier budget enforcement for AI agent workspaces. Visibility dashboards (always on),
  soft alerts at 80% threshold, hard ceilings at 100% that auto-pause agents.
  Tracks per-agent, per-task, and per-project costs in both tokens and dollars.
  Triggers on: "budget", "cost", "spending", "token usage", "billing"
---

# /budget

> 3-tier budget enforcement — visibility, alerts, hard ceilings.

## Purpose

Prevent runaway AI costs in multi-agent workspaces. Every token consumed is tracked at three levels: per-agent, per-task, and per-project. Three enforcement tiers ensure costs never surprise you: Tier 1 (visibility) shows real-time dashboards, Tier 2 (soft alerts) warns at 80%, Tier 3 (hard ceilings) auto-pauses agents at 100%.

## Usage

```bash
# View budget dashboard
/budget

# View specific agent's budget
/budget --agent researcher

# Set project budget
/budget set --project 500000 --dollars 25.00

# Set per-agent budget
/budget set --agent researcher 50000

# View burn rate
/budget burn-rate

# Export cost report
/budget report --format csv --period 2026-03

# Reset budget counters (new billing period)
/budget reset --confirm
```

## Arguments

| Subcommand | Description |
|------------|-------------|
| (default) | Show budget dashboard |
| `set` | Set budget limits |
| `burn-rate` | Show token consumption velocity |
| `report` | Export detailed cost report |
| `reset` | Reset counters for new period |

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--agent` | string | `all` | Filter to specific agent |
| `--project` | int | — | Set project-level token budget |
| `--dollars` | float | — | Set dollar budget (converted via model pricing) |
| `--format` | enum | `terminal` | `terminal`, `csv`, `json`, `markdown` |
| `--period` | string | current | Billing period (YYYY-MM or date range) |
| `--confirm` | flag | false | Required for destructive operations (reset) |
| `--alert-threshold` | float | 0.8 | Tier 2 soft alert threshold (0.0–1.0) |
| `--hard-ceiling` | float | 1.0 | Tier 3 hard ceiling (0.0–1.0+, >1.0 allows overflow) |

## Workflow

### Tracking
1. **Intercept** — Every LLM call from any agent passes through the budget tracker. Record: agent ID, task ID, model, input tokens, output tokens, timestamp.
2. **Price** — Convert tokens to dollars using model-specific pricing: Claude Opus ($15/1M in, $75/1M out), Sonnet ($3/$15), Haiku ($0.25/$1.25), Codex (per pricing), Gemini (per pricing).
3. **Aggregate** — Maintain running totals at all three levels: agent, task, project.
4. **Store** — Append to budget log (append-only file, never edited).

### Enforcement Tiers
1. **Tier 1 — Visibility** (always on): Budget data visible in `/board`, `/heartbeat`, and dedicated dashboard. No action taken.
2. **Tier 2 — Soft Alerts** (80% default): When any level crosses the threshold, emit warning to orchestrator inbox. Agent continues working. Logged as `budget_warning` event.
3. **Tier 3 — Hard Ceiling** (100%): When any level hits ceiling, auto-pause the agent. Send `budget_exceeded` message to orchestrator. Agent cannot resume until budget is increased or reset.

## Output

### Dashboard
```markdown
## Budget Dashboard — 2026-03-20

### Project Total
| Metric | Value |
|--------|-------|
| Token budget | 500,000 |
| Tokens used | 167,300 (33%) |
| Dollar budget | $25.00 |
| Dollars spent | $8.42 (34%) |
| Burn rate | 12,400 tokens/hr |
| Time to ceiling | ~27 hours at current rate |

### Per-Agent Breakdown
| Agent | Budget | Used | % | $/hr | Status |
|-------|--------|------|---|------|--------|
| researcher | 50,000 | 23,400 | 47% | $1.20 | active |
| writer | 30,000 | 11,200 | 37% | $0.85 | active |
| analyst | 50,000 | 45,100 | 90% | $2.10 | ⚠ ALERT |
| coder | 100,000 | 0 | 0% | $0.00 | idle |
| unallocated | 270,000 | — | — | — | — |

### Top Tasks by Cost
| Task | Agent | Tokens | Cost |
|------|-------|--------|------|
| Revenue analysis | analyst | 38,200 | $4.12 |
| Competitor scan | researcher | 18,400 | $1.85 |
| Pitch draft v1 | writer | 9,800 | $0.98 |

### Alerts
- ⚠ analyst: 90% of budget consumed (soft alert threshold: 80%)
```

## Dependencies

- Agent registry (for mapping agent IDs)
- Task store (for mapping task IDs)
- Model pricing configuration
- `/heartbeat` — Agent status for pause/resume
- `/inbox` — Alert delivery
- Budget log file (append-only)
