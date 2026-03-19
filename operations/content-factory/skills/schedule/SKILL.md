# Schedule

## Command
/schedule [--week <date>] [--gaps]

## Purpose
Content calendar management -- view, plan, and identify gaps.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| --week | date | No | Week to view/plan. Default: current week |
| --gaps | flag | No | Highlight gaps in the next 4 weeks |

## Output
Genre: plan
Format: Markdown calendar table

Produces:
1. **Calendar View** -- content scheduled by day, platform, and status
2. **Gap Analysis** (if --gaps): missing slots against target cadence
3. **Pillar Mix** -- balance check across content pillars
4. **Upcoming Deadlines** -- drafts due, reviews due, publish dates

## Agent Activation
- **editor-in-chief** (wave 1): Calendar review, gap identification, priority planning

## Process
```
1. Load current editorial calendar
2. Display scheduled content with status (planned/in-progress/ready/published)
3. If --gaps: compare against target cadence and flag empty slots
4. Check pillar mix balance (60% evergreen, 20% timely, 20% thought leadership)
5. List upcoming deadlines for all in-progress content
```

## Examples
```
/schedule
/schedule --week 2026-04-01
/schedule --gaps
```
