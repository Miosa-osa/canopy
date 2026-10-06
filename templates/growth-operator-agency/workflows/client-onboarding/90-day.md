# Client Onboarding — 90-Day Plan

## Purpose
The first 90 days decide whether a client renews, refers, and becomes a case study. Built around three milestones: 30-day Early Win, 60-day Mid-Review, 90-day QBR. Each has a defined artifact, gate, and renewal/expansion decision.

## The 90-Day Arc
```
Day 0 ─── Week 1 Onboarding (see week-1.md)
Day 1–30 ── Foundations / First Win sprint
Day 30 ─── Early-Win Milestone
Day 31–60 ── Build + Launch sprint
Day 60 ─── Mid-Review Milestone
Day 61–90 ── Optimize + Scale sprint
Day 90 ─── QBR + renewal decision
```

## Milestone 1 — Day 30 Early Win

### Definition
A tangible, visible, client-owned result within 30 days. Never a "we set up the system" internal win — must be something the client can point to and say "that happened because of this engagement."

### Acceptable Early Wins (by engagement type)
- **Foundations engagement**: Offer + positioning + ICP + voice guide shipped; first sales call booked using new positioning
- **Launch engagement**: Launch plan + 50% of assets live + runway audience growing; first waitlist dollar committed
- **Scale engagement**: 2–3 SOPs live + first hire scorecard out + first month revenue report delivered; one operational bottleneck demonstrably gone

### Day-30 Ritual
- [ ] 30-day review call (45 min) — review deliverables, validate Early Win, surface friction
- [ ] Early-Win artifact published to `output/onboarding/{client}/day-30-win.md` with evidence (screenshot, metric, quote)
- [ ] NPS pulse + open-ended "what is working / not working"
- [ ] Next-30-day plan confirmed
- [ ] Expansion signal check: any scope-creep requests or adjacency opportunities

### Day-30 Gate
- Client confirms Early Win in writing (email or signed doc)
- CSAT ≥ 4.5/5
- If gate fails → immediate escalation to department heads + replan

## Milestone 2 — Day 60 Mid-Review

### Definition
Half-way audit. Assess trajectory toward 90-day goal. Adjust pacing, scope, or team. The honest mid-point conversation.

### Day-60 Ritual
- [ ] Mid-review call (60 min) — walk through goal trajectory, metric comparison, pace assessment
- [ ] Written mid-review doc: where we are vs where we said we'd be, gap analysis, corrective actions
- [ ] Risk scan: are there blocking issues we have been avoiding?
- [ ] Renewal/expansion conversation — planted, not closed
- [ ] Case-study consent conversation opened (if trajectory is strong)

### Day-60 Artifact
`output/onboarding/{client}/day-60-mid-review.md` containing:
- **Original goal**: {success_metric} by Day 90
- **Current pace**: ahead / on-track / behind
- **Blockers**: list with owner + resolution date
- **Pivot needed?**: yes/no with rationale
- **Next-30 plan**: final-sprint scope

### Day-60 Gate
- Client and delivery lead both sign off on trajectory diagnosis
- Any pivot explicitly scoped and re-contracted
- If behind, replan presented with realistic Day-90 target

## Milestone 3 — Day 90 QBR (Quarterly Business Review)

### Definition
Formal business review. Scoped outcomes delivered, measured, documented. Decision: renew, expand, off-board cleanly.

### Day-90 Ritual
- [ ] QBR call (90 min) — full review using `execution-templates/client-qbr-template.md`
- [ ] Full written QBR document shipped 24h before call
- [ ] Outcomes vs goals: quantified gap or overage
- [ ] Case-study decision: produce it (`/case-study` triggered) or not
- [ ] Renewal decision: continue / pause / off-board
- [ ] Expansion offer presented if fit
- [ ] Referral ask if CSAT ≥ 4.5 and result achieved

### Day-90 Artifact
`output/onboarding/{client}/day-90-qbr.md` containing:
- Quantified outcomes vs original goals
- Asset inventory (what was built + handed off)
- Team performance assessment (both sides)
- Lessons learned (both sides)
- Renewal + expansion decision with rationale
- Case-study commitment (if applicable)

### Day-90 Gate
- NPS ≥ 50
- Original success metric achieved OR documented why not (and client agrees with diagnosis)
- Renewal decision made (not deferred)

## Expansion + Renewal Decision Matrix
| CSAT | Result | Decision |
|---|---|---|
| ≥ 4.5 | Met / Exceeded | Renew + expansion offer + case-study |
| ≥ 4.5 | Partial | Renew + replan |
| 3.5–4.4 | Met | Renew + address friction |
| 3.5–4.4 | Partial | Pause / reset with clear scope |
| < 3.5 | Any | Off-board cleanly; post-mortem |

## Fillable Template Variables
- `{client_name}`
- `{day_30_win}` — specific, verifiable Early Win
- `{day_60_pace_status}` — ahead / on-track / behind + metric
- `{day_90_outcome}` — quantified achievement
- `{csat_30}`, `{csat_60}`, `{csat_90}` — score + comments
- `{renewal_decision}` — renew / pause / off-board
- `{expansion_sku}` — if applicable

## Sample Filled (Month 3 of Growth Operating Agency engagement)
- `{client_name}`: {CLIENT_NAME} / Alex
- `{day_30_win}`: Positioning + ICP shipped; first 3 cold-sourced demos booked using new "only-we" statement
- `{day_60_pace_status}`: On-track — funnel live, VSL live, 7 of planned 10 demos booked
- `{day_90_outcome}`: $45K in booked engagements from cold funnel + 12 case-study-worthy wins
- `{csat_90}`: 4.8 — "Worth every dollar and then some"
- `{renewal_decision}`: Renew annual + add Scale department engagement
- `{expansion_sku}`: Growth Operating Agency Annual + Scale Add-on

## Escalation Triggers
- CSAT < 4.0 at any milestone → department heads owns recovery
- 2 consecutive missed deliverable dates → founder engaged
- Client unresponsive > 10 days → contract review + outreach sequence
- Original goal drifting > 25% off → replan required

## Cross-references
- Prior: `workflows/client-onboarding/week-1.md`
- Delivery: `workflows/delivery/4-week-fulfillment.md`
- Templates: `workflows/execution-templates/client-qbr-template.md`, `workflows/execution-templates/weekly-review-template.md`
- Skills: `skills/case-study/`, `skills/retention-check/`
- Automation: `workflows/automations/churn-detection.md`, `workflows/automations/referral-trigger.md`

---
*v1.0 — 2026-04-19.*
