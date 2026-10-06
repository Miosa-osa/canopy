# 4-Week Fulfillment Cycle

## Purpose
Standardized 4-week delivery cadence for a typical Growth Operating Agency engagement slice. Each week has a theme, deliverables, calls, checkpoints, and escalation triggers. Weeks compound: Week 4 depends on Week 3 depending on Week 2 depending on Week 1.

## Week-by-Week Overview
| Week | Theme | Primary Deliverables |
|---|---|---|
| 1 | Foundations | ICP, positioning, offer, voice guide |
| 2 | Build | VSL script, funnel pages, email sequences |
| 3 | Launch | Soft launch, traffic-on, first measurement cohort |
| 4 | Optimize | CVR improvements, SOP capture, next-cycle plan |

## Week 1 — Foundations

### Theme
Make the ideal customer, positioning, voice, and offer legible on paper. No building yet.

### Deliverables
- [ ] `research-brief.md` (S/N ≥ 0.8)
- [ ] `icp.md` (one page, named avatar, pain-tier tagged)
- [ ] `positioning.md` (category, enemy, "only-we" statement)
- [ ] `voice-guide.md` (20+ phrases, 10+ signature words, cadence rules)
- [ ] `offer.md` (Value Equation ≥ 150, stack ≥ 3× price)

### Calls
- Monday kickoff (60 min) — scope, success metric, access handoff
- Thursday working session (45 min) — research review, ICP draft walkthrough
- Friday async review — positioning + offer drafts delivered end-of-day

### Checkpoints
- Tue EOD: research brief draft circulated
- Wed EOD: ICP locked
- Thu EOD: positioning locked
- Fri EOD: voice + offer locked, sign-off for Week 2 start

### Escalations
- Missed Tue EOD brief → Thu call becomes recovery session
- ICP fails 90% completeness → Week 2 start delayed, founder informed
- Voice-guide fails blind-author test → escalate to founder's deeper voice-capture session

## Week 2 — Build

### Theme
Convert foundations into conversion assets. VSL, funnel, email. The production-heavy week.

### Deliverables
- [ ] `vsl-script.md` (Sacred-Format 3/3, ≥ 12 mechanism threads, crossroads at 65–75%)
- [ ] Funnel map + all pages built (landing, VSL, booking/checkout, thank-you, SCA)
- [ ] Email sequences: runway (5), daily-during (N), cart-close (3), SCA (3), post-purchase (5)
- [ ] Ad creative v1 (10 assets minimum)
- [ ] Tracking: pixel, server-side, UTM, attribution window set

### Calls
- Monday plan (45 min) — week scope confirmed, script direction chosen (1 of 5 VSL variants)
- Wednesday mid-week (45 min) — VSL draft walkthrough, funnel QA
- Friday end-week (60 min) — full walk-through, go/no-go for soft launch

### Checkpoints
- Tue EOD: VSL draft v1 ready
- Wed EOD: funnel pages visible (all routes clickable, no 404s)
- Thu EOD: email sequences loaded into ESP
- Fri EOD: ad creative loaded, tracking verified, go/no-go decision made

### Escalations
- VSL fails 3/3 sacred format → rewrite Thu, soft-launch delayed to Week 3 Tue
- Tracking verification fails → block launch until server-side attribution proven
- Email deliverability issue (SPF/DKIM/DMARC not passing) → dedicated IP warm-up or switch ESP

## Week 3 — Launch

### Theme
Turn on traffic. Measure. Respond to live data.

### Deliverables
- [ ] Soft launch executed (day 1 traffic-on, monitored hourly for first 8h)
- [ ] First 500-visitor cohort measured across every funnel step
- [ ] CVR dashboard live (`output/delivery/{client}/cvr-dashboard.md`)
- [ ] Issues log with root-cause + fix: `output/delivery/{client}/issues-week-3.md`
- [ ] Daily standup report

### Calls
- Monday launch-prep (30 min) — final checks, kill-switch agreement
- Daily 15-min standup (see `execution-templates/daily-standup-template.md`)
- Wednesday mid-launch review (45 min) — data-first, what to iterate
- Friday review (60 min) — cohort analysis, lessons, Week 4 plan

### Checkpoints
- Mon noon: go-live
- Mon EOD: first 50 visitors in funnel, no blocker issues
- Tue EOD: 200+ visitors, early CVR signals
- Wed EOD: 500+ visitors, step-CVR analysis
- Fri EOD: cohort-level readout

### Escalations
- Funnel break > 30 min → kill traffic, hot-fix, post-mortem
- Cold-visit → lead CVR below 10% → rework landing page headline, re-test within 24h
- VSL watch-through to crossroads < 20% → rewrite first 2 minutes over weekend
- Overall EPC < $0.50 by end of Week 3 → escalate to department heads + founder; replan

## Week 4 — Optimize

### Theme
Capture what worked into SOPs, fix what didn't, hand off a running system.

### Deliverables
- [ ] 2 CVR-improvement iterations shipped with before/after data
- [ ] `output/delivery/{client}/sops/` — SOPs captured for every recurring task
- [ ] Next-30-day plan: `output/delivery/{client}/next-cycle-plan.md`
- [ ] Handoff doc: who owns what, access inventory, support plan
- [ ] Case-study readiness check (if metrics warrant)

### Calls
- Monday optimization plan (45 min) — review Week 3 data, pick iterations
- Wednesday iteration review (45 min) — A/B results, next iteration
- Thursday SOP capture session (90 min) — walk through delivery, capture steps
- Friday handoff call (60 min) — systems handoff, next-cycle plan sign-off

### Checkpoints
- Mon EOD: iteration targets locked (top 2 by impact × effort)
- Wed EOD: iteration 1 shipped + measured
- Thu EOD: iteration 2 shipped + SOPs drafted
- Fri EOD: next-cycle plan signed off, CSAT collected

### Escalations
- CVR improvement < 10% from iterations → root-cause is upstream (offer or audience) → escalate
- Client declines to provide data for case study → move to referral ask instead
- Handoff incomplete → extend engagement 1 week with scoped billing conversation

## Per-Week Operating Rituals (every week)
- **Daily Slack standup** — async, 3 bullets (yesterday / today / blockers)
- **Weekly written report** — Friday EOD, delivered to client, 1 page max
- **Retro note** — internal, 3 bullets (what worked, what didn't, what to change)

## Deliverable Quality Bar
- Every deliverable ships with: purpose, input, output location, owner, metric
- No deliverable "complete" without verification in the client's workspace (not ours)
- Written reports beat verbal updates; verbal updates beat no update

## Cross-references
- Onboarding: `workflows/client-onboarding/week-1.md`, `workflows/client-onboarding/90-day.md`
- Department pipelines: all 7 in `workflows/divisions/`
- Templates: all 7 in `workflows/execution-templates/`
- Automations: all 5 in `workflows/automations/`

---
*v1.0 — 2026-04-19.*
