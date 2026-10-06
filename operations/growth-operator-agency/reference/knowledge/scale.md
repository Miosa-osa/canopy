# Scale — Shared Knowledge

## Purpose
Shared vocabulary, revenue thresholds, sling allocation, and cadence rules inherited by every skill in the Scale department. Scale is the discipline of removing the founder from every revenue-producing activity except the few where the founder is irreplaceable. VSL-director-style revenue-threshold gates dictate what gets built when.

## Department Skills (6)
- `/build-sop` — document a repeatable process with inputs, steps, outputs, owners, metrics
- `/hiring-brief` — role scorecard + ICP for the hire (skills, signals, trial project)
- `/retention-check` — customer health scan → save sequence or offboarding
- `/case-study` — client win documented in before / during / after with verified metrics
- `/competitor-intel` — quarterly competitor sweep (offers, funnels, positioning shifts)
- `/revenue-report` — monthly P&L + cohort view + forward forecast

## Core Vocabulary
- **SOP** — Standard Operating Procedure. One document per repeatable task. Must include: purpose, inputs, step-by-step, decision branches, outputs, owner, metric, failure mode.
- **the VSL director Revenue-Threshold Model** — Build only what current revenue earns the right to. $0–30K MRR: founder does everything. $30–100K: first 2 hires (delivery + ops). $100–300K: team-of-7 (sales, marketing, ops, delivery, finance, CS, founder). $300K+: layered management.
- **the operations director 60/30/10** — Monthly retention allocation: 60% of retention spend on existing-customer success (onboarding, QBRs, community), 30% on recovery (churn intervention), 10% on reactivation (winback).
- **Churn Rate** — % customers who cancel in a period. Target: monthly ≤ 5%, annual ≤ 20% for subscription; ≤ 10% for cohort programs.
- **Net Revenue Retention (NRR)** — ((Starting MRR + Expansion − Churn − Downgrade) / Starting MRR) × 100. Healthy: ≥ 110%.
- **Case-Study Format** — Before (specific pain + metric) / During (mechanism + timeline + notable event) / After (new metric + narrative). Must be verified, not testimonial-only.
- **Competitor Intel Grid** — Offer / price / funnel / hero angle / mechanism / proof / guarantee / trust signals. Quarterly refresh.

## the VSL director Revenue-Threshold Gates
| Revenue Band | Headcount | What to Build | What NOT to Build |
|---|---|---|---|
| $0–30K/mo | 1 (founder) | Offer, first funnel, first SOPs, 3–5 case studies | No hires, no software, no retreats |
| $30–100K/mo | 3 (founder + delivery + ops) | Delivery SOPs, hiring scorecard, retention SOP | No sales team yet, no office |
| $100–300K/mo | 7 (add sales, marketing, CS, finance) | Sales team SOP, marketing cadence, CS playbook, monthly revenue reports | No VP layer, no product expansion |
| $300K–1M/mo | 12–15 (add managers, specialists) | Manager layer, forecasting, org chart, quarterly planning | No enterprise sales pivot without thesis |
| $1M+/mo | 25+ (layered org) | VP hiring, financial controls, board cadence | No diversification before category dominance |

## the operations director 60/30/10 Allocation
Every dollar of retention spend allocates:
- **60% Existing-customer success** — onboarding completion, quarterly business reviews, community events, customer education
- **30% Churn recovery** — health-score drops trigger CS intervention, save offers, re-engagement sequences
- **10% Winback** — reactivation campaigns to churned list (quarterly, with new offer angle)

Guardrail: if churn > 5%/mo, shift to 40/50/10 until stabilized.

## Core KPIs
| KPI | Target | Measured By |
|---|---|---|
| Monthly Churn | ≤ 5% | billing |
| Net Revenue Retention | ≥ 110% | cohort report |
| SOP Coverage | ≥ 80% of recurring tasks documented | ops audit |
| Time-to-First-Win (new hire) | ≤ 30 days | hiring scorecard |
| Case Studies Shipped | ≥ 1 / month per core offer | case-study log |
| Competitor Intel Freshness | ≤ 90 days per competitor | intel grid |
| Revenue Report Cadence | Monthly by Day 5 | calendar |
| Gross Margin | ≥ 60% (services), ≥ 80% (info) | finance |

## Cadences
- **Daily** — Ops standup (15 min), support triage, metrics glance
- **Weekly** — Department review (60 min), hiring pipeline, retention health scan
- **Monthly** — Revenue report, case-study release, SOP audit, competitor-offer scan
- **Quarterly** — Full competitor intel refresh, QBR with each key client, hiring-plan revision, org review
- **Annual** — Strategy re-set, pricing review, positioning audit

## Handoff Patterns
1. Repeated task observed ≥ 3 times → `/build-sop` triggered. **Gate:** SOP reviewed by 2 operators before publishing.
2. SOP executed 10+ times with < 5% error rate → candidate for hire. **Gate:** `/hiring-brief` uses the SOP as scorecard.
3. Health-score drop ≥ 2 tiers → `/retention-check` triggered. **Gate:** intervention within 48h.
4. Client hits target result → `/case-study` request goes out (with written permission). **Gate:** metrics verified by screenshot + signed quote.
5. Quarterly window opens → `/competitor-intel` runs on top 5 competitors.
6. Month-close Day 1–5 → `/revenue-report` consumes billing + CRM → feeds founder scorecard.

## Anti-patterns (block these)
- Hiring before SOPs exist (new hire has nothing to execute)
- SOPs with no owner or no metric (unenforceable)
- Case studies with testimonials-only (no verified metric = not a case study)
- Reacting to churn only after cancellation (health-score drops precede it; instrument them)
- Competitor intel without action (intel without decisions is theater)
- Revenue report without cohort view (MRR alone hides churn)
- Skipping the VSL director gates (building team-of-7 at $30K/mo = structural burn)

## Cross-references
- Skills: `skills/build-sop/SKILL.md`, `skills/hiring-brief/SKILL.md`, `skills/retention-check/SKILL.md`, `skills/case-study/SKILL.md`, `skills/competitor-intel/SKILL.md`, `skills/revenue-report/SKILL.md`
- Frameworks: `reference/frameworks/sequential-dependency.md`, `reference/frameworks/slings-60-30-10.md`
- Knowledge: `reference/knowledge/foundations.md` (ICP for hiring), `reference/knowledge/nurture.md` (retention sequences)
- Agents: `agents/sop-builder.md`, `agents/client-success.md`, `agents/financial-modeler.md`
- Pipeline: `workflows/divisions/scale-pipeline.md`

---
*v1.0 — 2026-04-19.*
