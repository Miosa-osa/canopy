---
name: referral-program
description: Design customer-referral mechanics — reward structure, referral triggers, tracking, viral loop design. Distinct from affiliate program (customer-focused, not commercial partner).
signal:
  mode: linguistic
  genre: referral-program-spec
  type: inform
  format: markdown
  structure: w-referral-program
  receiver: existing customers + operations
  receiver_capacity: medium
department: partnerships
agent_affinity: [partnerships-head]
required_compartments:
  offer_architecture: 50
  lifecycle_optimization: 40
upstream_dependency: retention-check
execution_mode: interactive
tier: structured_ai
temperature_gate: warm
required_tools: [file_read, file_write]
required_mcps: [filesystem]
required_integrations:
  referral_tracking: [referralcandy-api, rewardful-api]
  crm: gohighlevel-api
  email: convertkit-api
credentials_required: [GHL_API_KEY, CONVERTKIT_API_KEY]
evidence_gate:
  - reward_structure_specified
  - triggers_mapped
  - tracking_wired
  - viral_loop_designed
  - signal_score_gte_0_8
keywords:
  - referral
  - referral program
  - viral loop
  - customer referral
priority: 1
version: 1.0
---

# /referral-program — Customer Referral Mechanics

## Structure

```
W(referral-program) =
  1. Reward Structure (who gets what — referrer + referee)
  2. Triggers (when ask for referral)
  3. Tracking + Attribution
  4. Viral Loop Design (k-factor optimization)
  5. Communication Cadence
  6. Success Metrics
```

## Reward Structure Options

| Pattern | Example |
|---|---|
| **Cash for referrer** | $500 per closed referral |
| **Credit for both** | $500 credit referrer + $500 off referee |
| **Service perks** | Extra coaching hours / DFY service for referrer |
| **Exclusive access** | Mastermind seat, retreat invite |
| **Hybrid** | Cash + perks combo |

For high-ticket: perks > cash (cash feels transactional to premium buyers).

## Triggers

- **Post first-win** — within 7-14 days of milestone hit (highest conversion)
- **NPS >= 9 moment** — ask in the NPS reply email
- **Testimonial capture** — pair with referral ask
- **Renewal / re-up** — "bring a friend" bonus
- **Milestone anniversaries** — 90-day / 180-day / 365-day

## Viral Loop Design (k-factor)

k = (invites sent per user) × (conversion rate on invites)

Target k > 1 = organic growth. Most programs k = 0.1-0.5 (supplements acquisition, not replaces).

## Process

### Phase 0 — Load
- Offer Doc, Retention output (thriving clients)
- Compartment 10 Lifecycle

### Phase 1 — Reward Structure
Per offer tier, select reward pattern.

### Phase 2 — Trigger Mapping
Per client journey stage, define when referral ask fires.

### Phase 3 — Tracking Wire-up
Referral links, attribution, CRM tagging.

### Phase 4 — Communication
Email/SMS asking for referral + providing share-asset.

### Phase 5 — Success Metrics
k-factor, referral-driven revenue %, CAC via referral vs paid.

## Output Format

```markdown
# Referral Program — [Creator Brand]

**Reward Pattern:** [cash | credit-both | perks | hybrid]
**Target k-factor:** [0.3+]
**Version:** 1.0

## Reward Structure
- Referrer receives: [...]
- Referee receives: [...]
- Payout trigger: [when referee completes X]

## Triggers
| Trigger | Timing | Communication |
|---|---|---|
| Post first-win | Day 7-14 post-milestone | Email + SMS |
| NPS 9+ | In NPS reply | Email |
| [...] |

## Tracking
- Referral link format: [...]
- Attribution: [last-click / first-click]
- CRM tag: referral_source=[referrer-id]

## Communication Cadence
### Post-first-win email
[copy]

### NPS-9 email follow
[copy]

### Share-assets
- Share link template
- Suggested message for referrer to use
- Landing page for referees

## Success Metrics
- k-factor: [target]
- Referral-driven revenue: [% of total]
- Referral CAC vs paid CAC: [comparison]
```

## Verification Checklist
- [ ] Reward structure specified
- [ ] Triggers mapped across journey
- [ ] Tracking wired
- [ ] Communication cadence with assets
- [ ] Success metrics targeted
- [ ] Triple-layer S/N ≥ 0.8

## Next Skills
- `/email-sequence` — referral ask emails
- `/case-study` — referrals from Thriving clients pair with case studies

## References
- Partnerships department Department
- Lifecycle best practices

---
*v1.0 — 2026-04-19. Cycle 6 Partnerships.*
