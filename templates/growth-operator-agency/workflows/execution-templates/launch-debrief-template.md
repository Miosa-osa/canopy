# Launch Debrief Template

## Purpose
Post-launch debrief (also called launch post-mortem). Fills `/launch-report` Phase-5 deliverable. Forces honest diagnosis of what worked, what didn't, and what the next cycle will change.

## When to Run
- **Timing**: Days N+1 to N+7 after cart close (let SCA + refunds settle)
- **Duration**: 2h live session + async writeup
- **Attendees**: launch director, founder, marketing lead, nurture lead, sales lead, ops
- **Facilitator**: non-launch-director (removes bias)
- **Output**: `output/launch/launch-report-{cycle}.md`

## Section 1 — Headline Numbers
| Metric | Target | Actual | Delta |
|---|---|---|---|
| Total revenue | `{$}` | `{$}` | `{%}` |
| Total units sold | `{n}` | `{n}` | `{%}` |
| AOV | `{$}` | `{$}` | `{%}` |
| CVR (traffic → buyer) | ≥ 2% | `{%}` | `{%}` |
| CAC | ≤ 1/3 price | `{$}` | — |
| Refund rate | ≤ 5% | `{%}` | — |
| NPS day-7 | ≥ 50 | `{n}` | — |
| Open-cart 48h share | 30–40% | `{%}` | — |
| Close-cart 24h share | 40–50% | `{%}` | — |
| SCA recovery | ≥ 15% | `{%}` | — |

## Section 2 — Phase-by-Phase Review

### Phase 1 — Pre-Launch Prep
- What was ready on time: `{items}`
- What slipped: `{items}` — cause: `{cause}`
- Tech checklist result: `{pass / partial + missing}`

### Phase 2 — Runway
- Waitlist growth: `{n}` ({projection})
- Pre-launch content engagement: `{metric}` vs baseline
- Email open rate: `{%}` (target ≥ 35%)
- Runway red flag missed? `{yes/no + details}`

### Phase 3 — Launch Day
- Launch executed on-time? `{yes/no}`
- Open-cart 48h revenue: `{$}` ({% of total})
- Tech incidents: `{count + duration + resolution}`
- Peak hour throughput: `{units/hr}`

### Phase 4 — Dead Middle Sustain
- Emails/day shipped: `{n}` vs `{plan}`
- Scheduled spikes executed: `{n}/{planned}`
- Mid-cycle CVR change: `{delta}`
- Retarget ads performance: `{CTR, EPC}`

### Phase 5 — Close + Post-Close
- Close-cart 24h revenue: `{$}` ({% of total})
- Extension request? `{yes/no}` — if yes, why and decision
- SCA recovery: `{%}` ({$ captured})
- Refunds: `{n}` ({%}) — pattern/reason

## Section 3 — Attribution
Revenue by source:
| Source | Revenue | % of Total | CAC |
|---|---|---|---|
| Organic social | `{$}` | `{%}` | `{$}` |
| Paid ads | `{$}` | `{%}` | `{$}` |
| Email list (owned) | `{$}` | `{%}` | — |
| Affiliate / JV | `{$}` | `{%}` | `{%}` rev-share |
| Direct / other | `{$}` | `{%}` | — |

## Section 4 — What Worked
3–5 items with evidence.
1. `{thing}` — evidence: `{metric/quote/screenshot}` — keep for next cycle
2. ...

## Section 5 — What Didn't Work
3–5 items with root cause + owner + fix.
1. `{thing}` — root cause: `{cause}` — fix for next cycle: `{action}` — owner: `{name}`
2. ...

## Section 6 — Biggest Surprise
One paragraph. The thing no one predicted. Insight quality often lives here.

## Section 7 — Next-Cycle Decisions
Binding decisions for the next launch cycle. Each with owner + date.
- Decision: `{what}` — rationale: `{why}` — owner: `{name}` — implementation by: `{date}`

## Section 8 — Route-To Downstream Departments
Which departments receive which lessons:
- Foundations: `{offer/positioning refinement}`
- Marketing: `{creative performance, top angle, top hook}`
- Nurture: `{sequence CVR, which email drove bookings}`
- Sales: `{VSL watch-through, crossroads performance}`
- Scale: `{ops / CS lessons}`
- Partnerships: `{partner performance + re-promote pipeline}`

## Sample Filled Debrief (abbreviated)
```
Launch Debrief — Q1-2026 Cohort Launch ({CLIENT_NAME} Growth Operating Agency)

HEADLINE
- Total revenue: $142K (target $150K, -5%)
- Units: 14 (target 15)
- AOV: $10,150
- CVR: 2.3%
- CAC: $2,400 (target <$3,380)
- NPS day-7: 62

WORKED
1. Crossroads-close video variant drove 38% watch-through (baseline 28%)
2. JV webinar with Partner X produced $52K (37% of total) — re-book for next cycle
3. SMS during close-cart 24h captured $18K extra vs email-only baseline

DIDN'T WORK
1. Runway webinar #2 had 14% show-rate (target 40%) — root cause: email sequence sent webinar link 3 days early, audience forgot — fix: consolidate webinar reminders to 48h + 4h + 30min — owner: {OWNER}
2. Dead-middle day-4 email dip (12% open rate vs 32% baseline) — root cause: subject-line too salesy — fix: value-led subject line tests — owner: {OWNER}
3. Tech: checkout flickered at 18:00 UTC Day 0, 22 min downtime — owner: {OWNER} to add failover processor

SURPRISE
The "bonus reveal" on Day 5 recovered 6 sales we had written off. Next cycle: plan bonus reveals Day 3 AND Day 5 (not only Day 5).

NEXT-CYCLE DECISIONS
- Failover payment processor live before next cycle — {OWNER} — by 2026-05-15
- Webinar reminder sequence rework — {OWNER} — by 2026-05-01
- JV partner Y approached for next cycle — {OWNER} — by 2026-05-10
- Bonus reveal cadence: Day 3 + Day 5 — {OWNER} — by next cycle
```

## Anti-patterns (block these)
- Debrief skipped ("we are too busy for next one") — highest-ROI hour of the cycle
- Blame-heavy debrief — root cause not owner-blame
- Decisions without owners / dates — generates no change
- Wins-only or misses-only report — both distort future decisions

## Cross-references
- Pipeline: `workflows/divisions/launch-pipeline.md`
- Skill: `skills/launch-report/`
- Templates: `workflows/execution-templates/post-mortem-template.md`

---
*v1.0 — 2026-04-19.*
