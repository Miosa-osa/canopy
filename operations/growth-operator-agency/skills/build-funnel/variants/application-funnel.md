# Application Funnel — Archetype Playbook

> **When it wins:** $5K+ high-ticket offer with a team-based sales motion (setter, closer, or founder-led) where qualification matters more than volume. Premium positioning + controlled growth.

## When to pick this archetype

- Price: $5K–$100K. Below $5K, friction is not worth the filter; above $100K, bespoke proposals replace standardized funnel.
- Delivery is high-touch (group coaching, 1:1, done-with-you) and every client requires real capacity.
- Sales team capacity is limited — you need to filter calls before they hit calendars.
- Refund rate on unfiltered calls > 5% — filtering pays for itself immediately.
- Premium / exclusive positioning reinforced by "we decide who we work with."

## The 5-stage structure

### 1. Awareness

- **Traffic:** organic (content, podcast, referral) + paid retargeting. Cold-traffic direct-to-application rarely works; route cold through VSL or webinar first, then application.
- **Entry:** "Apply to work with us" CTA on VSL, webinar, sales page, or content.

### 2. Interest

- **Application page:** 8–12 questions. `skills/application-form/SKILL.md`.
- **Question types:**
  1. Context (what / who / where)
  2. Pain specifics
  3. Desired outcome specifics
  4. Past solutions tried
  5. Current constraints (budget, timeline, capacity)
  6. Commitment / readiness signals
  7. Contact + scheduling

- **Qualification criteria:** filter on (a) fit with ICP, (b) readiness (financial + time + decision authority), (c) red-flag absence.

### 3. Consideration

- **Post-submission:** immediate confirmation email + scheduling link (auto-book OR manual review first).
- **Manual review:** for premium offers ($25K+), a human reviews each application before granting a call slot. 80% of applications approved for call; 20% declined (auto-email + nurture to wait-list).
- **Pre-call nurture (for approved):** 1–3 emails + SMS reminder. Include testimonial + success-case story + pre-call expectation setting.
- **Call brief (internal):** `skills/call-prep/SKILL.md` runs on every call.

### 4. Decision

- **Discovery call structure (45–75 min):**
  - Rapport + context rebuild (5–10 min)
  - Discovery + deepening (20–30 min)
  - Transition + pitch (10–15 min)
  - Objection handling (10–15 min)
  - Close + deposit ask + next step (5–10 min)

- **Close archetype:** typically assumptive close or crossroads close for high-ticket.
- **On-call deposit:** pays off sharply — 30–50% close-rate lift vs "I'll send a link."

### 5. Action

- **Post-close:** contract (`reference/legal-templates/client-agreement.md`) → full payment or deposit → kickoff email → onboarding sequence.
- **Post-decline:** wait-list nurture OR lower-tier offer (e.g., `skills/tripwire-design/SKILL.md` product) OR close-the-loop email.
- **Refund-protection:** onboarding quality + first-win engineering in days 1–14 (`skills/email-sequence/variants/post-purchase-sequence.md`).

## CVR benchmarks

| Stage | Good | Great | Elite |
|---|---|---|---|
| Traffic → application submit | 3% | 8% | 15% |
| Application → approved for call | 50% | 65% | 80% |
| Approved → call show | 70% | 82% | 92% |
| Call show → pitched | 80% | 90% | 95% |
| Pitched → closed | 15% | 28% | 45% |
| Blended traffic → close | 0.2% | 1.5% | 5.5% |

## Tech stack

- **Application form:** Typeform / Tally / Gravity / Jotform / custom form
- **CRM + pipeline:** HubSpot / Close / Pipedrive / GoHighLevel
- **Scheduling:** Calendly / SavvyCal / HubSpot Meetings / Chili Piper
- **Call recording + transcription:** Zoom + Fathom / Fireflies / Gong (if budget)
- **Deposit processing:** Stripe Payment Links / platform-native
- **Contract signing:** DocuSign / HelloSign / PandaDoc / Dubsado

## Creative requirements

- **Application copy:** sales-safe — "we review every application" + expected timeline.
- **Confirmation email:** sets expectations + builds anticipation + filters out tire-kickers.
- **Pre-call nurture:** 1–3 emails reducing show-rate drop-off.
- **Close-of-call: email + contract + deposit link within 24 hours.

## Economics

- **LTV:CAC ≥ 4:1** (higher than VSL funnel; application friction = higher per-lead economics required).
- **Sales team cost per close:** budget 15–25% of sale price for setter + closer + support.
- **Deposit-to-paid-in-full ratio:** target 85%+ (deposits that don't convert to full payment = leakage).

## Common failure modes

1. **Unfiltered calls.** Sales team burns time on unqualified prospects. Fix: stricter application + manual review + auto-decline criteria.
2. **Low show rate.** Application-to-show < 65%. Fix: tighter pre-call nurture + phone confirmation + calendar reminders + deposit-before-call for premium.
3. **Weak discovery.** Closers pitch before understanding. Fix: discovery-question bank in `prompts/sales-prompts.md` Prompt 5 + call-review coaching.
4. **On-call close-rate drift.** Closers drop to generic close-script. Fix: audit calls weekly, reinforce the 8 required beliefs at each stage.
5. **No deposit ask on call.** Close rates halve when prospects "think it over." Fix: deposit-ask script in `prompts/sales-prompts.md` Prompt 10.
6. **No decline nurture.** Declined applicants go dark. Fix: auto-email + lower-tier offer OR wait-list sequence.

## Variant: founder-led vs setter-closer

- **Founder-led:** founder does every discovery + close. Higher close rate, doesn't scale past ~10 calls/week.
- **Setter + closer:** setter qualifies + books; closer pitches + closes. Scales to 50–100 calls/week with right team.
- **Closer-only:** closer handles the full call. Scales in the middle range.

## Upstream dependencies

- `/design-offer` — LTV:CAC modeled, priced at $5K+
- `/application-form` — shipped with scoring rubric
- `/sales-script` — 8-stage script shipped
- `/call-prep` — 1-page brief template shipped
- `/objection-library` — 20+ objections × reframes

## Downstream handoff

- `/proposal` — for post-call contract-prep
- `/post-booking-nurture` — pre-call show-rate lift
- `/retention-check` — on closed clients

---
*v1.1 — Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
