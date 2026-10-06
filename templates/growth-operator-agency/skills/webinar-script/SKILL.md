---
name: webinar-script
description: Produce a webinar script using the 7-Figure Webinar Script structure (Intro 15-30 min / Content 45-60 min / Transition / Pitch / Q&A 30+ min). Voice-matched. Objection-handled. Bonus-stacked. Crossroads close. 6 delivery variants (Live / Evergreen / 3-Day Challenge / 5-Day / 7-Day / Workshop).
signal:
  mode: linguistic
  genre: webinar-script
  type: direct
  format: markdown
  structure: w-webinar-script-5-section
  receiver: webinar attendee
  receiver_capacity: high
department: nurture
agent_affinity: [nurture-head, webinar-producer]
required_compartments:
  audience_intelligence_system: 70
  offer_architecture: 70
  copy_messaging: 50
  education_nurture: 30
upstream_dependency: design-offer
execution_mode: interactive
tier: reasoning_ai
temperature_gate: warm
required_tools: [file_read, file_write]
required_mcps: [filesystem]
required_integrations:
  webinar: [zoom-api, livestorm-api, ever-webinar-api]
  email: convertkit-api                # for webinar-sequence emails
  crm: gohighlevel-api
  analytics: webinar-platform-native
credentials_required: [CONVERTKIT_API_KEY, GHL_API_KEY]
evidence_gate:
  - variant_selected
  - 5_section_structure_complete
  - 8_required_beliefs_installed
  - 10_plus_objections_handled_in_qa
  - bonus_stack_5_plus
  - crossroads_close_present
  - isomorphic_case_studies
  - voice_matched
  - signal_score_gte_0_8
  - blind_output_test_3_of_3
keywords:
  - webinar
  - webinar script
  - write webinar
  - challenge
  - 7 figure webinar
priority: 1
version: 1.0
---

# /webinar-script — 7-Figure Webinar Script (6 Variants)

## Role

Produce webinar scripts using the 7-Figure Webinar structure. Lineage: **7-Figure Webinar Script** (gamma.app canonical — 5-section structure), **the VSL director** (8 Required Beliefs + Crossroads Close), **the funnel-building platform founder** (3 Secrets webinar archetype — embedded in Content section), **the offer architect** (Bible Offer + Bonus Stacking + Price Anchoring), **the content OS director** (1-2 hours nurture-to-high-ticket rule).

Sacred format — requires **3/3 Blind Output Test pass** before live delivery to paid registrants.

## The 6 Delivery Variants

| # | Variant | Duration | Best For |
|---|---|---|---|
| 1 | **Live Webinar** | 90-120 min | Launch windows, authority + urgency boost |
| 2 | **Evergreen Webinar** | 60-90 min pre-recorded | 24/7 availability, scaleable |
| 3 | **3-Day Challenge** | 60-90 min × 3 days + close | $2K-$10K offers, community-building |
| 4 | **5-Day Challenge** | 60-90 min × 5 days + close | $3K-$15K offers, deeper indoctrination |
| 5 | **7-Day Challenge** | 60-90 min × 7 days + close | $5K-$30K offers, trust compound |
| 6 | **Workshop** | 60-180 min, teach-heavy | Technical/specialized niches |

## The 5-Section Structure (universal)

```
W(webinar) =
  Section 1 — Intro (15-30 min)
    - Opening Hook (pattern interrupt)
    - Authority Positioning (creator results + 3 testimonial types)
    - Sell Unique Mechanism (logical + emotional)
    - Create Commitments (logical yeses)
    - Open Loops (information gap)
    - Pre-Handle Objections (sprinkled)
  
  Section 2 — Content (45-60 min)
    - Teach WHAT, not HOW
    - 3-5 main steps / secrets
    - Per step: Context → Teaching → Pro Tips (setup bonuses, handle objections, micro-commitments, transition)
    - Between steps: commitment question
  
  Section 3 — Transition to Pitch
    - Recap learnings
    - 3-5 yes questions
    - Crossroads Close (action vs inaction)
    - Ask permission to pitch
  
  Section 4 — Pitch
    - Core offer (3-5 min)
    - Bonuses (min 5, 2nd-best first, best last)
    - Guarantee
    - CTA
  
  Section 5 — Q&A (30+ min)
    - Scripted objection destruction (Money / Time / Product-specific)
    - CTA after each objection handled
    - Close + final urgency
```

## Decision Logic

### Variant Selection
- Offer price $2K-$10K, creator can deliver live → Variant 1 or 3
- Offer $5K-$30K, heavy indoctrination needed → Variant 4 or 5
- Need 24/7 scalable → Variant 2 (evergreen, requires polished delivery)
- Technical niche, taught audience → Variant 6 (workshop)
- Community-first brand → Variant 3/4/5 (challenges)

### The 8 Required Beliefs — installed during webinar
From the VSL director. Each installed at specific section:
- Belief 1 (Reproduction — wants outcome): Opening Hook
- Belief 2 (Derivative desire): Authority section (creator's story)
- Belief 3 (Can-fulfill): Content Section 1-2
- Belief 4 (Urgency): Transition section
- Belief 5 (This offer): Mechanism sell + Pitch
- Belief 6 (Better/faster): Content section 3 + Guarantee
- Belief 7 (Trust-person): Authority + throughout
- Belief 8 (Trust-expertise): Content + Testimonials

### Bonus Stacking Rules
- Min 5 bonuses
- 2nd-best FIRST (hook)
- Best LAST (climax)
- Middle bonuses are OBJECTION COUNTERS
- Each tied to one objection from ICP Library

### Crossroads Close (Transition)
> "You have two options right now: option A — close this webinar and try to figure this out alone. Option B — take what we've shared and apply it with our mechanism + support. Both are valid. Only you can choose."

Forces action vs inaction decision. Non-optional for pitched webinars.

### The Content-Teaching Rule
> **Teach WHAT, not HOW.**

Give 3-5 main ideas/secrets. Each idea 8-15 min. Include:
- Context (why this matters)
- Teaching (high-level — not "module-1 of course")
- Pro Tips (setup bonuses, handle objections)
- Transition ("as if you already did it")
- Commitment question between steps

If you teach HOW (step-by-step implementation), attendee thinks they can do it alone. If you teach WHAT (the concepts + why they work), they need the offer to implement.

## Tacit Principles

1. **The hook's real job: grab attention AND create deep stay-desire.** Pattern interrupt from opening second. Audience has seen many boring webinars.

2. **Position as authority in first 30 min.** Results + testimonials + mission. Authority earns permission to teach.

3. **Unique mechanism is the spine.** Named, explained logically and emotionally in Section 1.

4. **Open loops for stay-rate.** Information gaps created in Intro, closed in Content, referenced in Pitch.

5. **Commitments are micro-yeses.** Get 20+ before pitch. Each commitment lowers friction for the buying yes.

6. **Pre-handle objections in Content.** By Pitch, every objection from ICP Library should already be crossed off.

7. **Bonuses counter objections 1:1.** Each bonus directly kills one specific objection.

8. **Q&A continues selling.** Scripted objection handling + CTA repetitions. Buyers are often made in Q&A, not Pitch.

9. **Price hint vs drop.** For $10K+ offers: "five figure investment" (lets them qualify themselves). For $2-5K: exact price.

10. **"This video is not selling you" = trust-leak.** Never say it. The offer reveal should feel inevitable, not surprising.

## Process

### Phase 0 — Load
- ICP Doc (objections, VOC, limiting belief)
- Offer Doc (value stack, bonuses, guarantee, mechanism)
- Positioning Doc (core belief, Big Enemy)
- Brand Voice Doc
- `reference/canonical/frameworks/classical/awareness-spectrum-5-levels.md`
- `reference/frameworks/sales/8-required-beliefs.md`
- `reference/operators/vsl-director.md`

### Phase 1 — Variant Selection
Apply decision tree + creator constraints (live delivery capacity, launch window, tech setup).

### Phase 2 — Section 1 — Intro (15-30 min)
- Opening Hook (pattern interrupt — "Live Proof" OR contrarian belief)
- Authority: creator results + 3 testimonial types (Expert Endorsement / Dream Result / Initial Win)
- Unique Mechanism sell (from Positioning Doc)
- 3-5 commitments (stay till end, take notes, ask questions)
- 3 open loops
- Pre-handle top 3 objections

### Phase 3 — Section 2 — Content (45-60 min)
- 3-5 main points (don't merge or split)
- Per point: Context → Teaching → Pro Tips → Commitment
- Between points: commitment question ("you see how that works?")
- Heavy mechanism thread

### Phase 4 — Section 3 — Transition
- Recap (2-3 min)
- 3-5 yes questions
- Crossroads Close
- Permission to pitch

### Phase 5 — Section 4 — Pitch
- Core offer explanation (3-5 min, components listed)
- Bonus stack (5+ bonuses, ordered per rule, each countering objection)
- Guarantee (ROI-positive)
- Price reveal (hint or drop per rule)
- CTA (specific, clear, urgent)

### Phase 6 — Section 5 — Q&A
- Scripted objections (Money / Time / Product-specific):
  - "I can't afford it" → reframe + ROI + payment plan
  - "I don't have time" → reframe + case study of busy implementer
  - "Will this work for my specific situation?" → isomorphic case study
- CTA after each objection
- Final urgency + close

### Phase 7 — Challenge Variants (3-Day / 5-Day / 7-Day)
If Variant 3/4/5:
- Day 1-N: daily content + community engagement
- Closing day: full 5-section webinar structure
- Between days: email + SMS + community reinforcement

### Phase 8 — Voice-Match + Compliance
- Voice-match throughout (3+ phrases per section)
- Banned vocab swept
- No income guarantees
- Truth Gate on all claims

### Phase 9 — Production Notes
- Slide deck outline (if slides)
- Props / demonstrations
- Live delivery vs evergreen differences
- Tech setup (Zoom / Livestorm / StreamYard)
- Chat moderation plan
- Replay handling

## Output Format

```markdown
# Webinar Script — [Creator Brand] — [Webinar Title]

**Variant:** [1 Live | 2 Evergreen | 3 3-Day | 4 5-Day | 5 7-Day | 6 Workshop]
**Runtime:** [N min]
**Offer Price:** $[N]
**Close Mechanism:** Crossroads Close
**Version:** 1.0

---

## Section 1 — Intro (15-30 min)

### Opening Hook
**[Time 0:00-0:03]**
> "[verbatim hook copy — pattern interrupt]"

### Authority Positioning
[creator results + 3 testimonial types]

### Unique Mechanism Sell
[name + logical + emotional]

### Commitments (3-5 logical yeses)
[...]

### Open Loops (3)
1. [loop 1 — closes at Content Section X]
2. [loop 2]
3. [loop 3]

### Pre-Handle Objections (3)
[top objections from ICP Library]

---

## Section 2 — Content (45-60 min)

### Point 1 — [Name]
**Context:** [...]
**Teaching:** [what, not how]
**Pro Tips:**
- [bonus setup]
- [objection pre-handle]
- [micro-commitment]
**Commitment question:** "[...]"

### Point 2 — [Name]
[repeat]

### Point 3 — [Name]
[repeat]

### Points 4-5 (if applicable)
[repeat]

---

## Section 3 — Transition to Pitch

### Recap
[2-3 min synthesis]

### 3-5 Yes Questions
[...]

### Crossroads Close
> "[verbatim close]"

### Permission to Pitch
> "[verbatim]"

---

## Section 4 — Pitch

### Core Offer (3-5 min)
[components from Offer Doc]

### Bonus Stack
#### Bonus 1 — [2nd-best]
- Value: $[N]
- Objection countered: [...]

#### Bonus 2 — [middle]
[...]

#### Bonus 3 — [middle]
[...]

#### Bonus 4 — [middle]
[...]

#### Bonus 5 — [BEST]
- Value: $[N]
- Objection countered: [...]

### Guarantee
[ROI-positive guarantee copy]

### Price Reveal
[hint or drop per rule]

### CTA
[specific, clear, urgent]

---

## Section 5 — Q&A (30+ min)

### Scripted Objections
#### Money
> Objection: "[verbatim]"
> Response: [reframe + ROI + payment plan]
> CTA: [repeat]

#### Time
[...]

#### Product-Specific
[top 5-10 product-specific objections with scripted responses]

### Final Urgency + Close
[...]

---

## Challenge Variant (if 3/5/7-day)

### Day 1 — [Topic]
[content outline + community engagement]

### Day 2 — [Topic]
[...]

### Closing Day
[full 5-section webinar above]

### Between-Days Reinforcement
- Email: [brief]
- SMS: [brief]
- Community: [rituals]

---

## Production Notes
- Platform: [Zoom / Livestorm / StreamYard]
- Slides: [outline]
- Props: [...]
- Chat plan: [moderators + CTAs in chat]
- Replay: [window + nurture sequence]

## Voice-Match Audit
[phrases_to_use distribution]

## Compliance
- [ ] No income guarantees
- [ ] Testimonials with FTC disclosure
- [ ] Banned vocabulary clean
- [ ] Truth Gate on all claims
- [ ] Refund / guarantee language legal-reviewed

---

## Appendix A — 8 Required Beliefs Installation Map
[which belief installed in which section + reinforcement points]

## Appendix B — Isomorphic Case Studies Selected
[3-5 case studies mapped by fit]

## Appendix C — Bonus → Objection Map
[bonus-by-bonus objection countering table]
```

## Important Rules

- **NEVER teach HOW** — teach WHAT, with just enough context.
- **NEVER say "this isn't selling you."**
- **NEVER skip the Crossroads Close.**
- **NEVER fabricate results / testimonials.**
- **NEVER close without Q&A** — 30%+ of conversions happen in Q&A.
- **ALWAYS install all 8 Required Beliefs.**
- **ALWAYS stack 5+ bonuses ordered correctly.**
- **ALWAYS pre-handle objections in Content, finish them in Q&A.**
- **ALWAYS use isomorphic case studies.**
- **ALWAYS 3/3 Blind Output Test before live.**

## Verification Checklist

- [ ] Variant selected
- [ ] 5 sections complete with time targets
- [ ] 8 Required Beliefs installed
- [ ] 10+ objections handled in Q&A
- [ ] 5+ bonuses with objection mapping
- [ ] Crossroads Close present
- [ ] 3+ isomorphic case studies
- [ ] Voice-matched
- [ ] Compliance passed
- [ ] Production notes complete
- [ ] Challenge variant day-by-day plan (if applicable)
- [ ] Triple-layer S/N ≥ 0.8
- [ ] Blind Output Test scheduled

## Next Skills

- `/email-sequence` type 4 Webinar — promotion sequence
- `/post-booking-nurture` — if webinar routes to calls
- `/write-linkedin-post` — webinar invite content

## References

- `reference/frameworks/sales/8-required-beliefs.md` (15-step VSL methodology)
- `reference/frameworks/sales/crossroads-close.md`
- `reference/frameworks/esoteric-marketing/README.md` (the offer architect — Bible Offer + Bonus Stacking)
- `reference/operators/vsl-director.md`
- `reference/operators/content-os-director.md` (1-2 hour nurture-to-high-ticket rule)
- `reference/sub-agents/webinar/` (Growth Operating Agency canonical source)

---
*v1.0 — 2026-04-19. Cycle 4 Educate. Sacred format — Blind Output Test required.*
