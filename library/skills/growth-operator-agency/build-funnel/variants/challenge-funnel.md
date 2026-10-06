# Challenge Funnel — Archetype Playbook

> **When it wins:** Transformation-first offers where belief installation requires multi-day immersion. Cohort launches. Pre-sold communities. List-building + cohort-closing in one motion.

## When to pick this archetype

- Offer requires deep belief installation (prospect needs to experience the method, not just hear about it).
- Cohort-based delivery with real start date and real seat cap.
- You have the hosting capacity for live daily engagement for 3–7 days.
- Pre-built list or warm audience to pull in (cold traffic converts 50%+ worse in challenges; only run cold if modeled).
- Mid-to-high ticket ($997–$10K) offer waiting at the end.

## The 5-stage structure

### 1. Awareness

- **Traffic:** list + social + paid retargeting.
- **Ad / post creative:** invitation-style. "Join my 5-day [outcome] challenge" — outcome-led, not method-led.
- **Landing:** registration page (email + first name; add phone for SMS opt-in).

### 2. Interest

- **Registration nurture (3–7 days before challenge):**
  - Confirmation email + calendar
  - Workbook / pre-work delivery
  - Daily hype email ("here's what to expect on Day 1")
  - 24h reminder + SMS

- **Show-rate target:** 35–55% on Day 1 (warm list 50%+; cold traffic 25–40%).

### 3. Consideration

- **Challenge body (3, 5, or 7 days):**
  - **Day 1:** big promise + quick win + momentum tactic
  - **Day 2:** teach mechanism pillar 1 + assignment
  - **Day 3:** teach mechanism pillar 2 + assignment
  - **Day 4 (if 5-day):** teach mechanism pillar 3 + community engagement peak
  - **Day 5 (last day):** synthesize + reveal offer

- **Engagement mechanics:** daily live calls + private group (Skool / Facebook / Circle / Discord) + peer-to-peer activity + accountability posts.

### 4. Decision

- **Offer reveal (last day):**
  - 45–90 min session
  - Recap of what was taught + what comes next (the offer)
  - Stack slide + guarantee + scarcity (cohort start, bonus expiration)
  - Cart opens same-day, closes 24–72 hours later

- **Close rate target:** 5–15% of challenge attendees who show on last day convert (significantly higher than webinar because of belief installation depth).

### 5. Action

- **Cart open window:** 24–72 hours typical.
- **Follow-up emails:** 3–7 emails during cart-open — each addressing one top objection.
- **Community nudge:** peer-to-peer visibility — who's in the program, who just joined, community celebration.
- **Post-cart nurture:** those who didn't close → wait-list / next-cohort nurture.

## CVR benchmarks

| Stage | Warm list | Cold retargeted |
|---|---|---|
| Traffic → registration | 25–45% | 8–18% |
| Registration → Day 1 show | 35–55% | 20–40% |
| Day 1 → final-day show | 40–65% | 25–45% |
| Final-day show → buy | 5–15% | 3–8% |
| Blended traffic → close | 1–4% | 0.2–1% |

## Tech stack

- **Hosting:** Zoom + StreamYard (live daily calls)
- **Community:** Facebook Group / Skool / Circle / Discord (choose one; don't split)
- **Email + SMS:** ActiveCampaign + Twilio / ConvertKit + Klaviyo SMS
- **Registration page:** funnel builder or custom
- **Checkout:** Stripe / SamCart / platform-native
- **Replay hosting:** Wistia / Vimeo / platform-native

## Creative requirements

- **Registration ad / post:** 5–8 variants.
- **Pre-challenge nurture:** 4–6 emails over 3–7 days (`skills/email-sequence/variants/welcome-sequence.md` adapted for challenge hype).
- **Daily teach slides:** 30–60 slides per day.
- **Offer-reveal deck:** 40–80 slides on the last day (stack slide + guarantee + scarcity).
- **Cart sequence:** 5–8 emails during cart-open.

## Economics

- **CAC on challenge traffic:** cheaper than VSL traffic typically (invitation-style converts better).
- **Close rate on cohort:** 5–15% of final-day attendees.
- **Blended LTV:CAC ≥ 3:1** required.
- **Cohort profitability math:** 100 final-day attendees × 10% close × $2K price = $20K cohort revenue; if cohort cost (ads + team time + platform) < $8K, LTV:CAC is 2.5:1+.

## Common failure modes

1. **Teaching too theoretical.** Attendees don't experience a concrete win by Day 2. Fix: quick-win on Day 1 non-negotiable.
2. **Community dies on Day 2.** Fix: host-driven engagement posts + 3 peer-hero features per day.
3. **Offer reveal feels like infomercial.** Fix: frame the offer as "the next step of the method you just experienced" — tonal continuity.
4. **Cart window too long (> 72h).** Urgency dies. Fix: 48h cart window max for challenges.
5. **No wait-list for non-closers.** Next cohort has to re-acquire. Fix: "join wait-list for next cohort + $X early-bird" sequence.
6. **Replay distribution unclear.** Attendees miss a day and disengage. Fix: 24h replay window with Day-N+1 email reset.

## Variant sub-archetypes

- **3-day challenge:** fastest cadence, lower close but higher completion. Good for warm list re-engagement.
- **5-day challenge:** the default. Deepest belief installation + manageable host time.
- **7-day challenge:** longest arc, highest transformation, high no-show risk Day 5–7.
- **Paid challenge ($27–$97):** tripwire + challenge hybrid. Buyers who paid to be in filter harder + convert better.
- **Free challenge:** classic funnel. Highest registration volume, lowest filter.

## Upstream dependencies

- `/design-offer` — core offer ready + cohort seat cap defined
- `/extract-voice` — challenge voice matches daily-speak, not corporate
- `/webinar-script` — offer-reveal session script
- `/email-sequence` — pre-challenge + during + cart sequences

## Downstream handoff

- `/post-booking-nurture` — if challenge ends in book-a-call / application
- `/launch-report` — post-cohort retrospective
- `/retention-check` — on closed cohort members

---
*v1.1 — Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
