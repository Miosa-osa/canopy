# Evergreen Automation Launch — Archetype Playbook

> **When it wins:** Always-on funnel replacing one-time cart launches. Scales via paid spend. Predictable daily / weekly revenue rather than quarterly bursts. Most VSL + tripwire + webinar funnels eventually evolve here.

## When to pick this archetype

- You have a VSL / webinar / application funnel with proven unit economics (LTV:CAC ≥ 3:1 on multiple cohorts).
- You want daily / weekly revenue, not quarterly bursts.
- Delivery model supports rolling enrollment (on-demand or near-continuous cohort starts).
- You have ad-buying capacity to sustain ongoing spend.
- Team can support continuous sales / onboarding / retention, not just burst windows.

## Phase 1 — Pre-Launch (weeks -6 to -1)

### Week -6 to -4: Evergreen design
- Choose the core funnel (VSL / webinar / application / tripwire)
- Design evergreen mechanics: how does urgency work (countdown timer, limited seats, bonus expiration, etc.) without cohort start date?
- Design rolling onboarding: how do buyers onboard without live group kickoff?
- Design delivery: on-demand modules, async community, live office-hours cadence
- Revenue model: how does LTV compound across new buyers arriving any day?

### Week -4 to -2: Asset production
- Funnel pages live + mobile-tested + conversion-optimized
- Automated email sequences (welcome, nurture, cart, cart-close, onboarding, retention)
- Evergreen webinar recorded (if webinar-based) OR VSL polished (if VSL-based)
- Deadline funnel tech configured (per-visitor countdown, NOT global)
- Attribution / analytics wired up (cohort tracking, source attribution)
- Onboarding automation tested end-to-end

### Week -2 to -1: Traffic setup
- Ad account structured (Meta / YouTube / TikTok / Google)
- Initial creative tested on small budget ($500–$2K)
- Winning variants promoted to larger daily spend
- Retargeting pixels firing correctly
- Paid spend daily cap set + budget pacing configured

## Phase 2 — Launch (Day 1 — evergreen-on)

### The day you turn spend on
- Scaling starts small: Day 1 spend 20% of target daily budget
- Monitor: CPM, CPC, CTR, landing CVR, opt-in rate, cart CVR
- Any red-flag metric (CPA 3× above target) → pause, diagnose, fix

### First 7 days
- Daily scaling based on CPA holding stable
- Creative fatigue watch: ad frequency per unique > 3 is warning signal
- New creative variants in rotation (target 3–5 new ads per week)
- Daily closes reviewed; refund / chargeback early signals watched

### First 30 days
- Scale to target daily budget
- Cohort LTV tracking begins (earliest real LTV signals at 30–60 days)
- Retargeting sequences optimized
- Exit-intent / cart-abandon sequences launched

## Phase 3 — Momentum (weeks +4 through +12)

### Scaling discipline
- Budget increases only when CPA holds for 7+ consecutive days
- No more than 20% daily budget increase week-over-week
- Creative refresh cadence: 3–5 new variants per week minimum
- Angle tests: every 2–4 weeks try a new messaging angle

### Funnel iteration
- Every 30 days: audit each stage CVR vs benchmark
- Fix the bottleneck (single weakest stage) before touching others
- A/B test isolated variables: hook / thumbnail / landing headline / stack slide

### Retention + ascension
- Weekly review: cohort retention at 7 / 30 / 60 / 90 days
- Monthly review: ascension rate from core offer to higher-tier offer
- Quarterly review: LTV trend (stable / growing / declining)

## Phase 4 — Follow-Up (ongoing per-cohort)

Not a "last 24 hours" phase; evergreen means each buyer has their own cart window.

### Per-buyer lifecycle
- Welcome (immediate + 24-hour + 72-hour)
- First-win engineering (days 1–14)
- Milestone engagement (day 30, day 60, day 90)
- Ascension trigger when ready

### Non-closer lifecycle (per prospect)
- Abandon cart → retargeting sequence (14 days)
- Browsed / watched but didn't buy → nurture sequence (30 days)
- Old leads → quarterly re-engage

## Phase 5 — Analyze (monthly / quarterly)

### Monthly rhythm
- Funnel-stage CVR report
- Channel / creative performance report
- CAC / LTV trend
- Refund / chargeback analysis
- Support-ticket pattern review

### Quarterly rhythm
- Full `/launch-report` equivalent but covering the 90-day period
- Unit-economics deep-dive
- Offer-iteration decisions
- Team capacity review
- Competitive scan

## Communication rhythm (evergreen)

| Channel | Cadence |
|---|---|
| New buyer welcome | Automated, triggered |
| Onboarding sequence | Automated, 5–10 emails over 14 days |
| Retention touch | Automated, week 4 / 8 / 12 |
| Ascension trigger | Behavioral-based; usually between day 30 and day 90 |
| Broadcast list updates | Monthly or bi-weekly to engaged buyers |
| Community activity | Ongoing (see `community-lead-magnet-funnel.md`) |

## Asset checklist (evergreen-specific)

- [ ] Core funnel CVR ≥ benchmark on 100+ conversions
- [ ] Per-visitor countdown timer (Deadline Funnel or equivalent)
- [ ] Automated email sequences (welcome / nurture / cart / cart-close / onboarding)
- [ ] Retargeting pixels + sequences
- [ ] Attribution tracking (server-side preferred at scale)
- [ ] Creative library (20+ variants minimum at scale)
- [ ] Onboarding automation (no human-in-loop for buys under $5K)
- [ ] Support tooling + SLA (inbound volume grows with spend)
- [ ] Refund / chargeback monitoring + response

## Metrics dashboard (evergreen)

| Metric | Target | Red flag |
|---|---|---|
| Daily CPA | $X (offer-dependent) | > 1.5× target |
| Daily revenue | Spend × LTV:CAC / 30 | Missing target 2 days running |
| Ad frequency per unique | < 3 | > 4 |
| 30-day cohort LTV | Hold within 10% of baseline | Declining 3 weeks running |
| Refund rate | < 5% | > 8% |
| Ascension rate 90-day | ≥ baseline | Declining month-over-month |

## Common failure modes

1. **Scaling too fast.** Doubling spend in 3 days → CPA breaks. Fix: 20% daily increase max.
2. **Creative fatigue.** Same ad for 4 weeks → CTR drops → CPA rises. Fix: 3–5 new variants weekly.
3. **Funnel-stage optimization without measurement.** "We changed the landing headline and revenue dropped." Fix: single-variable testing with 100+ conversions per variant before declaring winner.
4. **Onboarding automation cold / robotic.** Evergreen buyers feel like a number. Fix: humanize touch points — voice-note welcome, personal-response windows, community warmth.
5. **No retention discipline.** Evergreen hides churn because revenue keeps arriving. Fix: weekly cohort-retention report.
6. **Attribution blind spots.** Scaling ad spend without server-side attribution → misattributed channels. Fix: Hyros / Triple Whale / custom tracking at $50K+/mo spend.
7. **No LTV tracking.** Spend scales, but without LTV signal you can't justify the spend. Fix: 30 / 60 / 90 / 180-day cohort LTV dashboard.

---
*v1.1 — Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
