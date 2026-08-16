---
name: affiliate-program
description: Design affiliate program structure — commission rates + payout logic + affiliate portal + promotion assets + recruitment outreach + compliance. Built for Stripe / ThriveCart / FirstPromoter / Everflow integrations.
signal:
  mode: linguistic
  genre: affiliate-program-spec
  type: inform
  format: markdown
  structure: w-affiliate-program
  receiver: affiliates + operations
  receiver_capacity: medium
department: partnerships
agent_affinity: [partnerships-head]
required_compartments:
  offer_architecture: 60
  lifecycle_optimization: 20
upstream_dependency: design-offer
execution_mode: interactive
tier: structured_ai
temperature_gate: warm
required_tools: [file_read, file_write]
required_mcps: [filesystem]
required_integrations:
  affiliate_tracking: [firstpromoter-api, rewardful-api, everflow-api]
  payment: stripe-api
  email: convertkit-api
credentials_required: [STRIPE_SECRET_KEY, CONVERTKIT_API_KEY]
evidence_gate:
  - commission_structure_specified
  - payout_logic_clear
  - portal_assets_defined
  - recruitment_plan
  - compliance_disclosed
  - signal_score_gte_0_8
keywords:
  - affiliate
  - affiliate program
  - referral commission
priority: 1
version: 1.0
---

# /affiliate-program — Affiliate Program Designer

## Structure

```
W(affiliate-program) =
  1. Commission Structure (rates, tiers, recurring vs one-time)
  2. Payout Logic (cookie window, attribution, minimum payout, frequency)
  3. Affiliate Portal (login, links, assets, stats)
  4. Promotion Assets (ad creative / email swipes / social posts / landing pages)
  5. Recruitment Plan (who, outreach, qualification)
  6. Compliance (FTC disclosure, tax forms, contracts)
  7. Economics Validation (affiliate payout fits LTV:CAC math)
```

## Decision Logic

### Commission Rate Benchmarks
- Info / coaching: 20-50% first sale, 10-30% recurring
- Digital product: 30-50%
- SaaS: 20-30% first year, decaying
- Done-for-you: 10-20% (higher fulfillment cost)

### Cookie Window
- 30-60 days standard
- 90+ days for high-consideration offers

### Recruitment Tiers
- **Tier 1 affiliates** (top creators, influencers) — higher commission + custom terms
- **Tier 2** (aligned partners) — standard rates
- **Tier 3** (casual / customer-advocate) — self-serve portal

## Output Format

```markdown
# Affiliate Program — [Creator Brand]

**Commission Rate:** [%] first sale / [%] recurring
**Cookie Window:** [days]
**Payout Frequency:** [monthly]
**Minimum Payout:** $[N]
**Version:** 1.0

## Commission Structure
| Tier | First Sale | Recurring | Bonus |
|---|---|---|---|
| Tier 1 | 40% | 25% | $500 for first referral |
| Tier 2 | 30% | 20% | N/A |
| Tier 3 | 20% | 10% | N/A |

## Payout Logic
- Cookie window: [N days]
- Attribution: last-click
- Payment: monthly via Stripe/PayPal
- Minimum payout: $[N]
- Hold period: [days post-refund window]

## Affiliate Portal
- Login URL: [...]
- Affiliate link format: [...]
- Stats dashboard: [metrics]
- Asset library: [below]

## Promotion Assets
- Email swipes (3-5 versions)
- Social posts (LinkedIn / X / IG templates)
- Ad creative (banners / video ads)
- Webinar invite copy
- Landing pages (if custom for affiliates)

## Recruitment Plan
- Tier 1: direct outreach (5-10 target affiliates)
- Tier 2: email existing buyers
- Tier 3: public signup page

## Compliance
- FTC disclosure template (affiliates must use)
- W-9 / W-8BEN collection
- Affiliate agreement contract
- Refund policy handling

## Economics Validation
- Payout as % of AOV: [%]
- Net AOV post-payout: $[N]
- LTV:CAC impact: [math]
```

## Verification Checklist
- [ ] Commission structure specified
- [ ] Payout logic clear
- [ ] Portal + assets defined
- [ ] Recruitment plan
- [ ] Compliance complete
- [ ] Economics preserve ≥3:1 LTV:CAC
- [ ] Triple-layer S/N ≥ 0.8

## Next Skills
- `/referral-program` — customer-referral mechanics (adjacent)
- `/email-sequence` — affiliate recruitment sequence

## References
- Partnerships department Department

---
*v1.0 — 2026-04-19. Cycle 6 Partnerships.*
