# Flash Sale Funnel — Archetype Playbook

> **When it wins:** Hot audience (existing buyers, warm list, active community). 3–7 day urgency window. Revenue burst from relationship capital, not new acquisition.

## When to pick this archetype

- You have an engaged list (2K+ with 25%+ open rate) or community.
- Real urgency mechanism (limited-time bonus, cohort cap, price increase, holiday, anniversary).
- Current offer is undersold relative to its market fit — a push closes warm prospects who were on the fence.
- You need a revenue burst without scaling ad spend.
- You're willing to go dark for 30–60 days after a flash sale to protect list relationship.

## The 5-stage structure

### 1. Awareness

- **Traffic:** 100% warm — email list, SMS, community posts, social story teasers.
- **Zero cold-traffic dependency** (if cold traffic contributes, that's a separate evergreen funnel, not flash sale).

### 2. Interest

- **Pre-sale (1–3 days before):** teaser emails / posts. "Something's coming on [date]."
- **Open announcement:** email + SMS + community post + social.
- **Landing page:** sales page for the offer (can be minimal — the audience already knows the creator).
- **CVR benchmark:** warm-list open-to-sales-page click 15–30%.

### 3. Consideration

- **Sale window (3–7 days):** 5–10 emails during the window.
- **Cadence escalation:**
  - Day 1: open announcement + value-led intro
  - Day 2: objection-reframe email + proof-story email
  - Day 3: FAQ email (top 10 objections)
  - Day 4 (if 5-day): bonus reveal OR deeper objection reframe
  - Day 5 (last day): 2 emails — morning + final-hours

- **Community engagement:** 1–3 daily peer-visible conversations (testimonials, early buyers, questions).

### 4. Decision

- **Checkout or booking:** direct if self-serve; application if high-ticket.
- **Scarcity amplification (last 24h):** reminder emails at morning + mid-day + evening + final-2-hours.
- **Close rate on sale-window traffic:** 2–8% of list; 15–40% of click-to-sales-page traffic.

### 5. Action

- **Post-sale:** standard onboarding.
- **Post-sale for non-buyers:** gratitude + honesty email ("thanks for watching; next sale in ~60 days or here's the evergreen pricing").
- **Post-sale list hygiene:** remove excessive-openers-who-never-bought from active segments.

## CVR benchmarks

| Stage | Engaged list | Lightly-warm list |
|---|---|---|
| Pre-sale teaser open | 35–50% | 20–30% |
| Open announce → sales page visit | 20–35% | 8–15% |
| Sales page → purchase | 3–8% | 1.5–3% |
| Blended list → revenue event | 1–5% | 0.3–1.5% |

## Tech stack

- **Email:** ActiveCampaign / ConvertKit / Klaviyo (automation + segmentation critical)
- **SMS:** Twilio / Klaviyo SMS / platform-native
- **Community:** wherever you run your community
- **Checkout:** Stripe / SamCart / platform-native
- **Urgency countdown:** platform-native or Deadline Funnel (real-timer only; fake countdowns erode trust)

## Creative requirements

- **Pre-sale teasers:** 2–3 emails + social posts.
- **Sale-window sequence:** 5–10 emails.
- **SMS messages:** 3–5 during the window (opt-in only).
- **Community posts:** daily during sale.
- **Sales page updates:** can reuse existing sales page; refresh scarcity block.

## Economics

- **Revenue-per-email benchmark:** $0.50–$3.00 per engaged subscriber on a well-run flash sale.
- **Acquisition cost:** near-zero (warm list is already-acquired).
- **Flash-sale frequency:** max 4–6 per year to avoid list fatigue. Default 3–4.

## Common failure modes

1. **Fake urgency.** "50% off — 3 hours left!" reset every 3 hours. Fix: real deadlines, published calendar timestamps.
2. **Too frequent flash sales.** List fatigues → open rates drop → revenue-per-sale drops. Fix: 4 per year max.
3. **Pre-sale teaser too vague.** "Something's coming" without value → low pre-open. Fix: teaser delivers small value (insight, preview).
4. **Discount-addicted buyers.** List waits for next sale instead of buying at list price. Fix: don't discount the core offer; flash-sell bonuses / bundles / seats instead.
5. **No community amplification.** Sale is silent outside email inbox. Fix: parallel community posts + social stories.
6. **No post-sale debrief.** Revenue without learning. Fix: `/launch-report` for every flash sale.

## Variant sub-archetypes

- **Anniversary / milestone flash:** celebrates a real date; best excuse for a sale.
- **Cohort-close flash:** announces limited seats for an upcoming cohort.
- **Bonus-expiration flash:** existing offer + new bonus expires at date X.
- **Price-increase flash:** the price is going up on date X; lock in today.
- **Holiday flash:** Black Friday / end-of-year. Saturated but effective if audience is buyers.

## Upstream dependencies

- An engaged warm list (2K+, 25%+ open rate) OR engaged community
- `/design-offer` — the offer is ready
- `/email-sequence` — flash-sale sequence is built
- `/extract-voice` — urgency copy matches creator voice (doesn't drop into infomercial register)

## Downstream handoff

- `/launch-report` — post-sale debrief
- `/retention-check` — new buyers at 30 days
- `/case-study` — if flash-sale produced standout results

---
*v1.1 — Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
