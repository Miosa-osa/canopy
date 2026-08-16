# VSL Funnel — Archetype Playbook

> **When it wins:** Cold-traffic acquisition at scale for a solution-aware or offer-aware market buying a $1K–$10K offer where the prospect needs a 30–60 minute belief arc before they're ready to convert.

## When to pick this archetype over the others

- Traffic is primarily paid (Meta, YouTube, TikTok, Google) and not warm.
- Offer price is $997–$10K; below that, short-form + checkout converts cheaper; above that, application funnel filters better.
- ICP can sit through 20–60 minutes of video — reachable, patient, problem-aware.
- You have verifiable proof (case studies, numbers, authority signal) strong enough to earn that attention.
- Market sophistication is **solution-aware** (they know solutions exist) or **offer-aware** (they've tried some). If they're **unaware**, pair the VSL with a tripwire or a lead magnet that surfaces the problem first.

## The 5-stage structure

### 1. Awareness

- **Traffic source:** Meta / YouTube / TikTok / Google paid.
- **Creative:** 15–45 second hook ad using one of 30 hook archetypes (`reference/swipe-file/hooks/`). Hook promises the teaching the VSL will deliver, not the offer.
- **Landing:** hook ad → VSL page. No sub-pages between. Frictionless click-to-watch.
- **CVR benchmark:** ad CTR 1.0–2.5%; cold-page visit → VSL open 45–70%.

### 2. Interest

- **VSL start (0:00–2:00):** hook re-stated + credibility injection + promise of payoff + immediate teaching beat to earn the next 5 minutes.
- **30-second retention benchmark:** ≥ 55% on cold traffic. Below 45% → rewrite the first 2 minutes.
- **Pattern interrupts:** every 45–90 seconds for the first 10 minutes.

### 3. Consideration

- **Body (2:00–40:00):** the 15-step VSL structure (`skills/build-vsl/SKILL.md` for the full 15-step framework). Installs the 8 required beliefs.
- **Mechanism reveal:** unique mechanism named + taught in 3–5 minutes in the mid-body.
- **Proof injection:** case studies + verifiable numbers + authority signals at 3 spaced intervals (mid-body + pre-stack + pre-close).

### 4. Decision

- **Stack slide:** 6–10 components with dollar values totaling ≥ 5× price (`skills/landing-page/SKILL.md` for the research-mechanism-brief-copy 7-section offer page structure).
- **Price reveal:** one of 5 price-reveal mechanics (contrast, ratio, reinvestment, identity, takeaway — see `prompts/vsl-prompts.md` Prompt 7).
- **Guarantee:** one of 3 refund-policy variants (`reference/legal-templates/refund-policy.md`).
- **Scarcity (real):** cohort start, price increase, bonus expiration — real, not fake.

### 5. Action

- **Thank-you page:** confirmation + personal-SMS trigger + 24h / 6h / 1h reminder sequence (`skills/post-booking-nurture/SKILL.md`).
- **Email sequence post-opt-in:** welcome + indoctrination + objection pre-empt + cart-close reminder (`skills/email-sequence/variants/launch-sequence.md`).
- **Call booking (if applicable):** direct to Calendly / setter queue / application form.

## CVR benchmarks (cold traffic)

| Stage | Good | Great | Elite |
|---|---|---|---|
| Ad CTR | 1.0% | 1.8% | 2.5%+ |
| Cold VSL page → opt-in | 8% | 15% | 25%+ |
| Opt-in → cart / book | 10% | 18% | 30%+ |
| Cart / book → close | 15% | 25% | 40%+ |
| Blended cold traffic → close | 0.4% | 1.2% | 3.0%+ |

## Tech stack

- **Funnel builder:** ClickFunnels-class tool / GoHighLevel / custom / Framer / Webflow + Stripe
- **Video host:** Wistia / VdoCipher / Vimeo (analytics matter; don't use YouTube for VSL hosting — reach data is weaker)
- **Email + CRM:** ConvertKit / ActiveCampaign / Klaviyo / Customer.io
- **Scheduler:** Calendly / SavvyCal / Acuity
- **Attribution:** platform-native pixels + Triple Whale / Hyros / custom server-side for > $50K/mo spend

## Creative requirements

- **Hook ads:** 15–25 variants in rotation at launch. Fatigue appears at 500K–1M impressions per variant.
- **VSL versions:** minimum 2 (long + short), A/B the first 60 seconds.
- **Thumbnail:** if on YouTube, 3-element thumbnail at mobile size.
- **Retargeting creative:** different from cold; addresses the specific objection at each drop-off point.

## Economics required

- **LTV:CAC ≥ 3:1** at blended funnel level. Below 2:1, kill the funnel.
- **Payback period:** target ≤ 90 days on cold spend.
- **Break-even CAC:** compute at your gross margin; cold can spend up to (margin × LTV × 0.33).

## Common failure modes

1. **Hook / VSL mismatch** — hook ad promises X, VSL delivers Y. Fix: rewrite first 60 seconds of VSL to pay off the ad's hook immediately.
2. **Pace too slow first 10 minutes** — retention dies at 5–7 minutes. Fix: add pattern interrupts, tighten the lineage / credentials section.
3. **Mechanism reveal too late** — viewer leaves before mechanism installs. Fix: move to 18–22 minutes max.
4. **Stack slide too short** — feels like sales page, not stack. Fix: expand to 6–10 components with dollar anchors.
5. **Guarantee too vague** — "money-back" without conditions reads as unprotected. Fix: conditional-guarantee variant from `reference/legal-templates/refund-policy.md`.
6. **No retargeting** — 90% of clickers don't buy on first session. Fix: 14-day retargeting sequence addressing top-3 objections.
7. **Attribution confusion** — can't tell which ad drives close. Fix: server-side event + unique promo code per creative family.

## When NOT to use the VSL funnel

- Offer below $500 → use tripwire / flash-sale.
- Offer above $10K with need for heavy qualification → use application funnel.
- ICP with low video attention span (executives, physicians) → use book-funnel or DM-to-close.
- Category saturated with VSLs (generic coaching, trading) → differentiate with newsletter-led or community-lead-magnet.

## Upstream dependencies

- `/design-offer` — Value Equation ≥ 150 + LTV:CAC modeled
- `/build-vsl` — the 15-step script is shipped
- `/build-icp` — Completeness ≥ 80
- `/ad-creative` — 15+ hook variants produced
- `/landing-page` — the offer / thank-you pages are built

## Downstream handoff

- `/plan-launch` — if the VSL anchors a timed launch
- `/post-booking-nurture` — for calls booked from the funnel
- `/launch-report` — post-cart-close retrospective
- `/retention-check` — on closed buyers after 30 days

---
*v1.1 — Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
