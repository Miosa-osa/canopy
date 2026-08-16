# Survey Funnel — Archetype Playbook

> **When it wins:** Multi-offer catalog or multi-avatar ICP where the right offer depends on the prospect's context. B2B / consulting sells especially well here.

## When to pick this archetype

- You have 3+ distinct offers serving distinct buyer types — not one offer positioned 3 ways.
- Prospect's best-fit offer is non-obvious from the outside (consulting, agency, enterprise, diagnostic).
- You want to serve the right offer on the first contact (vs. starting everyone in the funnel for Offer A and re-routing).
- Offers span price tiers ($500–$50K+); different offers match different stages of buyer readiness.

## The 5-stage structure

### 1. Awareness

- **Traffic:** paid (LinkedIn for B2B, Meta for B2C), organic, referrals.
- **Ad / entry point:** "Take this 2-minute survey to find the right [solution] for your [business/situation]."
- **Landing:** survey start page (promise + benefit + start button).

### 2. Interest

- **Survey structure:** 8–15 questions across 3 dimensions:
  - Context (industry, role, stage, size)
  - Pain (what problem now)
  - Readiness (budget, timeline, decision authority)

- **Completion rate target:** 65–80%.
- **Email capture:** typically mid-survey (after context, before recommendation) OR end-of-survey.

### 3. Consideration

- **Recommendation engine:** survey answers → best-fit offer algorithm.
- **Recommendation page variants:**
  - Offer A (e.g., $497 course) → direct checkout or webinar
  - Offer B (e.g., $2K–$5K program) → application form
  - Offer C (e.g., $10K–$25K consulting) → book a call
  - Offer D (e.g., $50K+ engagement) → custom proposal path

- **Segment-specific nurture:** different 3–7-email sequences based on offer routed to.

### 4. Decision

- **Offer-specific close mechanism:** VSL, webinar, application, discovery call — whatever fits the offer price and readiness.
- **Close rate:** varies widely by offer tier (15–45% pitched-to-close).

### 5. Action

- **Post-close:** offer-specific onboarding.
- **Post-decline:** sideways route — "you said you weren't ready for X, here's the prerequisite Y."

## CVR benchmarks

| Stage | Good | Great | Elite |
|---|---|---|---|
| Land → survey start | 40% | 55% | 70%+ |
| Survey start → completion | 65% | 78% | 88%+ |
| Completion → offer page view | 70% | 85% | 95%+ |
| Offer page → conversion (action) | 8% | 15% | 25%+ |
| Blended traffic → revenue event | 1.5% | 5% | 12%+ |

## Tech stack

- **Survey:** Typeform / Involve.me / Outgrow / custom form
- **Routing engine:** conditional logic in survey platform OR custom backend
- **Email + CRM:** segmented by offer recommendation
- **Offer-specific funnels:** each offer has its own landing / VSL / webinar / application / booking mechanism

## Creative requirements

- **Survey questions:** conversational, business-y, not quiz-y (different tone from quiz funnel).
- **Recommendation pages:** 3–6 distinct pages, each with offer-specific proof + CTA.
- **Email sequences:** 3–6 distinct, one per offer track.
- **Ad creative:** "find the right fit" angle; can be B2B-targeted ads on LinkedIn.

## Economics

- **Right-offer economics vs wrong-offer economics:** routing a $50K prospect to a $500 course is offer-failure. Survey-funnel economics depend on accurate routing.
- **LTV:CAC** computed per-offer track, not blended. Some tracks may break-even; others may carry the model.

## Common failure modes

1. **Survey too long.** 15+ questions → completion drops below 50%. Fix: 8–12 questions max.
2. **Routing too optimistic.** Everyone gets routed to the most expensive offer. Prospect resents mismatch. Fix: honest routing — sometimes the recommendation is "you're not ready yet, here's the prerequisite."
3. **Generic recommendation page.** All tracks see similar pages. Fix: 3+ real variants with distinct copy + proof + CTA.
4. **No offer-specific nurture.** Everyone gets the same follow-up. Fix: distinct sequences per offer track.
5. **Inconsistent brand voice across offer pages.** Different pages feel like different companies. Fix: `skills/extract-voice/SKILL.md` voice discipline across all variants.
6. **Survey feels like qualifying.** Prospect senses sales filter. Fix: frame survey as "finding the right fit for you" not "seeing if you qualify for us."

## Variant sub-archetypes

- **Product-fit survey:** offer catalog (course / program / consulting / mastermind). Default.
- **Diagnostic survey (B2B):** survey diagnoses the business's constraint → recommends the specific service.
- **Readiness-stage survey:** survey maps prospect to buyer-journey stage → serves stage-appropriate content or offer.

## Upstream dependencies

- `/build-icp` — 3+ distinct sub-segments mapped to distinct offers
- `/design-offer` — 3+ offers designed at different price tiers
- `/extract-voice` — voice consistency across all variants
- `/build-positioning` — positioning for each offer + overall brand

## Downstream handoff

- Each offer track uses its own archetype (VSL, webinar, application, book-a-call)
- `/email-sequence` — segment-specific sequences
- `/retention-check` — on closed clients

---
*v1.1 — Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
