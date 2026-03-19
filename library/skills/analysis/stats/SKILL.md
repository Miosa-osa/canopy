---
name: stats
description: >
  Workspace metrics dashboard. Tracks growth rate, connection density, pipeline
  throughput, health score trends, budget consumption, and agent utilization over
  time. Includes trend detection for spotting degradation or acceleration.
  Triggers on: "stats", "metrics", "dashboard", "workspace numbers"
---

# /stats

> Workspace metrics dashboard with trend detection.

## Purpose

Quantify the state and trajectory of your workspace. Track how fast the knowledge base is growing, how well-connected it is, how much processing throughput the pipeline achieves, whether health is improving or degrading, and how efficiently agents are consuming budget. Designed for weekly reviews and operational awareness.

## Usage

```bash
# Full metrics dashboard
/stats

# Specific metric category
/stats growth

# Stats for a time period
/stats --period 2026-03

# Stats with trend analysis
/stats --trends

# Compare two periods
/stats --compare 2026-02 2026-03

# Export for reporting
/stats --format markdown --output monthly-report.md

# Agent utilization stats
/stats agents
```

## Arguments

| Subcommand | Description |
|------------|-------------|
| (default) | Full dashboard — all categories |
| `growth` | Knowledge base growth metrics |
| `connections` | Graph density and connection metrics |
| `pipeline` | Processing pipeline throughput |
| `health` | Health score trend |
| `budget` | Budget consumption and efficiency |
| `agents` | Agent utilization and productivity |

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--period` | string | `current-month` | Time period: `today`, `this-week`, `YYYY-MM`, date range |
| `--trends` | flag | false | Include trend analysis (requires historical data) |
| `--compare` | string | — | Compare against another period |
| `--format` | enum | `terminal` | `terminal`, `markdown`, `json`, `csv` |
| `--output` | path | stdout | Write to file |
| `--scope` | string | `all` | `all`, `node:<name>` |

## Workflow

1. **Collect** — Read from metrics store: file counts, timestamps, graph edges, pipeline logs, health history, budget logs, agent logs.
2. **Compute** — Calculate metrics per category:
   - Growth: files added, words written, claims extracted, net change
   - Connections: edge count, density (edges/possible edges), avg degree, clustering coefficient
   - Pipeline: items processed, avg processing time, throughput (items/day)
   - Health: current score, score history, check pass rate
   - Budget: tokens consumed, dollars spent, cost per task, cost per claim
   - Agents: tasks completed, avg task time, idle time, budget efficiency
3. **Trend** — If `--trends`, compute 7-day and 30-day moving averages. Detect: acceleration (metric growing faster), deceleration (slowing), degradation (metric declining), stability.
4. **Compare** — If `--compare`, compute deltas between periods.
5. **Render** — Display in requested format with sparklines for terminal, tables for markdown.

## Output

```markdown
## Workspace Stats — March 2026

### Growth
| Metric | Value | Trend (30d) |
|--------|-------|-------------|
| Total files | 287 | +34 (+13%) |
| Total words | 142,800 | +18,400 (+15%) |
| Claims extracted | 891 | +127 (+17%) |
| Signals processed | 43 | +12 (+39%) |
| Context updates | 28 | +8 (+40%) |

### Connection Density
| Metric | Value | Trend |
|--------|-------|-------|
| Entities | 156 | +14 |
| Edges | 423 | +67 (+19%) |
| Density | 0.035 | +0.003 |
| Avg degree | 5.4 | +0.6 |
| Clustering coeff | 0.42 | stable |
| Orphan rate | 4.2% | -1.1% (improving) |

### Pipeline Throughput
| Metric | Value | Trend |
|--------|-------|-------|
| Items processed | 43 | — |
| Avg processing time | 2m 18s | -12s (improving) |
| Throughput | 1.4 items/day | +0.3 |
| Pipeline errors | 2 | -1 |
| Reduction quality | 0.84 | stable |

### Health Score
| Date | Score | Delta |
|------|-------|-------|
| Mar 20 | 78 | — |
| Mar 13 | 72 | +6 |
| Mar 06 | 65 | +7 |
| Feb 28 | 68 | -3 |
Trend: improving (+13 over 30 days)

### Budget (March)
| Metric | Value |
|--------|-------|
| Tokens consumed | 1,234,567 |
| Total cost | $42.18 |
| Cost per task | $1.84 |
| Cost per claim | $0.047 |
| Budget utilization | 67% |

### Agent Utilization
| Agent | Tasks | Avg Time | Idle % | Budget Eff |
|-------|-------|----------|--------|------------|
| researcher | 12 | 24m | 18% | 0.89 |
| writer | 8 | 38m | 34% | 0.76 |
| analyst | 6 | 52m | 22% | 0.71 |
| coder | 15 | 18m | 12% | 0.93 |
```

## Dependencies

- Metrics store (historical data, append-only log)
- `/health` — Health score data
- `/budget` — Budget consumption data
- Agent registry — Agent utilization data
- Pipeline logs — Throughput data
- Knowledge graph — Connection density data
