# analytics-prompts

Drop-in prompts for interpreting metrics, diagnosing bottlenecks, forecasting. Pair with `/revenue-report`, `/launch-report`, `/retention-check`.

---

## Prompt 1 — Metric interpretation (one number)

```
# Role
A metrics-interpreter. Given one number + context, you return: what the number signals, what it does NOT signal, what to do about it.

# Task
Interpret this number: {{METRIC_NAME}} = {{METRIC_VALUE}} vs benchmark {{BENCHMARK}}.

# Inputs
Metric: {{METRIC_NAME}}
Current value: {{METRIC_VALUE}}
Benchmark: {{BENCHMARK}}
Business stage: {{BUSINESS_STAGE}} (pre-revenue / $10-50K mo / $50-250K mo / $250K-1M mo / $1M+ mo)
Context (what changed recently, if anything): {{RECENT_CONTEXT}}

# Constraints
- Don't over-interpret one number.
- State explicitly what the number cannot tell us.
- Propose the one next data pull that would clarify.

# Output format
- What this signals (2–3 interpretations ranked by likelihood)
- What this does NOT signal
- Confounds (things that could make this number look good / bad that aren't about the thing we care about)
- The one next data pull to clarify
- Recommended action (act / wait / dig)
```

---

## Prompt 2 — Funnel bottleneck diagnostic

```
# Role
A funnel-bottleneck diagnostician. Given the full funnel with stage-by-stage conversion rates, you identify the stage with the biggest gap to benchmark and prescribe the minimal intervention.

# Task
Diagnose the funnel below. Identify the ONE bottleneck stage to fix first.

# Inputs
Funnel stages + current rates vs benchmarks:
| Stage | Current rate | Benchmark |
| Awareness → Click | {{C1}} | {{B1}} |
| Click → Opt-in | {{C2}} | {{B2}} |
| Opt-in → Booked | {{C3}} | {{B3}} |
| Booked → Show | {{C4}} | {{B4}} |
| Show → Pitched | {{C5}} | {{B5}} |
| Pitched → Closed | {{C6}} | {{B6}} |

# Constraints
- Diagnose from the math, not vibes.
- Ignore seductive-but-small gaps (a stage that's 5% below benchmark doesn't matter if another is 40% below).
- Prescribe one intervention, not a laundry list.

# Output format
- Stage with the biggest absolute revenue impact if fixed + the math
- Likely root cause + why
- One intervention + cost + time to ship
- Success criteria (what the metric should move to)
- Measurement window

End with: the stage I'd fix second + sequencing logic.
```

---

## Prompt 3 — Cohort-LTV forecast

```
# Role
A cohort-LTV forecaster. You forecast 12- and 24-month LTV from early-cohort behavior, using retention curves, upsell rates, and referral patterns.

# Task
Forecast 12- and 24-month LTV for the cohort that started {{COHORT_START}}.

# Inputs
Cohort start: {{COHORT_START}}
Cohort size: {{COHORT_SIZE}}
Month-1 revenue: {{M1_REV}}
Month-2 revenue: {{M2_REV}}
Month-3 revenue: {{M3_REV}}
Month-6 revenue (if available): {{M6_REV}}
Upsell / ascension events observed: {{ASCENSION_EVENTS}}
Referral rate observed: {{REFERRAL_RATE}}
Historical cohort retention curve: {{HISTORICAL_CURVE}}

# Constraints
- Show the math.
- Flag the 3 biggest forecast risks.
- Present low / mid / high scenarios.

# Output format
- 12-month LTV: low / mid / high + math
- 24-month LTV: low / mid / high + math
- CAC payback at LTV:CAC = 3:1 (implied)
- 3 biggest risks to the forecast + how to watch for each

End with: the forecast I'd commit to in my model + the check-in metric at month-6 that would prompt a revision.
```

---

## Prompt 4 — Ad-spend allocation optimizer

```
# Role
An ad-spend allocation analyst. Given performance across channels, you recommend budget shifts that move money from losing cells to winning cells — without destroying learning in the losing cells.

# Task
Propose a budget reallocation for next month.

# Inputs
Channel breakdown:
| Channel | Spend | CAC | LTV:CAC | CVR | Fatigue status |
| {{CH1}} | {{S1}} | {{C1}} | {{R1}} | {{V1}} | {{F1}} |
| {{CH2}} | {{S2}} | {{C2}} | {{R2}} | {{V2}} | {{F2}} |
| {{CH3}} | {{S3}} | {{C3}} | {{R3}} | {{V3}} | {{F3}} |

Total budget: {{TOTAL_BUDGET}}
Offer: {{OFFER}}
Target LTV:CAC: {{TARGET_LTV_CAC}}

# Constraints
- Don't cut a channel to zero if it's still learning (unstable statistics).
- Keep a minimum 15% allocation on the single best channel to test ceiling.
- Flag channels where the unit economics are broken (LTV:CAC < 2).

# Output format
| Channel | Old allocation | New allocation | Rationale | Expected effect |
|---|---|---|---|---|

End with: the 1 channel I'd start testing next + the hypothesis + kill criteria.
```

---

## Prompt 5 — Churn diagnostic

```
# Role
A churn diagnostician. You distinguish the 4 churn types — payment, disengagement, outcome, community — and prescribe different interventions for each.

# Task
Diagnose recent churn. Classify, identify drivers, prescribe interventions.

# Inputs
Churn events last 30 days:
| Client | Tenure | Spend | Reason stated | Pre-churn behavior |
| {{C1}} | {{T1}} | {{S1}} | {{R1}} | {{P1}} |
| {{C2}} | {{T2}} | {{S2}} | {{R2}} | {{P2}} |

Typical tenure: {{TYPICAL_TENURE}}
Offer: {{OFFER}}

# Constraints
- Classify each event.
- Identify the dominant driver.
- Prescribe intervention that prevents the dominant driver, not a generic "retention push".

# Output format
| Client | Churn type | Driver | Prevention signal (what we should have caught earlier) | Intervention |
|---|---|---|---|---|

End with: the 1 early-warning signal I should now track on all active clients + how to capture it.
```

---

## Prompt 6 — Revenue-forecast reality check

```
# Role
A forecast-critic. You take a revenue forecast and stress-test it: show the numbers that have to be true for the forecast, flag the ones that are ambitious vs achievable.

# Task
Stress-test my forecast.

# Inputs
Forecast (next-quarter revenue target): {{FORECAST}}
Current-quarter run rate: {{CURRENT_RATE}}
Planned levers (launches, hires, ad scale, new offer, pricing change): {{PLANNED_LEVERS}}
Historical hit rate on forecasts: {{HIT_RATE}}

# Constraints
- Show every assumption behind the forecast.
- Rank assumptions by risk × impact.
- Propose the specific observation that tells me I'm on track.

# Output format
- Assumptions list (minimum 8)
- Top 3 risk assumptions + how to watch for them
- Month-by-month milestones (what revenue at the end of each month means the forecast is on track)
- Kill criteria (what would make me re-forecast)

End with: my honest confidence level in the forecast (low / medium / high) + the one change that would most improve confidence.
```

---

## Prompt 7 — Launch retrospective scorer

```
# Role
A launch-debrief analyst. You read a launch's numbers and produce a scored retrospective across: traffic, opt-in, show, pitch, close, operations, retention.

# Task
Score my recent launch. Identify top-3 wins and top-3 lessons.

# Inputs
Launch period: {{START_TO_END}}
Traffic driven: {{TRAFFIC}}
Opt-ins: {{OPT_INS}}
Show rate: {{SHOW_RATE}}
Pitched rate: {{PITCHED_RATE}}
Close rate: {{CLOSE_RATE}}
Revenue closed: {{REVENUE}}
Revenue target: {{REVENUE_TARGET}}
Refunds in first 30 days: {{EARLY_REFUNDS}}
Operational issues: {{OPS_ISSUES}}
Team member feedback: {{TEAM_FEEDBACK}}

# Constraints
- Score each dimension 1–5 + evidence.
- Wins and lessons must be concrete, not vague.

# Output format
| Dimension | Score (1-5) | Evidence | Lesson |

Top-3 wins to replicate.
Top-3 lessons to address.
One-sentence overall verdict (green / yellow / red).

End with: the 1 structural change I'd make to the next launch based on this retrospective.
```

---

## Prompt 8 — Unit-economics snapshot

```
# Role
A unit-economics analyst. You produce a one-page economic snapshot: CAC by channel, LTV 12-mo and 24-mo, gross margin, contribution margin, payback period, break-even timeline.

# Task
Produce the unit-economics one-pager.

# Inputs
Revenue last 90 days (by channel): {{REVENUE_BY_CHANNEL}}
Ad spend (by channel): {{AD_SPEND_BY_CHANNEL}}
Customer count (by channel): {{CUSTOMERS_BY_CHANNEL}}
12-mo retained revenue per cohort (historical): {{HISTORICAL_12MO}}
Cost of delivery (coach time, fulfillment, tools): {{COST_OF_DELIVERY}}
Fixed overhead: {{FIXED_OVERHEAD}}

# Constraints
- Show the math.
- Present by channel + blended.
- Flag channels with LTV:CAC < 3.

# Output format
| Channel | CAC | 12-mo LTV | LTV:CAC | Gross margin | Payback period |
| ... |

Blended totals.
Break-even monthly customer count.
The 1 channel where economics are strongest.
The 1 channel where economics are broken.

End with: the 1 operational change that would most improve blended LTV:CAC + the timeline.
```

---

## Prompt 9 — Leading-indicator dashboard design

```
# Role
A dashboard designer. You know that revenue is a lagging indicator; you design dashboards on leading indicators that predict revenue 30–60 days ahead.

# Task
Design a dashboard of 5–7 leading indicators that predict my revenue 30–60 days out.

# Inputs
Current funnel: {{FUNNEL_STAGES}}
Current lagging indicators tracked: {{LAGGING_INDICATORS}}
Offer + sales cycle length: {{OFFER_AND_CYCLE_LENGTH}}
Team roles + KPIs: {{TEAM_ROLES_KPIS}}

# Constraints
- Indicators must be observable daily or weekly, not monthly.
- Each indicator has a clear threshold (green / yellow / red).
- No vanity metrics.

# Output format
| # | Leading indicator | Frequency | Green threshold | Yellow threshold | Red threshold | Predicts |
|---|---|---|---|---|---|---|

End with: the 1 indicator that would most upgrade my weekly review + where to pull it from.
```

---

## Prompt 10 — Kill-criteria protocol

```
# Role
A disciplined stop-loss designer. You help creators kill experiments, ads, funnels, and product lines before they drain runway.

# Task
Design kill-criteria for my experiment / ad / funnel / product.

# Inputs
Experiment name: {{EXPERIMENT}}
Expected outcome: {{EXPECTED_OUTCOME}}
Current spend / time invested: {{INVESTMENT}}
Decision maker: {{DECISION_MAKER}}
How long to run before a kill call: {{DURATION}}

# Constraints
- Kill criteria are pre-committed, not debated mid-experiment.
- Include both performance criteria and time criteria.
- Include sunk-cost checks.

# Output format
- Performance kill threshold (the metric value at which we stop)
- Time kill threshold (how long we run before calling it)
- Sunk-cost check (the question we ask before extending)
- Post-mortem template (the debrief questions if we kill)
- Succession plan (what we try next, with what budget)

End with: the emotional pre-commit I should make now (to not renegotiate the kill criteria when the moment comes).
```

---
*v1.0 — drop-in prompts for analytics and diagnostics. Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
