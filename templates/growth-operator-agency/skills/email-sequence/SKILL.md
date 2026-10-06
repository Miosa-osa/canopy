---
name: email-sequence
description: Produce email sequences in 8 types (Welcome / Nurture / Launch / Webinar / Re-engagement / Application / Post-Purchase / Single Broadcast). Voice-matched. Conversion-staged. Consumes ICP + Offer + Brand Voice. Built for ConvertKit / ActiveCampaign / Beehiiv / GoHighLevel.
signal:
  mode: linguistic
  genre: email-sequence
  type: inform
  format: markdown
  structure: variant-dependent-w-email-sequence
  receiver: subscriber
  receiver_capacity: low-to-medium
department: nurture
agent_affinity: [nurture-head, email-copywriter]
required_compartments:
  audience_intelligence_system: 60
  offer_architecture: 50
  copy_messaging: 40
  education_nurture: 20
upstream_dependency: design-offer
execution_mode: interactive
tier: structured_ai
temperature_gate: warm
required_tools: [file_read, file_write]
required_mcps: [filesystem]
required_integrations:
  email: convertkit-api              # or activecampaign / beehiiv / ghl
  crm: gohighlevel-api               # for segmentation + tagging
  analytics: email-platform-native
credentials_required: [CONVERTKIT_API_KEY, GHL_API_KEY]
evidence_gate:
  - sequence_type_selected
  - per_email_subject_hook_specificity_gte_8
  - conversion_stage_mapped
  - voice_matched
  - cadence_specified
  - unsubscribe_compliance_present
  - signal_score_gte_0_8
keywords:
  - email sequence
  - welcome email
  - nurture email
  - launch email
  - email marketing
priority: 1
version: 1.0
---

# /email-sequence — Email Sequence Producer (8 Types)

## Role

Produce email sequences that convert subscribers to buyers. Lineage: **the content OS director** (Nurture Block — indoctrination/value/conversion/retention sequences), **the offer architect** (belief-installation email cadence), **the growth strategist** ($200k/mo outreach OS — Whisper/Tease/Shout launch cadence), **the copy director** (direct-response email structure), **the acquisition economist** (a lead-generation canon email frameworks).

## The 8 Sequence Types

| # | Type | Emails | Purpose |
|---|---|---|---|
| 1 | **Welcome** | 5-7 | Activation after opt-in; deliver lead magnet; set expectations |
| 2 | **Nurture (indoctrination)** | 7-14 | Belief installation over 14-30 days; move unaware → solution-aware |
| 3 | **Launch** | 5-10 | Offer-window campaign; Whisper → Tease → Shout cadence |
| 4 | **Webinar** | 5-8 | Registration → show-up reminders → replay + close sequence |
| 5 | **Re-engagement** | 3-5 | Reactivate cold subscribers before list scrubbing |
| 6 | **Application** | 4-6 | Post-opt-in to application-submit nurture |
| 7 | **Post-Purchase** | 5-10 | Onboarding + activation + first-win + upsell |
| 8 | **Single Broadcast** | 1 | Weekly value drop or tactical announcement |

## Decision Logic

### Subject Line Invariants
- **Hook Specificity ≥ 8** (per `primitives/specificity.md`)
- 40-50 chars mobile-optimized
- Curiosity gap OR contrarian OR specific outcome
- Banned phrases: "Quick question", "Just checking in", "Touching base", "Re:" (fake reply)

### Preview Text Optimization
- 35-90 chars
- Extends the subject's curiosity gap
- Never repeats subject verbatim

### Sender Name
- Creator's name preferred over brand name (30%+ open rate lift)
- Consistent across sequences

### Cadence by Sequence Type

| Type | Cadence |
|---|---|
| Welcome | Day 0 (immediate), Day 1, Day 3, Day 5, Day 7, Day 10, Day 14 |
| Nurture | Day 0, 2, 4, 7, 10, 14, 18, 22, 26, 30 |
| Launch | Day 0 (Whisper), 2, 3, 5 (Tease), 6, 7 (Shout), 7-final-day (5-6 emails in last 24h) |
| Webinar | T-7d (invite), T-3d, T-1d, T-1h (show-up), T+0 (missed? replay), T+1d (close), T+2d (bonus) |
| Re-engagement | Day 0, 3, 7, 10 (last chance) |
| Application | Day 0, 2, 4, 7 |
| Post-Purchase | Day 0, 1, 3, 7, 14, 30, 60, 90 |

### Email Structure (universal)

```
Subject (40-50 chars)
Preview text (35-90 chars)
---
[Hook — first 1-2 lines — phone preview visible]
[Body — story / teaching / value]
[Bridge — connects to CTA]
[CTA — single action, direct link]
[Sign-off — creator signature]
---
[P.S. — often highest-read; repeat CTA or add urgency]
```

### Voice + Compliance
- 3+ `phrases_to_use` per email
- Banned vocabulary swept
- CAN-SPAM compliance (physical address, unsubscribe link, truthful header)
- GDPR compliance if EU audience (explicit consent tracked)

## The 8 Sequences in Detail

### Type 1 — Welcome Sequence (5-7 emails)
- Email 1 (Day 0): Deliver lead magnet + expectations
- Email 2 (Day 1): Origin story — who the creator is + why this matters
- Email 3 (Day 3): Mechanism teaching — the unique mechanism named + 1 sub-step
- Email 4 (Day 5): Case study — isomorphic client result
- Email 5 (Day 7): Objection pre-handle — the #1 objection from ICP library
- Email 6 (Day 10): Soft CTA — offer mention, low-pressure
- Email 7 (Day 14): Decision — "ready?" with direct CTA

### Type 2 — Nurture / Indoctrination (7-14 emails)
Belief installation from the VSL director's 8 Required Beliefs:
- Week 1: Belief 1-2 (outcome desire + derivative desire)
- Week 2: Belief 3-4 (can-fulfill + urgency)
- Week 3: Belief 5-6 (this-offer + better/faster)
- Week 4: Belief 7-8 (trust-person + trust-expertise)
- Interlaced with value teaching + Core Belief Statement reinforcement

### Type 3 — Launch Sequence (5-10 emails, compressed to offer window)
Per the growth strategist Whisper/Tease/Shout:
- **Whisper phase (5-7d pre):** Soft hints, problem-reframe, "something's coming"
- **Tease phase (3-2d pre):** Specific previews, mechanism reveal, case studies
- **Shout phase (offer-window):** Direct offer + urgency + social proof + closing
- **Final 24h:** 5-6 emails hitting urgency, last-chance, bonuses, Q&A, live-mention

### Type 4 — Webinar Sequence (5-8 emails)
- T-7d: Registration invite
- T-3d: Reminder + value preview
- T-1d: Show-up reminder + social proof (who else registered)
- T-1h: "Starting in 1 hour" with direct join link
- T+0: (Missed?) replay auto-send
- T+1d: Close — offer reminder + replay link + FAQ
- T+2d: Final — bonus deadline / urgency

### Type 5 — Re-engagement (3-5 emails)
- Email 1: "Are you still with me?" with recap of value
- Email 2: Fresh case study or tactical insight
- Email 3: Direct question — what do you need?
- Email 4: Last chance — subscribe removal warning
- Email 5 (optional): "Breakup" email with soft CTA for those on the fence

### Type 6 — Application (4-6 emails, post-opt-in pre-apply)
- Day 0: What to expect + application link
- Day 2: Why applications are screened + what they're looking for
- Day 4: Case study of someone who applied + got in + result
- Day 7: "Applications close soon" (if cohort-based)

### Type 7 — Post-Purchase (5-10 emails)
Onboarding + activation + retention + upsell:
- Day 0: Welcome to program + access + first action
- Day 1: First-win setup (engineered per Offer Doc)
- Day 3: First-win check-in + support access
- Day 7: Milestone — "Week 1 wins"
- Day 14: Mid-program check + feedback capture
- Day 30: Transformation check + upsell intro (if applicable)
- Day 60: Case study capture invitation
- Day 90: Alumni / ascension path

### Type 8 — Single Broadcast
One-off:
- Weekly value drop
- Tactical announcement (new content, partnership, event)
- Tied to calendar post (content-calendar generates brief → this skill writes)

## Tacit Principles

1. **Subject + first line must earn the open.** Preview shows the first sentence. If it's weak, subject wasted.

2. **One CTA per email.** Stacking CTAs = zero clicks.

3. **P.S. is highest-read.** Use it — urgency reminder, second CTA, or punchline.

4. **Signature = creator name, not brand.** Personal > corporate for creator businesses.

5. **Segment aggressively** — don't send Launch emails to Post-Purchase list. Segmentation = conversion.

6. **Whisper before Shout.** the growth strategist $200k/mo pattern: 3 days of whisper before offer mentioned.

7. **Re-engage before scrubbing.** 5 emails → then remove cold subscribers from main list.

8. **Read aloud — if it sounds like an email blast, rewrite.** Should sound like a personal note.

9. **Specificity in body.** "$7,500 invoice in 2 hours" beats "made money." Every email.

10. **Cadence fatigue kills.** Launch windows are compressed (5-10 emails in 7 days = fine). Nurture is paced (every 2-4 days). Mix them up.

## Process

### Phase 0 — Load
- Calendar brief (if broadcast type), compartments 1-5, 9
- ICP + Offer + Positioning + Brand Voice docs
- `reference/operators/content-os-director.md` (Nurture Block)
- `reference/operators/offer-architect` content (belief installation)
- `reference/frameworks/sales/8-required-beliefs.md`

### Phase 1 — Sequence Type Selection
Apply table. Or `--type=1-8`.

### Phase 2 — Cadence Planning
Per table. Confirm offer-window dates if launch.

### Phase 3 — Per-Email Brief
For each email:
- Subject (3 variants + selected)
- Preview text
- Sender name
- Hook (first 1-2 lines)
- Body structure
- Single CTA

### Phase 4 — Write Each Email
- Voice-matched
- Specificity ≥ 8 in subject + body
- Mechanism threaded where applicable
- P.S. optimization
- Compliance: physical address + unsubscribe + truthful header

### Phase 5 — Segmentation + Tagging
Declare:
- Which segment receives
- Tags added/removed per email (based on actions)
- Automation triggers (e.g., click email 3 → tag "interested")

### Phase 6 — Platform Export
Format for platform API import (ConvertKit / AC / Beehiiv / GHL schemas).

## Output Format

```markdown
# Email Sequence — [Creator Brand] — [Sequence Name]

**Type:** [1-8]
**Total Emails:** [N]
**Cadence:** [per-email timing]
**Voice-Match:** [VERIFIED]
**Version:** 1.0

---

## Sequence Overview
| # | Day | Subject | Purpose | CTA |
|---|---|---|---|---|
| 1 | 0 | [subject] | [purpose] | [CTA] |
...

---

## Email 1 — [Day 0] — [Title]

**Subject:** "[40-50 chars]"
**Preview:** "[35-90 chars]"
**From:** [Creator Name <email>]
**Segment:** [tag]

**Body:**
```
[Hook — 1-2 lines]

[Body — story/teaching/value]

[Bridge]

[CTA — single action, direct link]

[Sign-off + creator signature]

P.S. [optional high-read line]
```

**Tags:**
- Add: [tag on send]
- Remove: [tag on click]

---

## Email 2 — [Day N] — [Title]
[repeat structure]

---

## Segmentation Plan
[which segments + tag logic]

## Automation Triggers
[click / open / reply behavior → downstream action]

## Platform Export (ConvertKit JSON)
```json
{
  "sequence": "...",
  "emails": [...]
}
```

## Compliance
- [ ] Physical address in footer
- [ ] Unsubscribe link
- [ ] Sender verified
- [ ] GDPR opt-in tracked (if applicable)

## Voice-Match Audit
[phrases_to_use distribution]

---

## Appendix A — Subject line A/B variants
[3 variants per email with reasoning]

## Appendix B — P.S. variants
[per email]
```

## Important Rules

- **NEVER use fake-reply subject ("Re:") to boost opens** — trust violation.
- **NEVER stack >1 CTA per email.**
- **NEVER skip unsubscribe / address (CAN-SPAM).**
- **NEVER send Launch to cold list without nurture** — burns the list.
- **ALWAYS voice-match.**
- **ALWAYS hit specificity ≥ 8 on subject.**
- **ALWAYS segment before sending** (tag logic).

## Verification Checklist

- [ ] Sequence type selected
- [ ] Cadence per table
- [ ] Per-email: subject / preview / hook / body / CTA / P.S.
- [ ] Single CTA per email
- [ ] Voice-matched
- [ ] Specificity ≥ 8 on all subjects
- [ ] Compliance footer
- [ ] Tags + segmentation plan
- [ ] Platform export format
- [ ] Triple-layer S/N ≥ 0.8

## Next Skills

- `/post-booking-nurture` — specific confirmation-page + SMS + email stack for call funnels
- `/lead-magnet` — the lead magnet that drives opt-ins to Welcome sequence
- `/webinar-script` — the webinar that the Webinar sequence promotes

## Variants

Per-variant playbooks live in `variants/`. Each file expands one sequence type with scope, triggers, cadence, 200-to-400 line per-email structure, subject-line bank, P.S. bank, segmentation logic, benchmarks, failure modes, and next-sequence routing.

| # | Variant | File |
|---|---|---|
| 1 | Welcome | `variants/welcome-sequence.md` |
| 2 | Nurture | `variants/nurture-sequence.md` |
| 3 | Launch | `variants/launch-sequence.md` |
| 4 | Webinar Promotion | `variants/webinar-promotion-sequence.md` |
| 5 | Re-engagement | `variants/re-engagement-sequence.md` |
| 6 | Application | `variants/application-sequence.md` |
| 7 | Post-Purchase | `variants/post-purchase-sequence.md` |
| 8 | Broadcast | `variants/broadcast-playbook.md` |

Index: `variants/_INDEX.md`.

## References

- `reference/operators/content-os-director.md` (Nurture Block)
- `reference/operators/acquisition-economist.md` (a lead-generation canon email)
- `reference/frameworks/sales/8-required-beliefs.md` (the VSL director — Nurture sequences install these)
- `reference/operators/growth-strategist.md` (Whisper/Tease/Shout launch cadence)
- `reference/canonical/spec/INTEGRATIONS.md` (email platforms)

---
*v1.0 — 2026-04-19. Cycle 4 Educate.*
