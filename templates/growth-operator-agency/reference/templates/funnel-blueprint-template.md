# Funnel a longevity-protocol — 7-Archetype Template

> **Source skill:** `/build-funnel`
> **Output location:** `output/build-funnel/{YYYY-MM-DD}-funnel-blueprint.md`
> **Structure:** one template covering 7 funnel archetypes
> **Gate:** archetype chosen with reasoning, every stage has a mapped asset, traffic-to-buyer path drawn, conversion gates quantified, tech + tracking plan specified.

Replace every `[FILL]` with real content. Do not ship with brackets remaining.

---

# Funnel a longevity-protocol — [Creator Brand] — [Funnel Name]

**Funnel archetype:** [VSL / Webinar / Application / Book-a-Call / Tripwire / Challenge / Community]
**Primary offer:** [FILL]
**Target ICP segment:** [FILL — from ICP Doc]
**Awareness level served:** [Problem-aware / Solution-aware / Product-aware / Most-aware]
**Funnel goal:** [enrollment in [offer] / booked calls / subscribers / email opt-ins]
**Confidence:** [H / M / L]
**Version:** 1.0

---

## 7 Funnel Archetypes (Decision Matrix)

| Archetype | Best when | Price tier | Sales motion | Average conversion (of qualified traffic) |
|---|---|---|---|---|
| VSL | Solution-aware audience, $1K-$10K offer, scalable paid traffic | $1K-$10K | Self-serve or soft apply | 1-5% |
| Webinar | Need teaching before pitch, $500-$5K | $500-$5K | Live event → CTA | 3-8% |
| Application | High-ticket ($10K+), need qualification | $10K-$100K | App → call → close | 20-40% app-to-close |
| Book-a-Call | $5K-$50K, high-touch closer model | $5K-$50K | Direct call booking | 15-35% |
| Tripwire | List-building + economics-offset | $7-$97 | Low-friction buy | 5-15% |
| Challenge | Community-driven, commitment-based | $300-$3K | Multi-day event → pitch | 5-10% |
| Community | Membership, monthly recurring | $47-$297/mo | Free trial or direct | 2-8% |

---

## 1. Archetype Selection + Reasoning

### 1.1 Archetype chosen

**[FILL — archetype]**

### 1.2 Why this archetype

[FILL — 2-3 sentences. Why this archetype fits the ICP's awareness level, the offer's price tier, and the creator's channel strengths.]

### 1.3 Rejected archetypes

| Rejected | Why rejected |
|---|---|
| [FILL] | [FILL] |
| [FILL] | [FILL] |

---

## 2. Funnel Structure (5-Stage)

> Every funnel has 5 stages regardless of archetype: Awareness → Interest → Consideration → Decision → Action.

### 2.1 Stage: Awareness

**Goal:** prospect encounters the creator for the first time.

**Traffic mechanism:** [FILL — cold paid ads / organic content / SEO / referral / JV]

**Hook framework:** [FILL — pattern interrupt / curiosity-gap / big-number / identity call-out]

**Asset required:** [FILL — ad creative / post / video]

**KPIs:**
- CTR / thumbstop: [target]
- Cost per click: $[target]

### 2.2 Stage: Interest

**Goal:** prospect opts in or clicks through.

**Mechanism:** [lead magnet opt-in / VSL click-through / registration / direct sales page]

**Delivery asset:** [FILL]

**Opt-in page:** [FILL — see `lead-magnet-brief.md` Section 4 for opt-in page structure]

**KPIs:**
- Opt-in rate: [target]
- Cost per lead: $[target]

### 2.3 Stage: Consideration

**Goal:** prospect consumes content + develops belief in the mechanism.

**Mechanism:** [email sequence / VSL watch / webinar attendance / challenge days 1-N]

**Belief installation framework:** reference 8 Required Beliefs from `/design-offer`

**Asset(s):** [FILL — email sequence / webinar / VSL / nurture content]

**KPIs:**
- Consumption rate: [target]
- Content engagement: [target]

### 2.4 Stage: Decision

**Goal:** prospect decides to buy / apply / book.

**Mechanism:** [CTA click → checkout / application / call booking]

**Sales mechanism per archetype:**

- VSL: primary CTA at end of VSL
- Webinar: CTA during pitch segment + email sequence
- Application: application form → scored → call booked
- Book-a-Call: direct calendar booking
- Tripwire: checkout page
- Challenge: Day N pitch → CTA
- Community: free trial or direct sign-up

**KPIs:**
- CTA click rate: [target]
- CTA → next-step completion: [target]

### 2.5 Stage: Action

**Goal:** prospect completes the purchase / application / booking.

**Mechanism:** [checkout / application submit / call-scheduled / trial-activated]

**Post-action trigger:** [confirmation email / post-booking nurture / community invite]

**KPIs:**
- Checkout conversion: [target]
- Abandoned cart recovery: [target]
- Show-up rate (if call booked): [target]

---

## 3. Archetype-Specific Blueprints

### 3.1 If VSL Funnel

**Structure:** Ad → Opt-in → VSL → CTA → Checkout

| Asset | Skill | Status |
|---|---|---|
| Ad creative | `/ad-creative` | |
| Opt-in page | [page builder] | |
| VSL | `/build-vsl` | |
| Sales page (optional below VSL) | `/build-funnel` | |
| Checkout | [payment processor + {FUNNEL_BUILDER}] | |
| Post-purchase upsell | `/design-offer` | |
| Email follow-up | `/email-sequence` | |

**Traffic → VSL watch:** conversion target [%]
**VSL watch → CTA click:** [%]
**CTA click → checkout:** [%]
**Checkout completion:** [%]

### 3.2 If Webinar Funnel

**Structure:** Ad → Registration → Reminder sequence → Live event → Pitch → CTA → Application/Checkout

| Asset | Skill | Status |
|---|---|---|
| Ad creative (registration-focused) | `/ad-creative` | |
| Registration page | [page builder] | |
| Confirmation + reminder emails | `/email-sequence` | |
| Webinar script | `/webinar-script` | |
| Webinar platform | [Zoom / {WEBINAR_PLATFORM}] | |
| Pitch slide deck | [design] | |
| Sales page or application form | `/build-funnel` | |
| Post-webinar sequence | `/email-sequence` | |

**Registration → show-up:** [target %]
**Show-up → stay-to-pitch:** [%]
**Stay-to-pitch → CTA:** [%]
**CTA → close (on-call or self-serve):** [%]

### 3.3 If Application Funnel

**Structure:** Ad → VSL or landing page → Application form → Screening → Call → Close

| Asset | Skill | Status |
|---|---|---|
| Ad creative (authority-heavy) | `/ad-creative` | |
| Landing page / VSL | `/build-funnel` / `/build-vsl` | |
| Application form | `/application-form` (v1.1 roadmap) | |
| Screening criteria | `/design-offer` | |
| Booking page | [calendar tool] | |
| Pre-call nurture | `/post-booking-nurture` | |
| Sales script | `/sales-script` (v1.1 roadmap) | |
| Post-call follow-up | `/email-sequence` | |

**Traffic → application start:** [%]
**Application → qualified:** [%]
**Qualified → call booked:** [%]
**Call booked → call attended:** [%]
**Call attended → close:** [%]

### 3.4 If Book-a-Call Funnel

**Structure:** Ad → Landing page → Direct calendar → Pre-call nurture → Call → Close

Similar to Application but with lower friction at booking stage. Use when qualification happens on the call rather than via form.

### 3.5 If Tripwire Funnel

**Structure:** Ad → Landing page → $7-$97 purchase → Order bump → Upsell → Downsell → Email ascension

| Asset | Skill | Status |
|---|---|---|
| Ad creative | `/ad-creative` | |
| Tripwire offer page | `/tripwire-design` (v1.1 roadmap) | |
| Order bump (+ $X at checkout) | `/design-offer` | |
| Upsell 1 (post-purchase) | `/design-offer` | |
| Downsell (if upsell declined) | `/design-offer` | |
| Email ascension sequence | `/email-sequence` | |

**Conversion economics:**
- Tripwire conversion: [%]
- Order bump attach: [%]
- Upsell 1 attach: [%]
- Blended AOV: $[N]
- CAC coverage goal: [tripwire AOV >= CAC]

### 3.6 If Challenge Funnel

**Structure:** Ad → Registration → Pre-launch emails → Days 1-N → Pitch day → CTA → Enrollment

Cross-reference `webinar-script-challenge.md` for the challenge structure itself.

| Asset | Skill | Status |
|---|---|---|
| Ad creative (promise-led) | `/ad-creative` | |
| Registration page | [page builder] | |
| Pre-launch emails | `/email-sequence` | |
| Daily challenge scripts | `/webinar-script` (challenge variant) | |
| Community / platform | [community platform] | |
| Pitch day script | `/webinar-script` | |
| Application form or sales page | `/build-funnel` | |

### 3.7 If Community Funnel

**Structure:** Ad → Landing page → Free trial or direct sign-up → Onboarding → Monthly recurring

| Asset | Skill | Status |
|---|---|---|
| Ad creative | `/ad-creative` | |
| Community landing page | `/build-funnel` | |
| Free trial mechanism | [community platform] | |
| Onboarding sequence | `/post-booking-nurture` or `/email-sequence` Type 7 | |
| Retention / engagement calendar | `/retention-check` | |
| Churn recovery sequence | `/email-sequence` | |

**Economics:**
- Trial → paid: [%]
- Month 2 retention: [%]
- Month 6 retention: [%]
- Avg LTV: $[N]

---

## 4. Traffic Source Plan

### 4.1 Paid

| Channel | Budget | Target CPA | Creative type | Owner |
|---|---|---|---|---|
| META | $[N]/day | $[N] | [video / carousel / static] | [FILL] |
| YouTube | $[N]/day | $[N] | [pre-roll / in-stream] | [FILL] |
| TikTok | $[N]/day | $[N] | [native-style video] | [FILL] |
| LinkedIn | $[N]/day | $[N] | [thought leader / sponsored content] | [FILL] |
| Google | $[N]/day | $[N] | [search / display] | [FILL] |

### 4.2 Organic

| Channel | Cadence | Expected contribution | Owner |
|---|---|---|---|
| YouTube | [FILL] | [FILL] | [FILL] |
| LinkedIn | | | |
| Instagram | | | |
| Podcast | | | |
| Newsletter | | | |

### 4.3 Partnerships

| Partner type | Count target | Terms | Owner |
|---|---|---|---|
| Affiliates | [N] | [commission %] | [FILL] |
| JV webinars | [N] | [rev-share / CPA] | [FILL] |
| Podcast guest spots | [N] | [exposure] | [FILL] |
| Newsletter cross-promotions | [N] | [mutual plug] | [FILL] |

---

## 5. Tech Stack Requirements

### 5.1 Core platforms

- Funnel / landing page builder: [FILL — {FUNNEL_BUILDER}]
- Email platform: [FILL]
- CRM: [FILL]
- Payment processor: [FILL]
- Analytics: [FILL — Google Analytics / Mixpanel / custom]
- Tracking pixels: [META / TikTok / Google / LinkedIn]
- Calendar / booking: [FILL]
- Video hosting (VSL / webinar replay): [FILL]
- Community platform (if applicable): [FILL]
- SMS platform (if applicable): [FILL]

### 5.2 Integrations

| From | To | Trigger | Data sent |
|---|---|---|---|
| Opt-in form | Email platform | Submit | name, email, UTMs, source |
| Email platform | CRM | Tag assignment | contact update |
| Payment processor | CRM | Purchase | contact + order |
| Booking tool | CRM | Call booked | contact + event |
| CRM | SMS platform | Event trigger | phone + message |

### 5.3 Tracking plan

| Event | Source | Pixel | CRM field |
|---|---|---|---|
| Page view | page | META / Google | — |
| Opt-in | form | META / Google | lead-status |
| Add to cart | checkout | META / Google | lead-status |
| Purchase | payment processor | META / Google | customer-status |
| Application submit | form | META / Google | lead-status |
| Call booked | calendar | META / Google | lead-status |
| No-show | calendar | — | lead-status |

---

## 6. Sequencing (Asset Dependency Graph)

Order of asset production for this funnel:

1. **Upstream foundations (prerequisite):** ICP → Positioning → Offer → Brand Voice → Case Studies
2. **Consideration-stage asset** (biggest work item): [VSL / Webinar / Challenge / Application]
3. **Landing pages:** opt-in + sales
4. **Email sequences:** indoctrination + nurture + conversion
5. **Ad creative pack:** 5-10 variants per stage
6. **Tracking + integrations:** verified end-to-end
7. **Launch + iterate**

---

## 7. Optimization Priorities

### 7.1 KPIs to monitor weekly

| KPI | Baseline | Target | Warning threshold |
|---|---|---|---|
| CPC | | | |
| Opt-in rate | | | |
| Consumption rate | | | |
| CTA click rate | | | |
| Checkout conversion | | | |
| CPA | | | |
| ROAS | | | |

### 7.2 Test priority (stack ranked)

1. [FILL — highest-leverage variable to test first, usually hook or offer]
2. [FILL]
3. [FILL]

### 7.3 When to kill vs when to scale

- Kill: [FILL — criteria]
- Scale: [FILL — criteria]

---

## Appendix A — Funnel Diagram

Draw a visual funnel map with:
- Traffic sources on the left
- Stages across
- KPIs per stage
- Asset name per stage
- Drop-off points highlighted

[Attach / link the diagram here once produced.]

## Appendix B — Conversion Benchmarks by Archetype

| Archetype | Cold-traffic end-to-end rate | Warm-traffic rate |
|---|---|---|
| VSL | 0.5-3% | 2-8% |
| Webinar | 1-4% | 3-10% |
| Application | 0.5-2% (to close) | 2-5% |
| Book-a-Call | 0.5-2% | 2-6% |
| Tripwire | 2-8% | 5-15% |
| Challenge | 2-5% | 5-12% |
| Community | 1-4% (trial to paid) | 3-8% |

Benchmarks vary widely by niche. Use ICP Doc + Market Research Brief to calibrate.

## Appendix C — Common Funnel Pitfalls

- Mismatch between awareness level and funnel entry point (e.g., cold-traffic into Product-aware VSL)
- Offer-funnel mismatch (high-ticket through self-serve checkout without qualification)
- Missing consideration-stage asset (going straight from click to close)
- Tracking gaps (pixel not firing, UTMs lost at checkout, no backend attribution)
- No abandoned-cart or no-show recovery
- Platform single-point-of-failure (if email goes down, the funnel dies)

## Appendix D — Funnel Iteration Log

| Date | Change | Hypothesis | Result | Kept? |
|---|---|---|---|---|
| | | | | |

---

*Funnel a longevity-protocol template v1.0 — Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
