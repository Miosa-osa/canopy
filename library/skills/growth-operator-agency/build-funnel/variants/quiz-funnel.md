# Quiz Funnel — Archetype Playbook

> **When it wins:** Outcome-variance markets (health, fitness, relationships, career, finance) where the prospect self-identifies into a specific type. Segmentation matters. Personalization drives close.

## When to pick this archetype

- Offer serves 3–6 distinct ICP segments with different pains / paths / price tiers.
- Prospect decision is emotionally charged (self-diagnosis creates buy-in).
- You have email list economics to justify the lower immediate close rate.
- Category is noisy and generic offers underperform ("Here's what I recommend based on YOUR answers" beats a static VSL).
- You can sustain 3–6 personalized result pages + follow-up tracks.

## The 5-stage structure

### 1. Awareness

- **Traffic:** paid (Meta / TikTok excellent), organic social, referrals.
- **Ad creative:** "Take this 90-second quiz to find out your [type/path/stage]" — curiosity-driven.
- **CVR benchmark:** quiz CTR 2–4% on cold traffic (higher than direct-to-VSL by 40–80%).

### 2. Interest

- **Quiz start page:** promise the outcome ("Find out which [X type] you are").
- **Quiz questions:** 5–10 questions, multiple-choice, conversational tone.
- **Completion rate target:** 75–90% (if below 65%, questions are too long, too many, or don't feel relevant).
- **Email capture:** AFTER the last question, BEFORE the result. "Where should we send your personalized plan?"
- **Email capture rate:** 60–80% of completers.

### 3. Consideration

- **Result page:** personalized based on the segment. 3–6 result-page variants, one per segment.
- **Result-page structure:**
  - "You are the [type]" headline
  - Brief description of the type (mirror their self-perception)
  - The specific next step for THIS type (gated by the offer)
  - Proof: success stories specifically from this type
  - CTA: book / buy / opt into segment-specific sequence

### 4. Decision

- **Post-quiz sequence (5–10 emails):** personalized per segment. Each sequence leads to a segment-specific offer.
- **Close mechanism:** depends on segment — some get book-a-call CTA, some get direct-checkout, some get webinar invite.
- **Segmentation drives close rate:** well-targeted segment-specific offer closes 2–4× better than generic.

### 5. Action

- **For closers:** standard post-sale onboarding (`skills/email-sequence/variants/post-purchase-sequence.md`).
- **For non-closers:** continued segment-specific nurture; eventual re-quiz invitation ("your type may have changed — retake to recalibrate").

## CVR benchmarks

| Stage | Good | Great | Elite |
|---|---|---|---|
| Ad CTR to quiz | 2% | 3.5% | 5%+ |
| Quiz completion | 70% | 85% | 92%+ |
| Email capture (at result) | 55% | 70% | 85%+ |
| Result → click offer | 15% | 30% | 50%+ |
| Email sequence → close | 2% | 5% | 10%+ |
| Blended ad click → close | 0.3% | 1.2% | 3.5%+ |

## Tech stack

- **Quiz platform:** Typeform / Involve.me / Outgrow / ScoreApp / LeadQuizzes / Tally / custom
- **Email / CRM:** ActiveCampaign / Klaviyo / Customer.io (segmentation is critical — platform choice matters)
- **Result pages:** dynamic-content landing pages (LeadPages / Unbounce / custom)
- **Analytics:** per-segment cohort tracking; conversion rate per segment
- **Attribution:** segment × ad creative × offer performance matrix

## Creative requirements

- **Quiz questions:** 5–10 that feel natural, not survey-style.
- **Result-page variants:** one per segment (3–6 pages).
- **Email sequences:** one per segment (5–10 emails each).
- **Ad creative:** curiosity-led "find out your type" angle + 10+ variants in rotation.

## Economics

- **LTV:CAC ≥ 3:1** blended.
- **Segment-level LTV varies:** some segments 2× others.
- **Segment prioritization:** double-down on high-LTV segments; trim or redirect low-LTV ones.
- **Cold-traffic quiz typically beats cold-traffic VSL on cost-per-email:** $1–$4 per quiz-finisher-email vs $5–$15 per VSL-optin-email.

## Common failure modes

1. **Generic result page.** All segments see the same "result." Defeats the funnel. Fix: 3+ real variants with distinct copy, proof, CTA.
2. **Too many questions.** Completion dies at 12+ questions. Fix: 5–10 max.
3. **Email capture before result.** Kills completion rate — buyers quit before finishing. Fix: capture email AFTER the last question, before revealing result.
4. **Segment-blind follow-up.** Everyone gets the same email sequence. Fix: one sequence per segment.
5. **Quiz questions too leading.** Prospect sees through the funnel. Fix: genuine multi-dimensional questions, not "are you a type-A or type-B" binary.
6. **No re-engagement mechanism.** Quiz non-buyers go cold. Fix: "your type may have changed" re-quiz invitation at 90 days.

## Variant sub-archetypes

- **Outcome quiz:** "Find out your X type" — the default. Self-diagnostic.
- **Readiness quiz:** "Find out if you're ready for X." Filters for commitment.
- **Calculator quiz:** "Calculate your potential X." Projects future outcomes + ties to the offer.
- **Diagnostic quiz (B2B):** "Diagnose your business's X bottleneck." Ascends to audit or consulting offer.

## Upstream dependencies

- `/build-icp` — 3–6 sub-segments identified with distinct pain/desire profiles
- `/design-offer` — offers mapped to each segment (same offer positioned differently, or genuinely different offers)
- `/extract-voice` — per-segment voice-of-customer language
- `/email-sequence` — one sequence per segment

## Downstream handoff

- `/build-vsl` or `/sales-script` — depending on segment's natural closing mechanism
- `/retention-check` — segment-level retention tracking

---
*v1.1 — Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
