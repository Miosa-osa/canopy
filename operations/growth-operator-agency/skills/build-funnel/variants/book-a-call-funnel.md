# Book-a-Call Funnel — Archetype Playbook

> **When it wins:** Mid-to-high ticket ($2K–$15K), warm-to-hot traffic, short decision cycle, low-friction discovery. The B2B / coaching default when the prospect already trusts the creator.

## When to pick this archetype over application funnel

- Traffic is warm (list, referral, podcast listener, social follower) so qualification friction isn't needed upfront.
- Price is $2K–$15K (below $2K → tripwire / cart; above $15K → application).
- Sales cycle < 2 weeks (longer → add nurture between call and close).
- Creator brand carries the trust — prospects book because they already half-trust.
- Volume goal is 10–40 calls per week (higher volume → application funnel filter needed).

## The 5-stage structure

### 1. Awareness

- **Traffic:** content (LinkedIn, YouTube, podcast), list, referrals, paid retargeting.
- **Ad / post creative:** lead with the outcome, not the call ("Book a call to learn X" is weaker than "If you want X, here's 15 min on the calendar").
- **Landing:** either direct-to-Calendly OR a short landing page (hero + proof + 3 benefits + book button).

### 2. Interest

- **Calendar page:** Calendly / SavvyCal / custom. 2–3 question intake (name, email, 1 context question).
- **No long application** — the whole point of this archetype is low friction.
- **CVR benchmark (warm traffic):** land → book 8–20%.

### 3. Consideration

- **Pre-call sequence (3 emails + SMS):**
  - Booking confirmation + calendar invite (immediate)
  - 24 hours before: "what to expect" + 1 success case
  - 6 hours before: SMS or email reminder + Zoom link
  - 1 hour before: SMS reminder
- **Show rate target:** 70–85% on warm traffic with this nurture stack.
- **Call brief:** `skills/call-prep/SKILL.md` on every call.

### 4. Decision

- **Discovery call (30–60 min, shorter than application funnel):**
  - Rapport (3–5 min)
  - Discovery (15–25 min)
  - Transition to pitch (5–10 min)
  - Pitch (10–15 min)
  - Close + next step (5–10 min)

- **Close rate target:** 25–40% on warm book-a-call traffic (lower than application funnel because less upfront qualification).
- **On-call payment:** preferred for sub-$5K offers; deposit + payment plan preferred for $5K–$15K.

### 5. Action

- **Post-close:** contract + payment link within 30 min of call end. Momentum matters.
- **No-close follow-up:** 5-touch sequence over 14 days (`prompts/sales-prompts.md` Prompt 4).
- **Onboarding:** starts immediately after payment clears.

## CVR benchmarks

| Stage | Warm traffic | Cold retargeted |
|---|---|---|
| Land → book | 8–20% | 3–8% |
| Book → show | 70–85% | 55–72% |
| Show → pitched | 85–95% | 75–88% |
| Pitched → closed | 25–40% | 15–25% |
| Blended land → close | 1.5–5% | 0.4–1.5% |

## Tech stack

- **Calendar:** Calendly / SavvyCal / Cal.com
- **CRM:** HubSpot / Close / GoHighLevel (simpler than application-funnel CRM needs)
- **Reminders:** platform-native + SMS (Twilio / Textline / platform integration)
- **Payment:** Stripe Payment Links / Payment Links with payment-plan option
- **Contract:** HelloSign / DocuSign (optional for sub-$5K)

## Creative requirements

- **Traffic creative:** outcome-led, not call-led ("If you're a [X] who wants [Y]" beats "book a call to talk")
- **Landing page:** 400–600 words if used; otherwise direct-to-calendar
- **Pre-call emails:** 3 emails per `skills/email-sequence/variants/welcome-sequence.md` style (concise, expectation-setting)

## Economics

- **LTV:CAC ≥ 3:1**.
- **Sales cost:** 10–20% of sale price.
- **Deposit-to-paid rate:** 90%+ (simpler sales motion = fewer defaults).

## Common failure modes

1. **Traffic too cold.** Direct-to-calendar cold traffic rarely converts. Fix: route cold through a short VSL, a lead magnet, or a newsletter before the calendar CTA.
2. **No pre-call nurture.** Show rate < 60%. Fix: add 24h + 6h + 1h reminders.
3. **Calendar friction.** 10-question Typeform before calendar destroys conversion. Fix: 2–3 questions max.
4. **Closer reads a script.** Warm prospects already know the creator — scripted closes feel off. Fix: frameworked close, not scripted.
5. **No follow-up after "no."** 40–60% of warm book-a-call prospects close on follow-up. Fix: 5-touch sequence per `prompts/sales-prompts.md` Prompt 4.
6. **Price reveal on wrong call.** Some book-a-call prospects need two calls (diagnostic + proposal). Fix: add deposit-call flow OR surface price on discovery.

## Variant sub-archetypes

- **Strategy call (diagnostic-only):** the first call delivers a diagnostic; the pitch is a second call. Premium / complex offers.
- **Discovery + pitch (single call):** 30–60 min, ends with the offer. Most common.
- **Preliminary + intro video:** prospect watches a 10–20 min pre-call video; call starts at discovery depth. Lifts close rate.

## Upstream dependencies

- `/build-icp` — Completeness ≥ 80
- `/design-offer` — priced between $2K and $15K
- `/sales-script` — frameworked, not scripted
- `/call-prep` — brief template ready
- `/post-booking-nurture` — pre-call sequence built

## Downstream handoff

- `/proposal` — if second-call pattern
- `/email-sequence` — no-close follow-up
- `/retention-check` — on closed clients

---
*v1.1 — Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
