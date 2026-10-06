# Daily Standup Template (15 min)

## Purpose
15-minute synchronous or async check-in to surface progress, plan the day, and expose blockers within 24 hours of emerging.

## Cadence
- **Time**: same time every working day (typical: 09:00 local)
- **Duration**: hard stop at 15 min (use a timer)
- **Format**: standing (in-person), cameras-on (remote), or async-in-Slack if team spans > 6 hours of time zones
- **Scribe**: rotates weekly; notes land in `workflows/operations/standup-log/{YYYY-MM-DD}.md`

## Agenda (3 questions per person, 60–90s each)
1. **Yesterday** — one sentence on what actually moved
2. **Today** — top 1–3 priorities (ranked)
3. **Blockers** — what is stopping you, named with owner

## Metrics Glance (top of standup, 2 min)
| Metric | Today | Yesterday | Trend |
|---|---|---|---|
| New leads | `{n}` | `{n}` | ↑/↓/= |
| Calls booked | `{n}` | `{n}` | ↑/↓/= |
| Calls held | `{n}` | `{n}` | ↑/↓/= |
| Closes | `{n}` | `{n}` | ↑/↓/= |
| Revenue (rolling 7d) | `{$}` | `{$}` | ↑/↓/= |
| Open blockers | `{n}` | `{n}` | ↑/↓/= |

## Fillable Template (async Slack format)
```
Standup — {YYYY-MM-DD} — {team}

METRICS
- Leads today: {n} (7d avg: {n})
- Calls booked today: {n}
- Revenue 7d: ${n}
- Open blockers: {n}

{NAME}
Yesterday: {what shipped}
Today: {top 1-3 priorities}
Blockers: {named blocker + owner requested OR "none"}

{NAME}
Yesterday: ...
...
```

## Sample Filled Standup
```
Standup — 2026-04-19 — Growth Operating Agency Delivery

METRICS
- Leads today: 47 (7d avg: 42) ↑
- Calls booked today: 6
- Revenue 7d: $18,500
- Open blockers: 2

Syed
Yesterday: Shipped VSL v2 script for {CLIENT_NAME}, first cohort traffic live
Today: Review Week 3 cohort data, iteration plan, deliver 2pm review
Blockers: none

Alex
Yesterday: Finalized Q2 positioning revision
Today: Record 2 case-study interviews, draft next launch plan
Blockers: Need Stripe access from client by noon to finish tracking setup — pinged client
```

## Blocker Escalation
- Blocker named today → owner acknowledges within 2h
- Blocker open 48h → escalates to department heads automatically
- Blocker open 96h → escalates to founder + re-scoped

## Anti-patterns (block these)
- Standup longer than 15 min — cut it; route discussions to 1:1s
- "Status update theater" — skip progress that doesn't change anything downstream
- Blocker without named owner — not a real blocker
- Missing standups — 2 consecutive skips triggers retro discussion

## Cross-references
- Weekly rollup: `workflows/execution-templates/weekly-review-template.md`
- Issue escalation: each blocker can trigger `workflows/execution-templates/post-mortem-template.md`

---
*v1.0 — 2026-04-19.*
