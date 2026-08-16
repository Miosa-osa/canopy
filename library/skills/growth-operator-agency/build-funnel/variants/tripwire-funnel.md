# Tripwire Funnel — Archetype Playbook

> **When it wins:** Cold traffic at scale. $7–$97 front-end offer that liquidates ad spend (CAC offset), filters buyers from browsers, and ascends to higher-ticket offers.

## When to pick this archetype

- You want to scale ad spend on cold traffic without waiting months for ascension to pay back.
- Ascension ladder exists: core offer $500–$5K and/or high-ticket $5K+.
- Email list economics are load-bearing — tripwire buyers are 10–50× more likely to buy again than free opt-ins.
- ICP is pattern-matched: someone willing to pay $7 today is statistically closer to someone who'll pay $2K next month than a freebie-seeker.
- You have the economics modeled: how long does the average tripwire buyer take to ascend, and what's their 12-month LTV?

## The 5-stage structure

### 1. Awareness

- **Traffic:** paid cold at scale (Meta, TikTok, YouTube Shorts, Google).
- **Ad creative:** direct-response. "Get [specific thing] for $27" — product-led, not course-led.
- **Land:** short sales page (400–800 words) or direct-to-checkout.

### 2. Interest

- **Page or checkout:** mobile-first. Single hero section + proof stack + stack slide (for $27 that's often $50 or $100 of stacked value) + checkout.
- **CVR benchmark (cold):** 2–5% land → buy on a well-optimized tripwire.

### 3. Consideration

- **Order bump:** at checkout, offer a $10–$47 complement (increases AOV 30–50%).
- **Upsell #1 (one-click):** $47–$197 complement offer after checkout. Take rate 15–30%.
- **Upsell #2 (optional):** $197–$497 extended offer. Take rate 5–15%.

### 4. Decision

- **Cart complete + thank-you:** ship the digital product instantly. Every second of delay lowers ascension.
- **Immediate orientation email:** "here's what you just bought + what to do first."
- **Next-step offer teased:** the thank-you page itself points to the core offer ($500–$5K) as the natural next step.

### 5. Action

- **Post-sale ascension sequence:** 7–14 emails over 14–30 days moving the buyer toward the core offer.
- **Webinar invite (often the ascension mechanism):** tripwire buyer → invited to core-offer webinar within 14 days.
- **Call offer (for premium ladders):** for $10K+ core offers, tripwire buyers get a scheduled call invite after they've consumed the $27 product.

## CVR benchmarks

| Stage | Good | Great | Elite |
|---|---|---|---|
| Ad CTR | 1.0% | 2.0% | 3.0%+ |
| Land → checkout | 5% | 10% | 18%+ |
| Checkout → paid | 60% | 75% | 88%+ |
| Order bump take | 20% | 35% | 50%+ |
| Upsell #1 take | 15% | 25% | 35%+ |
| AOV ($27 front) | $32 | $42 | $58+ |
| 30-day ascension ($27 → $500+) | 2% | 5% | 10%+ |
| 12-month LTV | $80 | $180 | $400+ |

## Tech stack

- **Funnel / checkout:** ClickFunnels-class / SamCart / ThriveCart / custom Stripe checkout
- **Upsell engine:** platform-native one-click (critical — multi-step reduces take 50%+)
- **Email:** ConvertKit / ActiveCampaign / Klaviyo (segmented by tripwire-buyer tag)
- **Fulfillment:** instant-delivery via email / platform / membership area

## Creative requirements

- **Ad variants:** 20–40 in rotation. Tripwires fatigue FAST — new creative weekly.
- **Landing page:** 2–3 variants. Test hero-hook + proof-stack.
- **Upsell offers:** each upsell = 30–90 second video + scannable bullet list.
- **Email ascension sequence:** 7–14 emails (`skills/email-sequence/variants/post-purchase-sequence.md`).

## Economics

- **CAC offset:** the tripwire purchase should pay back a large portion (50–80%+) of CAC immediately.
- **Ascension math:** 30-day ascension rate × core offer price must exceed (CAC − tripwire gross profit) for break-even.
- **LTV:CAC target:** 3:1 blended.
- **Example economics:**
  - $27 front-end, 3% cold land → buy, $30 CPA, AOV $42 (with bumps + upsells) = pay back 140% of CAC immediately.
  - 5% 30-day ascension to $2K core offer = $100 additional LTV per front-end buyer.
  - 12-month LTV: $42 front + $100 ascension + continuity / backend = $180–$400+ blended.

## Common failure modes

1. **Tripwire doesn't filter.** Freebie-seekers and high-ticket buyers both show up. Fix: $27 minimum; free-or-paid split is a real filter.
2. **No order bump / upsell.** AOV flat = economics break at CAC > $30. Fix: add bumps ($10–$47) + one-click upsell ($47–$197).
3. **No ascension sequence.** Tripwire buyers don't move. Fix: 14-email sequence with webinar or call invite.
4. **Tripwire too generic.** "Swipe file" without a specific outcome. Fix: package = specific outcome the buyer can execute in 24 hours.
5. **Upsell irrelevance.** Bump / upsell doesn't match what tripwire promises. Fix: make upsell the obvious next-step extension.
6. **Compliance disaster.** Tripwire page claims unsupported results. Fix: income-claim / medical-claim compliance per `prompts/ad-creative-prompts.md` Prompt 10.

## Variant sub-archetypes

- **Free + shipping:** physical product ($7.95 shipping). Higher list-building, lower ascension.
- **Info tripwire ($17–$47):** checklist / swipe file / mini-course. Highest ascension rate.
- **Consultation tripwire ($97):** buyer pays for a 30-min strategy call. Highest close-rate on ascension.
- **Trial subscription ($1 / $7):** 7–14 day access to a recurring product. Best when continuity is the anchor.
- **Challenge ticket ($27):** paid challenge that ascends to core offer at the end. Blends tripwire + challenge funnel.

## Upstream dependencies

- `/tripwire-design` — 7-archetype $7–$97 entry offer playbook shipped
- `/design-offer` — core offer + upsells priced
- `/ad-creative` — 20+ creative variants in rotation
- `/email-sequence` — ascension sequence built

## Downstream handoff

- `/webinar-script` or `/sales-script` — the ascension mechanism
- `/build-vsl` — if ascension is VSL-led
- `/retention-check` — on ascended buyers

---
*v1.1 — Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
