# Post-Mortem Template

## Purpose
Incident post-mortem. Used when something breaks in a way that materially affects customers, revenue, or trust. The goal is systemic prevention, not blame. Every post-mortem produces at least one durable change.

## When to Run
- Customer-facing outage > 15 min
- Revenue loss > $1K (hard cost) OR > $5K (opportunity cost)
- Trust-damaging incident (wrong email to full list, double-charges, etc.)
- Safety / compliance breach (GDPR, FTC, platform ToS)
- Repeat incident (3rd occurrence of same pattern)

## Timeline
- **T+0 to T+24h**: Incident resolved, owner logs raw notes
- **T+48h**: Post-mortem meeting scheduled (90 min)
- **T+5 days**: Written post-mortem published
- **T+14 days**: Corrective actions implemented (or re-scoped)

## Attendees
- Incident commander (ran the response)
- People directly involved (max 5)
- One domain expert outside the incident (for questions)
- Founder reads the doc; attends only for trust-damaging or > $10K incidents

## Blameless Principle
We assume everyone did what seemed correct with the information they had. The goal is to identify systemic gaps: missing monitoring, ambiguous SOPs, unclear ownership, latent brittle systems. Blame is a shortcut that stops learning.

## Document Structure

### 1. Summary (≤ 5 sentences)
What happened. When. Who was affected. How it was resolved. Top corrective action.

### 2. Timeline
Minute-by-minute (or hour-by-hour) reconstruction. Include:
- T+0: trigger event
- Every subsequent event (detection, escalation, hypothesis, action, validation)
- T+resolution: fix verified
All times in UTC, local time in parentheses.

### 3. Impact
- Customers affected: `{n}` ({%} of total)
- Revenue loss: `{$}` direct, `{$}` opportunity
- Duration: `{n}` minutes
- External visibility: `{who saw this outside the team}`
- Trust impact: `{none / moderate / severe}` with reasoning

### 4. Root Cause (5 Whys minimum)
Don't stop at the proximate cause.
- Why did X happen? Because Y.
- Why did Y happen? Because Z.
- ...
- Iterate until you hit a systemic cause (missing process, missing alert, untested path, ambiguous ownership).

### 5. What Went Well
Things that worked during the response. Often: good detection, fast escalation, clean communication, accurate post-incident comms.

### 6. What Went Poorly
Specific failures during detection, response, or communication. Not people. Process / tooling / docs.

### 7. Where We Got Lucky
The things that prevented this from being worse. These are usually your next fragile points.

### 8. Corrective Actions
| Action | Type | Owner | Due |
|---|---|---|---|
| `{what}` | prevent / detect / mitigate | `{name}` | `{date}` |
| ... | ... | ... | ... |

- **Prevent** actions stop recurrence of this exact cause
- **Detect** actions reduce time-to-detection for this class
- **Mitigate** actions reduce impact if it recurs

Minimum: 1 prevent + 1 detect. Often: add 1 mitigate.

### 9. Lessons
Short list of takeaways that should outlive this incident. These go into the permanent playbook / SOP.

## Fillable Template
```
POST-MORTEM: {title}
Incident date: {YYYY-MM-DD}
Commander: {name}
Authored by: {name}
Status: draft | reviewed | published
Published: {date}

SUMMARY
{5 sentences or fewer}

TIMELINE (all times UTC)
T+0 {HH:MM} — {event}
T+{n}m {HH:MM} — {event}
...
T+resolution — {verification}

IMPACT
Customers affected: {n}
Revenue loss: direct ${n}, opportunity ${n}
Duration: {n} minutes
External visibility: {description}
Trust impact: {none/moderate/severe}

ROOT CAUSE
{5+ whys walking from proximate to systemic}

WENT WELL
- ...

WENT POORLY
- ...

GOT LUCKY
- ...

CORRECTIVE ACTIONS
| Action | Type | Owner | Due |
|---|---|---|---|
| ... | ... | ... | ... |

LESSONS
- ...
```

## Sample Filled Post-Mortem (abbreviated)
```
POST-MORTEM: Cart Outage During Launch Day 0
Incident date: 2026-04-14
Commander: {COMMANDER}
Authored: {AUTHOR}
Status: published
Published: 2026-04-19

SUMMARY
On launch day 0 at 18:00 UTC (11:00 PT), the Stripe checkout endpoint returned 503 errors for 22 minutes during peak traffic. We estimate 47 purchase attempts failed. Approximately $12K in revenue was at risk; $9K of it was recovered via a triggered SCA sequence. We have added a failover payment processor and a checkout health-check alert as corrective actions.

TIMELINE
T+0 18:00 — Stripe returns first 503 (noticed in error logs 2 min later)
T+2m 18:02 — Alert fires; commander paged
T+5m 18:05 — Stripe status page shows incident; commander decides not to halt traffic
T+12m 18:12 — Commander drafts internal comms + triggers SCA sequence mid-launch
T+22m 18:22 — Stripe returns healthy; manually verified with test transaction
T+30m 18:30 — Internal all-clear + public status note pre-drafted (not needed; no customer complaint surfaced)
T+48h — SCA sequence recovered 31 of the 47 attempts ($9K)

IMPACT
Customers affected: 47 failed checkouts during window
Revenue loss: $3K direct (unrecovered), $0 opportunity (rest recovered)
Duration: 22 min
External visibility: 6 customer-support tickets, all resolved within 24h
Trust impact: moderate — we owe follow-up email to 16 affected customers

ROOT CAUSE
- Why did checkouts fail? Stripe 503'd.
- Why did we have only one processor? We never contracted a failover.
- Why didn't we? Launch pre-flight checklist in our current launch SOP does not require failover — only primary processor test.
- Why not? SOP was built before we had > $10K launch days.
- Why wasn't it updated? We haven't audited the launch SOP against our current revenue band.

Systemic cause: SOPs are not on an audit cadence tied to revenue threshold.

WENT WELL
- Alert fired in 2 min (detection working)
- Commander made quick judgment call not to halt traffic (right call in retrospect)
- SCA sequence recovered 66% of at-risk revenue

WENT POORLY
- No failover processor (preventable with 2 days of setup)
- No checkout health-check (only error-log alert, which had 2 min latency)
- Internal comms were ad-hoc; no pre-drafted template

GOT LUCKY
- Stripe's outage was short (22 min). A 2-hour outage would have been catastrophic.
- SCA sequence happened to be already warm from prior use; had it been cold, recovery would have been much lower.

CORRECTIVE ACTIONS
| Action | Type | Owner | Due |
|---|---|---|---|
| Contract failover payment processor (Braintree) | prevent | Syed | 2026-05-05 |
| Add checkout synthetic health-check (every 60s) | detect | Syed | 2026-04-25 |
| Pre-drafted incident comms template | mitigate | Alex | 2026-04-30 |
| Launch SOP audit quarterly (against revenue band) | prevent | Alex | 2026-05-15 |

LESSONS
- At $10K+ launch days, single-point-of-failure in payment is a material risk
- SOPs must have scheduled audits tied to revenue band (see the VSL director thresholds)
- SCA sequence warmth is a launch-day asset; keep it active between launches
```

## Anti-patterns (block these)
- Blame-focused post-mortem ("X screwed up") — systemic prevention is the goal
- Corrective actions without owners / dates — no change happens
- Only 1-2 "whys" — stops before hitting systemic cause
- Post-mortem not published — lessons die; pattern repeats
- Actions overdue and never chased — defeats the purpose

## Cross-references
- Templates: `workflows/execution-templates/rfc-decision-template.md`, `workflows/execution-templates/runbook-template.md`
- Incident response: `workflows/operations/` ledger
- Knowledge: `reference/knowledge/launch.md` (launch SOPs), `reference/knowledge/scale.md` (SOP audits)

---
*v1.0 — 2026-04-19.*
