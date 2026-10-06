# Launch — Shared Knowledge

## Purpose
Shared vocabulary, 5-phase SOP, launch variants, and tech checklist inherited by every skill in the Launch department. Launch compresses 6 months of marketing into a defined window — a concerted push with inventoried assets, a measured runway, and a post-mortem that feeds the next cycle.

## Department Skills (2)
- `/plan-launch` — build a full launch plan across the 5 phases
- `/launch-report` — post-launch debrief + attribution + learnings

## Core Vocabulary
- **Launch Window** — The defined sales-open period (typically 5–14 days). Cart opens, cart closes, no extensions.
- **Runway** — Pre-launch promotion period (typically 14–30 days) where interest is built without asking for the sale.
- **Open-Cart Frenzy** — The first 48h after cart opens. Historical data: 30–40% of revenue lands here.
- **Close-Cart Frenzy** — Final 24h before cart closes. 40–50% of revenue lands here.
- **Dead Middle** — Days 3 to N-2. Hardest period; requires scheduled spikes (guest teachers, bonus drops, Q&As).
- **Attribution Window** — Days from first touch to purchase counted as launch revenue. Standard: 30 days pre + launch window.
- **Shopping Cart Abandonment (SCA)** — % who hit checkout but do not purchase. Target < 60% with sequenced recovery.

## The 5-Phase Launch SOP

### Phase 1 — Pre-Launch Prep (T-minus 45 to T-minus 15 days)
- Offer finalized and pressure-tested
- Funnel pages built and QA'd
- Email sequences written (runway, daily-during-launch, cart-close, SCA, post-purchase)
- Tech stack load-tested (5× expected peak)
- Affiliate partners recruited + briefed
- All ad creative produced (20+ assets minimum)
- Customer-service scripts written

### Phase 2 — Runway (T-minus 14 to T-minus 1)
- Value content cadence: 1 piece every 2 days minimum
- Waitlist open, lead-magnet running
- Social proof collection: testimonials, case studies
- Founder-led live events (2–3 webinars, AMAs, or workshops)
- Email nurture: 6–8 touches building belief scaffolding

### Phase 3 — Launch Day (Day 0)
- Cart opens with scheduled announcement (email + SMS + socials simultaneously)
- 2–3 additional pushes in first 12h
- Live stream or event to concentrate attention
- Monitor funnel metrics hourly; hot-patch issues

### Phase 4 — Dead Middle Sustain (Days 1 to N-2)
- Daily email minimum
- 1 scheduled spike per day (new testimonial, Q&A, bonus reveal, guest, deadline reminder)
- Retarget warm-but-unconverted list
- Objection-handling content (video + email + post)

### Phase 5 — Close + Post-Mortem (Day N and N+1 to N+7)
- Cart-close frenzy: 3 emails in final 24h, SMS at 4h and 1h
- Midnight close — no extensions (trust > revenue)
- Day N+1: thank-you email, onboarding kickoff
- Days N+2 to N+7: produce `launch-report.md` with attribution, CVR, CAC, revenue, lessons

## 5 Launch Variants
1. **Cohort Launch** — Fixed start date, students proceed together. Best for: coaching programs, group curricula.
2. **Rolling Launch** — Always-on with scheduled "open-cart weeks" monthly or quarterly. Best for: evergreen offers with cohort benefits.
3. **Evergreen Launch** — Automated 14-day window triggered per-lead. Best for: info products, scaled funnels.
4. **multi-video pre-launch runway (the launch-formula originator)** — 3 pre-launch videos → cart open 4–7 days. Best for: info + community.
5. **Challenge Launch** — 5-day / 7-day challenge → offer at the end. Best for: engagement-driven close, fitness, biz-opp.

Pick based on: offer price, audience size, operational capacity, traffic source.

## Launch KPIs
| KPI | Target | Measured By |
|---|---|---|
| Waitlist Conversion (lead → buyer) | ≥ 8% | CRM |
| Launch CVR (traffic → buyer) | ≥ 2% | funnel analytics |
| Cost per Acquisition | ≤ 1/3 offer price | ad platform |
| SCA Recovery | ≥ 15% | SCA sequence |
| Email Open Rate (launch) | ≥ 35% | ESP |
| Open-Cart 48h Revenue Share | 30–40% | revenue dashboard |
| Close-Cart 24h Revenue Share | 40–50% | revenue dashboard |
| NPS (Day N+7) | ≥ 50 | onboarding survey |
| Refund Rate | ≤ 5% | billing |

## Launch Tech Checklist
- [ ] Checkout gateway tested with real card (refunded)
- [ ] Failover payment processor configured
- [ ] CRM tags firing correctly (abandoned, purchased, refunded, upsell)
- [ ] Email deliverability: SPF, DKIM, DMARC passing; list warmed
- [ ] Landing page Core Web Vitals green (LCP < 2.5s, CLS < 0.1)
- [ ] Tracking: pixel, server-side, UTM, attribution window set
- [ ] Scarcity timer logic verified (not resetting on refresh)
- [ ] SMS provider connected + opt-ins cleaned
- [ ] Onboarding sequence triggers on-purchase (not on manual tag)
- [ ] Support inbox monitored + triage SLA defined
- [ ] Load test: 5× peak expected traffic
- [ ] Rollback plan for every critical page

## Handoff Patterns
1. Offer + VSL + Funnel ready (from sales department) → `/plan-launch` consumes them. **Gate:** all 5 Phase-1 prep items complete.
2. `/plan-launch` produces `launch-plan.md` — 5-phase calendar, asset inventory, team responsibilities. **Gate:** tech checklist at 100%.
3. Launch executes — metrics captured daily.
4. `/launch-report` consumes analytics → produces `launch-report.md` with attribution, CVR, lessons, next-cycle inputs.
5. Lessons feed back into foundations (offer refinement), marketing (creative performance), nurture (email CVR), sales (close-rate).

## Anti-patterns (block these)
- Launching without a cart-close deadline (evergreen without scarcity = no urgency)
- Extending the deadline (destroys future launch credibility)
- No runway (cold audience + open cart = flat launch)
- Single email/day during dead middle (audience fatigue from silence, not frequency)
- Ignoring SCA (15%+ recoverable revenue left on table)
- No post-mortem (repeats same mistakes next cycle)

## Cross-references
- Skills: `skills/plan-launch/SKILL.md`, `skills/launch-report/SKILL.md`
- Knowledge: `reference/knowledge/sales.md` (funnel + VSL), `reference/knowledge/marketing.md` (creative), `reference/knowledge/nurture.md` (email sequences)
- Frameworks: `reference/frameworks/launch-5-phase.md`, `reference/frameworks/product-launch-formula.md`
- Agents: `agents/launch-manager.md`, `agents/post-launch-analyst.md`
- Pipeline: `workflows/divisions/launch-pipeline.md`

---
*v1.0 — 2026-04-19.*
