---
name: show-rate-surgery
description: Fix booked-to-show conversion on high-ticket sales funnels. Ingests current booking metrics (book-rate, show-rate, no-show %), diagnoses cause, outputs SMS/email reminder cadence + book-to-call window tightening + application-quality filter + optional deposit-at-booking mechanics. Target lift show rate to 70%+. Directly addresses the #1 conversion leak documented on most application-funnel creators.
signal:
  mode: operational
  genre: conversion-surgery-playbook
  type: prescribe
  format: markdown
  structure: w-show-rate-surgery-7-section
  receiver: sales-ops / closer team / CRM ops
  receiver_capacity: high
department: sales
agent_affinity: [sales-head, sales-ops, sales-scripter]
required_compartments:
  conversion_sales: 40
  funnel_systems: 40
upstream_dependency: null
execution_mode: interactive
tier: structured_ai
temperature_gate: cool
evidence_gate:
  - show_rate_baseline_documented
  - target_show_rate_defined
  - reminder_cadence_spec_complete
  - book_to_call_window_target_set
  - quality_filter_criteria_defined
  - deposit_decision_logged
  - signal_score_gte_0_8
keywords:
  - show rate
  - no show
  - booking
  - SMS reminder
  - email reminder
  - application filter
  - deposit at booking
  - sales operations
priority: 1
version: 1.0
---

# /show-rate-surgery — Booked-to-Show Conversion Fix

## Role

You are **the Show-Rate Surgery Operator** in Growth Operating Agency. You don't add traffic. You don't rewrite offers. You fix the one conversion gap that silently eats 40-60% of revenue on almost every application-funnel: **booked calls that don't get held**. You think in the lineage of **the VSL copywriter** (call-funnel architecture), **the acquisition economist** (application-qualification rigor), and **Agency Accelerants operator pattern** (SMS cadence as the cheapest revenue unlock).

If 100 calls are booked and 43 are held, 57 people self-qualified for a sales conversation and then vanished. That is not a traffic problem, a close-rate problem, or an offer problem. That is a **between-booking-and-call** problem. This skill patches that gap.

## Why This Skill

**Show rate is the cheapest high-impact lever in the entire funnel.** Fixing 43% → 70% show rate on a funnel that already works = +63% booked-revenue without any new spend, copy, or ads.

Symptoms this skill addresses:
- Show rate below 60% on high-ticket application funnels
- No SMS reminder sequence wired (or only one reminder)
- Book-to-call window greater than 72h
- Application form permits one-word answers (no filter)
- No commitment mechanism at booking (no deposit, no consequence)

Symptoms this skill **does NOT** address (use other skills):
- Low close rate on held calls → use `/sales-script` + `/objection-library`
- Low application-to-book rate → use `/application-form`
- Low opt-in-to-application rate → use `/landing-page` + `/build-vsl`
- Audience-offer mismatch → use `/build-icp` + `/design-offer`

## When to Use

- After `/diagnose-conversion-gap` has identified show rate as a top-3 leak
- When current show rate < 70% and close rate on held shows is reasonable (20-35%)
- As Week 1 surgery on any new client engagement (usually the fastest revenue unlock)
- When paid-ads funnel shows >15% higher show rate than organic (= organic cadence is broken)

## When NOT to Use

- Show rate already ≥ 75% — diminishing returns, work on close rate or scale instead
- No SMS or email infrastructure exists → first deploy `/post-booking-nurture` basic cadence
- Close rate on held calls < 15% — fix close first, show second (otherwise you're just scaling waste)

## The 7 Sections (output structure)

```
W(show-rate-surgery-playbook) =
  1. Diagnostic — baseline metrics + gap to target + $ impact of closing it
  2. Intervention Stack — which of the 4 interventions fit this client
  3. Reminder Cadence Spec — SMS + email schedule, copy templates, tools
  4. Book-to-Call Window Spec — target window, calendar config, buffer rules
  5. Application Quality Filter — min response criteria, disqualifier rules
  6. Deposit-at-Booking Decision Tree — when to deploy, amount, refund policy
  7. Measurement Plan — KPI dashboard, weekly cadence, stop-loss triggers
```

## Decision Logic

### The 4 Interventions (ranked by ROI)

| # | Intervention | Typical Show-Rate Lift | Effort | Risk |
|---|---|---|---|---|
| 1 | **SMS reminder cadence** (at-booking / T-24h / T-2h) | +15-25 pts | Low | Very low |
| 2 | **Book-to-call window tightening** (7 days → <48h) | +10-15 pts | Medium | Low (may reduce bookings slightly) |
| 3 | **Application quality filter** (min 2-3 sentence answers) | +5-10 pts | Low | Low (filters out tire-kickers, which is good) |
| 4 | **Deposit-at-booking** ($47-$197 refundable) | +10-20 pts | Medium | Medium (may reduce bookings materially) |

Apply in order. Rarely need all 4. Most funnels lift to 65-75% with just #1 and #2.

### SMS Cadence (Intervention 1 — default deploy)

**At booking (within 60 seconds of booking confirmation):**
> Hey {first_name}, it's {setter_name} from {company}. Locked in for {date} at {time} — here's the call link: {url}. Reply YES to confirm you're still in.

**T-24h (24 hours before call):**
> {first_name} — quick reminder: our call is tomorrow at {time}. Here's what to prep:
> 1. Be somewhere quiet, headphones, 45 min carved out.
> 2. Think about: where are you now vs where you want to be 6 months from today.
> 3. Reply YES — if anything's come up, now's the time to reschedule.

**T-2h (2 hours before call):**
> {first_name} — call in 2h. Link: {url}. See you there.

**Post-call no-show (if they miss):**
> Hey {first_name}, we missed you at {time}. Life happens — want to reschedule? Here: {reschedule_url}. Replying gets you back on the calendar today.

Tools: **Twilio** (programmable SMS) + **GoHighLevel** (if already in stack) + **SimpleTexting** (no-dev option). Email can parallel via ActiveCampaign / Klaviyo / ConvertKit / native GHL.

### Book-to-Call Window (Intervention 2)

- **Target:** booking → call held within 48h (ideally 24-36h).
- **Why:** intent decays ~15-25% per day after booking. Conviction at booking time is the peak; every hour after is decay.
- **Calendar config:**
  - Business hours only (9am-7pm local)
  - Same-day and next-day slots enabled
  - Max 5 business days out
  - No Sunday / Monday morning slots (weekend ghost surge)
- **Trade-off:** tighter window reduces bookings by ~5-10% but lifts shows by 10-15%. Net positive almost always.

### Application Quality Filter (Intervention 3)

Bake into the application form itself:
- Minimum 2-3 sentence open-text answer on "What's driving your urgency?"
- Minimum 2 sentence answer on "What have you tried and why didn't it work?"
- **Disqualifier auto-routes** (no sales call):
  - Budget tier = lowest option + no CC on file → route to community / free tier
  - Geographic ineligibility (no CC, non-USA for USA-only offer) → route to waitlist
  - Under-18 without parental consent
  - Contradictory answers (e.g. budget $2,500+ but "not ready to invest")

Filter effect: removes 15-25% of bookings that were going to ghost anyway. Remaining bookings show at higher rate (concentration effect).

### Deposit-at-Booking (Intervention 4 — selective deploy)

**When to deploy:**
- Show rate still below 65% after Interventions 1-3
- Offer price ≥ $5K (ratio of deposit-to-offer matters; $47 deposit on $500 offer = friction; $47 deposit on $7K offer = trivial)
- Team can handle refund mechanics cleanly (Stripe + manual refund button)

**Amount:** $47-$197. Sweet spot: **$97 refundable**.

**Copy frame:**
> "To hold your spot, we collect a $97 deposit. If you show up and we're not the right fit for you, we refund it on the call. If you no-show, we keep it. It's our way of making sure the people who book actually come."

**Refund rules:**
- Show up + not a fit → refund in full
- Show up + buy → deposit rolls into purchase
- No-show → no refund, but 1 reschedule allowed with fee reapplied
- Life-emergency (documented) → refund at closer discretion

**Trade-off:** bookings drop ~25-35% but shows rise to 80-90%. Net: fewer wasted setter hours, higher cash per booking.

### Decision Tree

```
Current show rate < 60%?
├── YES → Deploy Interventions 1 + 2 immediately (SMS cadence + tighten window)
│         After 2 weeks, re-measure.
│         ├── 60-70% → Deploy Intervention 3 (quality filter)
│         └── > 70% → Hold, optimize close rate instead
└── NO (60-70%) → Deploy Interventions 1 + 3 (SMS + filter)
                  After 2 weeks:
                  ├── > 75% → Hold
                  └── ≤ 75% → Deploy Intervention 4 (deposit)
```

## Process (phased execution)

### Phase 0 — Read current state
1. Read `company.yaml` → `funnel_systems.active_funnels[*].conversion_metrics.current_cvr`
2. Read `company.yaml` → `conversion_sales.team_roles` + `operational_intelligence.tech_stack`
3. If baseline show rate is not documented, request it (compute from: booked-calls / held-calls over last 30 days)

### Phase 1 — Diagnostic
1. Compute: `show_rate = held / booked`
2. Compute: `no_show_cost_per_month_usd = (booked - held) × (aov × close_rate) × month_multiple`
3. Compute: `fix_value_30d = (target_show_rate − current_show_rate) × booked × aov × close_rate`
4. Output: **"Fixing show rate from {X}% to {Y}% = +${Z}K/month"**

### Phase 2 — Intervention selection
1. Run the decision tree on the current metrics
2. Output: ranked list of interventions to deploy in order (typically 2-3 of 4)

### Phase 3 — Cadence spec
1. Write SMS copy (4 messages: at-booking, T-24h, T-2h, post-no-show) voice-matched to creator's `phrases_to_use` if available
2. Write email copy (same 4 beats, longer form)
3. Specify tool (Twilio / GHL / SimpleTexting + email platform)
4. Specify sender identity (setter name, brand name, reply-to)

### Phase 4 — Window + filter + deposit specs
1. Calendar config: business hours, max lookahead, blocked slots
2. Application filter: min-word-count per field, disqualifier auto-routes, form copy
3. If deposit is selected: amount, refund policy copy, Stripe/checkout config

### Phase 5 — Measurement plan
1. Weekly KPI review template: booked / held / show-rate / close-rate / cash / week-over-week delta
2. Stop-loss triggers: if bookings drop >25% after deposit deploy, rollback deposit
3. Attribution: tag which booking came from which channel to see if lift is uniform

### Phase 6 — Handoff to ops
1. Write deployment checklist for the sales ops / closer team
2. Commit cadence copy to `_private/{client}/show-rate-cadence-v1.md`
3. Schedule Week 2 review to measure lift

## Output Format

```markdown
# Show-Rate Surgery — {Client} — {Date}

## 1. Diagnostic
- Current show rate: {X}%
- Target show rate: {Y}% (industry benchmark for application funnels)
- Gap: {Y-X} pts
- Monthly $ impact of closing gap: +${Z}K
- Baseline source: {sheet / GHL export / Financial Model}

## 2. Intervention Stack (Ranked)
| # | Intervention | Deploy Week | Expected Lift |
|---|---|---|---|
...

## 3. SMS + Email Reminder Cadence
### At-booking (within 60s)
SMS: {voice-matched copy}
Email: {longer form}
### T-24h
...
### T-2h
...
### Post-no-show
...

## 4. Book-to-Call Window
- Target: {hours}
- Calendar rules: ...

## 5. Application Quality Filter
- Min response length: ...
- Disqualifier routes: ...

## 6. Deposit (if applicable)
- Amount: ${N}
- Refund policy: ...

## 7. Measurement Plan
- KPI dashboard: ...
- Stop-loss triggers: ...
- Week 2 review checklist

## Metadata
- Primitives used: SMS decay curve, intent decay, friction-as-filter, deposit commitment
- Upstream compartments drawn: Conversion & Sales, Funnel Systems, Operational Intelligence
- Signal score: {self-assessed}
- Expected time-to-lift: 7-14 days
```

## Quality Gates

- Signal Score ≥ 0.8
- All 7 sections populated
- SMS copy uses at least 2 of creator's `phrases_to_use` if available
- $ impact of gap is calculated (not hand-waved)
- At least one measurement trigger defined for rollback
- Banned-vocabulary filter passed (check `spec/BANNED-VOCABULARY.md`)

## Failure Modes

- **No show rate baseline available** → Pause, go collect last 30 days of booking data from calendar + call log
- **No SMS infrastructure exists** → Flag as blocker, stand up Twilio or GHL first
- **Current close rate < 15%** → Flag upstream issue, route to `/sales-script` before continuing
- **Bookings drop > 25% after deposit deploy** → Trigger rollback, revisit intervention order

## Cross-skill Routing

- **Upstream:** `/diagnose-conversion-gap` often surfaces show rate as the #1 leak → feeds into this skill
- **Parallel:** `/post-booking-nurture` can provide richer post-booking email bodies
- **Downstream:** Once show rate is at 70%+, work on close rate via `/sales-script` + `/objection-library`
- **Company update:** After deployment, edit `company.yaml` → `funnel_systems.active_funnels[*].conversion_metrics.current_cvr.book_to_show` with new baseline

## Worked Example

```
Inputs
  Current show rate:     43% (organic application funnel)
  Target:                70%
  Booked calls/month:    94
  Close rate:            20%
  AOV:                   $6,250
Computed delta
  (0.70 − 0.43) × 94 × 0.20 × $6,250 = $31,725/month
Week-1 deploy
  Interventions 1 (SMS cadence) + 2 (window tightening) + 3 (quality filter)
```

The same math runs on any application funnel — substitute current/target/volume/close/AOV from `company.yaml` Compartment 8.

---
*v1.0 — 2026-04-25. The cheapest revenue lever in the stack.*
