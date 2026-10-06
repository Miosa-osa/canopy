# Webinar Funnel — Archetype Playbook

> **When it wins:** Market sophistication stage requires belief installation; audience has some warmth (list, social, referrals); mid-ticket to high-ticket ($997–$15K) with a cohort-based delivery model.

## When to pick this archetype

- ICP benefits from 60–90 minutes of teaching before the offer ask.
- Offer maps to a clear 3-secrets / 3-pillars / 3-lies teaching structure.
- You run cohorts or limited-window enrollment (scarcity is real).
- You have a list OR warm audience (cold-traffic webinars convert 2–5× worse than warm; only run cold if you've modeled the economics).
- You have the capacity to run live OR a polished evergreen recording.

## The 5-stage structure

### 1. Awareness

- **Traffic source:** organic (LinkedIn, X, YouTube, email list, podcast) + paid retargeting.
- **Ad creative:** invitation-style, not offer-style. "Join me for a free training on X."
- **Landing:** 1-page registration form (email + first name minimum; for B2B add company + role).
- **CVR benchmark:** warm traffic → registration 30–50%; cold traffic → registration 10–20%.

### 2. Interest

- **Registration confirmation:** immediate email + calendar invite + SMS opt-in (optional).
- **Pre-webinar nurture:** 4–6 emails across 3–14 days. `skills/email-sequence/variants/webinar-promotion-sequence.md`.
- **Show-rate target:** 40–55% (evergreen 25–40%, live warm 50%+).
- **Pattern interrupt:** pre-webinar content (video teaser, short PDF, DM) to deepen commitment.

### 3. Consideration

- **Webinar body (60–90 min):**
  - **Opening (0:00–10:00):** big promise, credibility, agenda, interaction ping.
  - **Teaching (10:00–60:00):** three-secrets archetype — each "secret" dismantles a limiting belief + installs a new one. Lead with the most unexpected secret.
  - **Transition (60:00–65:00):** bridge from teaching to offer without tonal whiplash.
- **Belief arc:** 8 required beliefs (same set as VSL: reproduction → derivative desire → can-fulfill → urgency → this-offer → better-faster → trust-person → trust-expertise).

### 4. Decision

- **Pitch (60:00–80:00):**
  - Restate the transformation.
  - Introduce the offer (core + bonuses + guarantee).
  - Stack slide with $ anchors ≥ 5× price.
  - Price reveal with contrast mechanic.
  - Urgency mechanism (cohort start, price increase, bonus expiration — REAL).
- **Close (80:00–90:00):** live Q&A + "click the link" CTA repeated 3×.

### 5. Action

- **Cart or booking:** checkout (for set-price) or application form (for qualifying).
- **Cart-open window:** 24–72 hours typical. Shorter = more urgency + lower close rate on stragglers.
- **Post-webinar sequence:** replay + objection-pre-empt emails + final-hours email.

## CVR benchmarks

| Stage | Warm list | Cold traffic |
|---|---|---|
| Registration rate | 30–50% | 10–20% |
| Show rate | 40–55% | 20–35% |
| Pitch-stay rate | 55–75% | 40–60% |
| Close rate (of live attendees) | 3–7% | 1–3% |
| Close rate (of replay watchers) | 1–3% | 0.5–1.5% |
| Blended list → close | 0.8–2.5% | 0.2–0.8% |

## Tech stack

- **Webinar platform:** Zoom + StreamYard (live) / Everwebinar / WebinarJam / Demio (evergreen)
- **Registration / email:** ActiveCampaign / ConvertKit / Klaviyo / Customer.io
- **Calendar reminders:** Calendly reminder flow or platform-native
- **Checkout:** Stripe / Samcart / platform-native
- **Replay hosting:** Wistia / Vimeo / YouTube unlisted

## Creative requirements

- **Promo ads (if paid retargeting):** 3–5 angles tied to "what you'll learn."
- **Email sequence:** 4–6 emails per `skills/email-sequence/variants/webinar-promotion-sequence.md`.
- **Live webinar slides:** 60–100 slides at 1 slide / 60–90 seconds.
- **Evergreen version:** pre-recorded, cleaned, compressed to 45–75 min.

## Economics

- **Registration-to-close blended CPA target:** ≤ LTV / 4.
- **Show-rate lift economics:** 10-point show-rate lift ≈ 25–40% revenue lift per webinar.
- **Evergreen vs live:** live closes 1.5–2× better per attendee; evergreen scales with no host time. Model both.

## Common failure modes

1. **Teaching too abstract.** If the attendee can't walk away with one concrete thing they'll do tomorrow, retention dies. Fix: make each secret actionable today.
2. **Pitch tonal whiplash.** 60 min of teacher voice + 20 min of infomercial voice = bounce. Fix: frame the pitch as "the next step of what we just taught."
3. **Bonus inflation.** Listing 15 bonuses reads as fluff. Fix: 5 bonuses, each countering a specific objection.
4. **Fake urgency.** "Only 20 spots left!" (when there are 2000). Fix: real scarcity only — cohort start date, bonus expiration with calendar timestamp.
5. **No replay + no follow-up.** 60% of eventual buyers don't close live. Fix: 48-hour replay window + 3-email follow-up sequence.
6. **Registration spam (gift-card scam traffic).** Cold-traffic webinars attract fake registrants. Fix: require phone + captcha + source tracking; exclude obvious fake patterns.

## Variant: live vs evergreen

- **Live webinar:** host present, Q&A live, higher close rate per attendee, host-time intensive, scales via repetition or guest-host stacking.
- **Evergreen:** one-time production, 365-day distribution, lower close per attendee, scales with spend, attribution easier.
- **Hybrid:** quarterly live broadcasts + evergreen between — highest-effort, highest-leverage for established list.

## Upstream dependencies

- `/design-offer` — Value Equation + Stack + Guarantee ship-ready
- `/extract-voice` — so the teach doesn't feel generic
- `/build-icp` — to know which objections to pre-empt
- `/webinar-script` — the full script including Q&A playbook

## Downstream handoff

- `/email-sequence` — the promotion + follow-up sequences
- `/post-booking-nurture` — for application funnels after webinar
- `/launch-report` — post-cohort debrief

---
*v1.1 — Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
