# Deposit-to-Call Funnel — Archetype Playbook

> **When it wins:** Premium positioning where price-filtering at the top protects the team's time. Refundable or credited deposit locks commitment. $15K+ offers. Elite / exclusive brand tier.

## When to pick this archetype

- Offer is $15K+ high-ticket, mastermind, or top-tier consulting.
- Your team's time on calls is valuable enough that a deposit protects throughput.
- ICP expects a premium filter ("we take this seriously").
- Refund policy allows deposit credit-toward-offer OR partial-refund-after-call.
- You have authority / brand strength that justifies asking for money before a conversation.

## The 5-stage structure

### 1. Awareness

- **Traffic:** typically warm — referrals, content, existing relationship, after a prior funnel stage (VSL, newsletter, podcast).
- **Entry:** "Book a strategy call — $X deposit secures the slot, credits to your engagement if you enroll."
- **Cold-to-deposit funnel rarely works:** route cold through warm-up first.

### 2. Interest

- **Deposit page:** short sales page + deposit form.
  - Promise of what the call delivers (diagnostic + recommendation + fit assessment)
  - Deposit amount ($497–$5K typical)
  - What happens to deposit (credit to enrollment OR refunded after call IF not fit)
  - Calendar booking after payment clears

- **CVR benchmark:** 5–20% of warm visitors pay the deposit (significantly lower than free-call book rate, significantly higher intent per close).

### 3. Consideration

- **Post-deposit confirmation:** email + calendar + pre-call brief questionnaire (short).
- **Pre-call nurture:** 1–2 emails setting expectations, sharing a relevant case study.
- **Show-rate benchmark:** 95%+ (paid deposit = near-zero no-show).

### 4. Decision

- **Call (45–90 min):**
  - Rapport + deposit acknowledgment (1–2 min)
  - Discovery + diagnostic (20–30 min)
  - Recommendation + offer pitch (15–20 min)
  - Objection + close (10–20 min)
  - Deposit-credit handling (mentioned naturally, not pressure tactic)

- **Close rate on deposit-paid calls:** 35–65% (much higher than free-call close rate because buyer pre-committed).
- **Deposit outcomes:**
  - Close → deposit credited to full price
  - No-close but still fit → deposit refundable within 30 days on request
  - No-close due to misfit identified on call → deposit refunded immediately

### 5. Action

- **Close path:** contract + remaining payment + onboarding.
- **Non-close path:** deposit handling (credit or refund) + close-the-loop email.

## CVR benchmarks

| Stage | Good | Great | Elite |
|---|---|---|---|
| Warm traffic → deposit | 5–12% | 12–20% | 20–30%+ |
| Deposit → show | 90–95% | 95–98% | 98%+ |
| Show → close | 35–55% | 55–70% | 70–85%+ |
| Blended warm traffic → close | 2–5% | 5–10% | 10–18% |

## Tech stack

- **Deposit page:** simple sales page + Stripe Payment Link / Stripe Checkout
- **CRM:** Close / HubSpot / Pipedrive
- **Calendar:** Calendly / SavvyCal (gated to show only after deposit clears)
- **Call recording:** Zoom + Fathom / Fireflies
- **Contract:** DocuSign / PandaDoc / HelloSign
- **Deposit refund mechanism:** documented + audit-able

## Creative requirements

- **Deposit page copy:** addresses the obvious objection ("why pay for a call?") by framing the deposit as filter + commitment, not gate.
- **Pre-call brief form:** 5–8 questions (short — they already paid).
- **Email sequence:** 2–4 emails pre-call + 2 emails post-call.
- **Refund-request process:** clear, friction-free.

## Economics

- **Deposit revenue:** typically $497–$5K. On a $25K+ offer, deposit is 2–10% of price.
- **Revenue split:** 60–80% of deposit-payers close; 20–40% refund.
- **Team-time savings:** calls drop 50–70% in volume but close 2–4× better. Net team hours per close decrease 30–50%.
- **LTV:CAC:** usually excellent — warm traffic + filtered calls + premium pricing.

## Common failure modes

1. **Deposit feels like a scam.** Copy is aggressive or unclear. Fix: plain-language explanation of what deposit covers + refund policy.
2. **Deposit too high.** $5K deposit on a $15K offer kills conversion. Fix: 2–5% of total price typical.
3. **No refund-path clarity.** Prospects won't pay if refund is unclear. Fix: document refund conditions explicitly + visible.
4. **Team refuses to refund.** Builds trust debt. Fix: process refunds same-day on request.
5. **Calendar gate fails.** Deposit pays but calendar slot isn't reserved. Fix: integration between payment + calendar; manual backup process.
6. **No second-touch for refunds.** Refunded prospects go dark. Fix: "we'll stay in touch if readiness changes" email + content-orbit nurture.
7. **Wrong-positioning for price filter.** Brand isn't authoritative enough to command a paid call. Fix: build authority first (content, case studies, social proof), then add deposit later.

## Variant sub-archetypes

- **Fully-refundable deposit:** deposit refunded if no-close. Lowest friction, lowest filter.
- **Credit-only-toward-offer deposit:** non-refundable, but credits to purchase. Highest filter + commitment.
- **Tiered deposit:** low for discovery call, higher for second "proposal" call. Used on large enterprise deals.
- **Application + deposit:** application filters fit; deposit filters commitment. Double-filter for elite tiers.

## Upstream dependencies

- Warm traffic funnel feeding the deposit-call page (VSL, newsletter, content, referrals)
- `/design-offer` — $15K+ offer with unit economics backing the price
- `/application-form` — if pairing with application
- `/sales-script` — 45–90 min call framework
- `/call-prep` — pre-call brief discipline
- `/proposal` — post-call contract

## Downstream handoff

- `/retention-check` — on closed clients
- `/case-study` — from standout closes
- Refund-handling process (documented internally)

---
*v1.1 — Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
