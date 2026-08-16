---
name: story-sequence
description: Produce 7-day Instagram Story sequence using the stories director's 4-layer story anatomy + 7-day content calendar (Proof / Clarity / Objection Break / Education-Differentiation / Connection / Proof+Skepticism Removal / Mission). 2-4 stories per day. Text + image + proof-screenshots + visuals.
signal:
  mode: linguistic
  genre: story-sequence
  type: inform
  format: markdown
  structure: w-story-sequence-7-day
  receiver: IG followers + story viewers
  receiver_capacity: low
department: marketing
agent_affinity: [marketing-head, stories-producer]
required_compartments:
  audience_intelligence_system: 50
  offer_architecture: 40
  copy_messaging: 30
  content_strategy: 20
upstream_dependency: content-calendar
execution_mode: interactive
tier: structured_ai
temperature_gate: warm
required_tools: [file_read, file_write]
required_mcps: [filesystem]
required_integrations:
  social_posting: instagram-graph-api
  scheduling: buffer-api
credentials_required: [INSTAGRAM_ACCESS_TOKEN, INSTAGRAM_BUSINESS_ACCOUNT_ID]
evidence_gate:
  - 7_day_calendar_complete
  - per_story_4_layer_anatomy_applied
  - orange_grey_mix_balanced
  - daily_framework_not_repeated
  - voice_matched
  - signal_score_gte_0_8
keywords:
  - story sequence
  - instagram stories
  - 7 day stories
  - close friends
  - story framework
priority: 1
version: 1.0
---

# /story-sequence — 7-Day IG Story Sequence (the stories director Framework)

## Role

Produce 7-day IG Story sequences using the stories director's 7-framework weekly system. Lineage: **the stories director** (the stories director Consulting — "story sequences are the single most powerful converting asset"), **the paid media director** (4-layer story anatomy), Marketing department Department (8 story sequence types).

## The 7-Day Framework (stories methodology)

Each day rotates a different framework. **Never repeat same framework 2 days in a row** (pattern fatigue).

| Day | Framework | Color/Weight | Purpose |
|---|---|---|---|
| 1 | **Proof From Many Clients** + Show It's Not Luck | Orange / heavy | Authority density |
| 2 | **Clarity About Program** (logical buyers FAQ) | Grey / light | Reduce friction |
| 3 | **Break Big Objection / Limiting Belief** | Orange / heavy | Objection killing |
| 4 | **Educative + Differentiation** (how we solve) | Orange / heavy | Mechanism teaching |
| 5 | **Personal Connection** | Grey / light | Humanize, build trust |
| 6 | **Proof From Client + Remove Skepticism** | Orange / heavy | Fresh case study |
| 7 | **Mission** | Grey / light | Bigger purpose |

Weighted balance: 4 orange (persuasive) + 3 grey (lighter). Prevents over-sales feel.

## The 4-Layer Story Anatomy (the stories director + the paid media director)

Every story has 4 layers working simultaneously:

1. **Text** (script engine) — the message/claim
2. **Image** (background) — NEVER blank — subconscious proof or connection
3. **Proof-Screenshots** (trust) — Stripe, testimonials, DMs (proof, not claims)
4. **Visuals** (authority) — charts/graphs/Miro/diagrams (process credibility)

Invariants:
- **Never blank background.**
- **Never claim without screenshot proof.**
- **Mix orange + grey.** 7 orange sequences = too salesy.
- **Each story sells the next.** Like carousel slides — momentum matters.

## Decision Logic

### Daily Framework Execution

#### Day 1 — Proof From Many Clients (orange/heavy)
- 3-4 stories
- Each story = one client result (different avatars)
- Each with Stripe screenshot / testimonial / before-after data
- Closer: "It's not luck. It's the [mechanism]."

#### Day 2 — Clarity About Program (grey/light)
- 3-4 stories
- FAQ-style: "How long?" "What if I'm new?" "What's the investment?"
- Each = 1 question, crisp answer, no hard sell

#### Day 3 — Break Big Objection (orange/heavy)
- 3-4 stories
- Pull from ICP Section 10 Objection Library
- Counter the #1 objection with mechanism + proof + reframe

#### Day 4 — Educative + Differentiation (orange/heavy)
- 3-4 stories
- 3 idea templates:
  - Big picture + solution (overview)
  - Big reason + unique model (why this works)
  - Focus on one pain + unique mechanism (how we solve vs others)

#### Day 5 — Personal Connection (grey/light)
- 3-4 stories
- Behind-scenes, personal, moments
- No CTA
- Voice + identity layer

#### Day 6 — Proof From Client + Remove Skepticism (orange/heavy)
- 3-4 stories, 4 templates:
  - Simple storytelling (arc)
  - A→B storytelling (transformation)
  - Testimonial-first (video or screenshot)
  - Objection-first (counter an assumed skepticism)

#### Day 7 — Mission (grey/light)
- 3-4 stories
- Bigger-than-product purpose
- Why the creator does this
- Closing thought — prepping the audience for next week's cycle

## Tacit Principles

1. **Each story sells the next.** Momentum carries the sequence.

2. **Never blank backgrounds.** Subconscious proof layer matters.

3. **Never claim without screenshot proof.** Screenshot > words.

4. **Orange + grey mix.** 4+3 weekly balance prevents sales fatigue.

5. **Different framework every day.** Single framework = partial buyer psychology triggered.

6. **Dedicated Story Sequences photo album.** Shoot weekly. Don't scramble.

7. **Check the Close Friends hack.** If creator has Close Friends list, repurpose the weekly sequence there with deeper content (insider access).

8. **Voice + identity on Day 5 and 7.** These humanize the orange-dominant other days.

9. **Day 3 pulls from ICP objection library.** Don't guess — use real objection data.

10. **Proof must be isomorphic.** Day 1 + Day 6 client proof should match target avatar closely.

## Process

### Phase 0 — Load
- Calendar brief + ICP Section 10 Objections + Offer Doc Social Proof + Brand Voice
- `reference/operators/stories-director.md` (7-day framework + 4-layer anatomy)
- `reference/operators/paid-media-director.md` (4-layer anatomy origin)

### Phase 1 — Weekly Topic Thread
Choose the week's connective theme:
- Launch week? Thread = offer + milestones
- Case-study week? Thread = client showcase
- Educational week? Thread = mechanism deep-dive

### Phase 2 — Day-by-Day Planning
For each of 7 days:
- Select framework (never same 2 days in a row)
- Pull content inputs (proof, objection, mechanism sub-step, etc.)
- Draft 3-4 story slides
- Apply 4-layer anatomy per slide

### Phase 3 — Visual Asset Brief
Per slide, specify:
- Text (script)
- Image (background concept — never blank)
- Proof-screenshot (if applicable — Stripe, DM, testimonial)
- Visual element (chart / diagram / Miro if authority layer)

### Phase 4 — Orange/Grey Balance Check
4 orange days + 3 grey days. If imbalanced, adjust.

### Phase 5 — Voice-Match + Compliance
- 3+ phrases_to_use across week
- Banned vocabulary swept
- Truth Gate on every claim (screenshots = Truth Gate built-in)

### Phase 6 — Publishing Plan
- Post times (2-4 stories per day, distributed across engagement windows)
- Close Friends variant (deeper content, if creator uses CF)
- Highlight saves (any stories to archive in profile Highlights?)

## Output Format

```markdown
# Story Sequence — [Creator Brand] — Week [N]

**Calendar Brief IDs:** [W1-ST-1 through W1-ST-7]
**Weekly Theme:** [connective thread]
**Orange/Grey Mix:** 4 orange / 3 grey
**Version:** 1.0

---

## Day 1 — Proof From Many Clients (Orange/Heavy)

### Story 1.1
- **Text:** "[on-screen copy]"
- **Image:** [background concept]
- **Proof-Screenshot:** [Stripe / DM / testimonial]
- **Visual element:** [if any]

### Story 1.2
[...]

### Story 1.3
[...]

### Story 1.4
[...]

### Day 1 Close
[transition line that leads into Day 2]

---

## Day 2 — Clarity About Program (Grey/Light)

### Story 2.1 — FAQ 1
[...]
### Story 2.2 — FAQ 2
[...]
[...]

---

[repeat for Days 3-7]

---

## Highlights Save Plan
Stories to archive in profile Highlights (evergreen access):
- [Day 1.2 — "Sarah $50K case study"]
- [Day 6.3 — "Mark mechanism testimonial"]

## Close Friends Variant (if applicable)
Enhanced versions of orange-days with deeper behind-scenes, exclusive updates, or pre-launch hints.

## Publishing Schedule
| Day | Story # | Publish Time |
|---|---|---|
| Mon | 1.1 | 9am |
| Mon | 1.2 | 1pm |
| ...

## Voice-Match Audit
[phrases_to_use distribution across week]

## Compliance
- [ ] No income guarantees
- [ ] All claims have screenshot proof
- [ ] Banned vocabulary swept
- [ ] FTC disclosure where applicable

---

## Appendix A — Shot list for weekly shoot
[all photography + screenshots needed — so creator can batch-capture on Sunday]

## Appendix B — Asset prep checklist
[what needs to be designed / screenshot-captured before publishing]
```

## Important Rules

- **NEVER blank backgrounds.**
- **NEVER claim without screenshot proof.**
- **NEVER repeat same framework 2 days in a row.**
- **NEVER flip orange/grey balance** (4+3 is load-bearing).
- **ALWAYS pull Day 3 objections from ICP Section 10.**
- **ALWAYS ensure Day 5 + Day 7 grey days humanize.**
- **ALWAYS voice-match across the week.**
- **ALWAYS use isomorphic-fit client proof.**

## Verification Checklist

- [ ] 7 daily frameworks executed
- [ ] 4 orange + 3 grey days balanced
- [ ] 4-layer anatomy per story
- [ ] No blank backgrounds
- [ ] Proof screenshots present on claim stories
- [ ] Mechanism threaded through Day 4
- [ ] Objection from ICP used Day 3
- [ ] Personal + Mission humanizes (Days 5, 7)
- [ ] Voice-matched
- [ ] Compliance passed
- [ ] Triple-layer S/N ≥ 0.8

## Next Skills

- `/write-reel` — weekly story sequence highlights → single reel
- `/email-sequence` — broadcast referencing a week of stories
- `/content-calendar` — next week's story sequence

## References

- `reference/operators/stories-director.md` (7-day framework + 4-layer anatomy)
- `reference/operators/paid-media-director.md` (Content Studio)
- `reference/frameworks/instagram-profile-funnel/README.md`

---

*Version 1.0 — 2026-04-19. Cycle 3 Attention — IG Stories.*
