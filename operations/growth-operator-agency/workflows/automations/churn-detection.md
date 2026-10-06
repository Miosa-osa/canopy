# Automation — Churn Detection

## Purpose
Detect pre-churn signals early, route an intervention before cancellation, and document the outcome for lifecycle learning. Target: catch 80%+ of at-risk customers at least 14 days before cancellation intent forms.

## Trigger Conditions
Any of the following cause a health-score drop:
- **Inactivity**: no login / no portal activity for `{n}` days (varies by product)
- **Engagement drop**: email open-rate falls > 50% from baseline for the customer
- **Usage drop**: key action count drops below threshold (e.g., < 2 calls/month booked in our service)
- **Support signal**: ≥ 2 support tickets in 30d OR NPS ≤ 6 in most recent survey
- **Payment issue**: failed payment, card-declined, dispute opened
- **Explicit signal**: customer asks about cancellation or pause

Health-score drop ≥ 2 tiers (e.g., Green → Yellow is fine; Green → Red is a trigger) fires the automation.

## End-State
- Health-score updated
- Intervention routed within 48h
- Owner assigned, SLA clock started
- Outcome logged: saved / downgraded / churned
- Lesson captured for future cohorts

## Flow Diagram
```
[Health-score calculated nightly]
      │
      ▼
[Score change detected]
      │  no change ──► [Continue normal cadence]
      ▼
[Drop >= 2 tiers?]
      │  no ──► [Log + watch]
      ▼
[Categorize risk]
      │
      ├── Inactivity → Re-engagement sequence
      ├── Engagement drop → Value-add outreach
      ├── Usage drop → CS 1:1 call
      ├── Support signal → CS + delivery lead call
      ├── Payment issue → Billing recovery
      └── Explicit signal → Save call (founder or delivery lead)
      ▼
[Intervention executes within 48h]
      │
      ▼
[Outcome tracked at T+14 days]
      │
      ├── Saved (score recovered) → log learning
      ├── Downgraded (smaller tier) → log + continue
      └── Churned → exit interview + post-mortem
```

## Step-by-Step

**Step 1. Nightly Health-Score Calculation**
- Runs at 02:00 UTC daily
- Pulls: login activity, email engagement, usage events, support ticket count, NPS, billing status
- Computes weighted score (configurable per product) and tier assignment (Green ≥ 75, Yellow 50–74, Red < 50)
- Writes to `output/scale/retention/health-{YYYY-MM-DD}.csv`

**Step 2. Detect Score Change**
- Compare today's tier to yesterday's
- If drop ≥ 2 tiers (Green→Red) or persistent Yellow for 14 days → trigger intervention

**Step 3. Categorize Risk + Route**
| Risk Type | Primary Signal | Intervention | Owner | SLA |
|---|---|---|---|---|
| Inactivity | No login > N days | Re-engagement email sequence (3 emails, 7 days) | CS | 24h |
| Engagement drop | Open rate < 50% of baseline | Value-add personal email | CS | 48h |
| Usage drop | Key action < threshold | Scheduled 30-min CS call | CS lead | 48h |
| Support signal | ≥ 2 tickets / NPS ≤ 6 | CS + delivery lead joint call | Delivery lead | 24h |
| Payment issue | Failed payment | Billing recovery sequence + call | Ops | 24h |
| Explicit signal | "how do I cancel" / "pause" | Founder or delivery lead save call | Delivery lead | 24h |

**Step 4. Intervention**
- Relevant sequence fires OR call booking link sent to owner
- Context packet delivered to owner: customer summary, health-score history, recent signals, product usage
- Owner documents outcome within 24h of action

**Step 5. Outcome Measurement (T+14d)**
- Re-run health-score
- Saved: score recovered to prior tier for ≥ 7 days
- Downgraded: customer moved to smaller plan (partial save)
- Churned: cancellation confirmed

**Step 6. Learning Capture**
- On churn: short exit interview (5 questions)
- Pattern tracking: root cause tagged (onboarding-failure / fit-mismatch / product-gap / pricing / competitor / life-event / unknown)
- Quarterly churn-pattern review feeds back to foundations (ICP), sales (qualification), product/service (delivery)

## Fillable Config
```yaml
score_calculation_time_utc: '02:00'
tiers:
  green_min: 75
  yellow_min: 50
  red_min: 0
triggers:
  multi_tier_drop: 2
  persistent_yellow_days: 14
  nps_threshold: 6
  support_ticket_window_days: 30
  support_ticket_threshold: 2
  payment_failure: true
inactivity_threshold_days:
  growth_os: 7
  launch_package: 14
  sop_library: 30
interventions:
  inactivity_sequence: reengagement-3x7d
  engagement_drop_owner: {cs_email}
  usage_drop_owner: {cs_lead_email}
  support_owner: {delivery_lead_email}
  payment_sequence: billing-recovery-3x3d
  explicit_signal_owner: {founder_email}
outcome_window_days: 14
```

## Sample Filled
```yaml
score_calculation_time_utc: '02:00'
tiers:
  green_min: 75
  yellow_min: 50
  red_min: 0
triggers:
  multi_tier_drop: 2
  persistent_yellow_days: 14
  nps_threshold: 6
  support_ticket_window_days: 30
  support_ticket_threshold: 2
  payment_failure: true
inactivity_threshold_days:
  growth_os: 7
  launch_package: 14
  sop_library: 30
interventions:
  inactivity_sequence: reengagement-3x7d
  engagement_drop_owner: cs@example.com
  usage_drop_owner: ops@example.com
  support_owner: ops@example.com
  payment_sequence: billing-recovery-3x3d
  explicit_signal_owner: founder@example.com
outcome_window_days: 14
```

## Failure Modes + Handling
| Failure | Detection | Response |
|---|---|---|
| Health-score job fails | Cron alert | Retry; escalate if 2 consecutive failures |
| Intervention SLA missed | 48h check | Escalate to department heads |
| Too many simultaneous triggers | CS queue overflow | Ops rebalances; add headcount if structural |
| False positive (score drop but customer healthy) | Outcome check | Tune weights; log for review |
| Churn without prior health-drop signal | Pattern | Critical — root-cause the missed signal, add indicator |

## Compliance / Care
- Interventions are not sales. Recovery conversations lead with diagnosis, not offer.
- If customer asks to cancel, honor it within the SLA — even if save call hasn't happened
- Exit interviews are optional for the customer; never coercive

## KPIs
- Churn prediction accuracy (target: ≥ 80% of churns preceded by trigger)
- Intervention SLA adherence (target: ≥ 95%)
- Save rate (target: ≥ 35% of interventions convert to saved)
- Downgrade rate (partial save target: ≥ 20%)
- Root-cause diversity (target: no single cause > 50% of churn; concentration = underlying problem)
- Monthly churn (target: ≤ 5%)

## Cross-references
- Skill: `skills/retention-check/`
- Pipeline: `workflows/divisions/scale-pipeline.md`
- Knowledge: `reference/knowledge/scale.md` (the operations director 60/30/10)
- Related: `workflows/automations/purchase-to-onboarding.md` (onboarding quality affects this)

---
*v1.0 — 2026-04-19.*
