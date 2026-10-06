# The 5-Tuple Encoding — S = (Mode, Genre, Type, Format, Structure)

> **Source:** Signal Theory pp.14-18 · the workspace manifest `protocol/signal-theory.md` lines 9-24
> **Status:** Load-bearing. Every skill output declares its 5-tuple before execution.

## Definition

```
  S = (M, G, T, F, W)
  where:
    M = Mode
    G = Genre  
    T = Type
    F = Format
    W = Structure (W(G) — Structure is a function of Genre)
```

A Signal is fully specified when all 5 dimensions are resolved. Unresolved = noise.

## The Five Dimensions

### Mode (M) — How is it perceived?
The sensory channel:
- `linguistic` — text / speech
- `visual` — diagram / image / video frame
- `auditory` — audio / podcast / voice
- `gestural` — demo / motion
- `spatial` — map / physical layout
- `code` — executable logic
- `data` — structured tables
- `mixed` — multi-modal

### Genre (G) — What conventionalized form?
The socially recognized pattern the receiver is trained to decode. Growth Operating Agency genres:

**Foundations:** `market-research-brief`, `icp-doc`, `positioning-doc`, `offer-doc`, `brand-voice-doc`

**Sales:** `vsl-script`, `funnel-blueprint`, `sales-script`, `application-form`

**Marketing:** `ad-creative-brief`, `content-calendar`, `reel-script`, `youtube-script`, `linkedin-post`, `x-thread`, `story-sequence`

**Nurture:** `email-sequence`, `lead-magnet-brief`, `webinar-script`, `post-booking-stack`

**Scale:** `sop`, `hiring-brief`, `retention-report`, `case-study`, `competitor-intel`, `revenue-report`

**Launch:** `launch-plan`, `launch-report`

**Partnerships:** `jv-proposal`, `affiliate-program-spec`, `referral-program-spec`

### Type (T) — What does it DO? (Searle speech act)
- `direct` — compel action (buy, click, apply, book)
- `inform` — deliver information
- `commit` — promise future behavior (guarantee, delivery)
- `decide` — conclude and lock a choice
- `express` — emotional/identity declaration

Type is **the independent axis** — any Type can ride any Genre/Mode/Format.

### Format (F) — What container?
- `markdown`, `yaml`, `json`, `code`, `pdf`, `docx`
- `slide-deck`, `spreadsheet`, `video`, `audio`, `html`, `live-session`

### Structure (W) — How is it internally organized?
Structure is a function of Genre: **W(G)**. Each genre has a canonical internal skeleton.

Examples:
- `W(vsl-script)` = 15-step (15-step VSL methodology) or 11-step (pull-push-persuade methodology) or 13-step (the 13-step VSL author) or 3X (3X VSL methodology) or 5-chapter (the growth engineer VSSL)
- `W(icp-doc)` = 13 sections (Demographics / Firmographics / Psychographics / Behavioral / Market Sophistication / VOC / Limiting Belief / ...)
- `W(offer-doc)` = 12 sections (Transformation / Mechanism / Capability Removal / Value Stack / Bonuses / Pricing / Guarantee / Upsell / Economics / Beliefs / Invariants)

## The Cascade Rule

Dimensions are NOT independent. They cascade:

```
Format → constrains Mode
Mode → constrains Genre
Genre → determines Structure (W = W(G))
Type → independent
```

An audio file can't carry visual mode. A demo requires gestural mode. A `vsl-script` follows W(vsl) regardless of content.

## The Receiver

The receiver is **not a sixth dimension** — it's the constraint field within which all 5 are optimized.

> *"A Signal encoded without knowing its destination is a broadcast. Broadcasting is a information theory violation."* — Signal Theory p.14

Every signal declaration includes receiver + receiver_capacity (high/medium/low).

## Usage in SKILL.md Frontmatter

Every skill declares its output's 5-tuple:

```yaml
signal:
  mode: linguistic
  genre: offer-doc
  type: inform
  format: markdown
  structure: w-offer-doc-12-section
  receiver: creator + sales + marketing + launch skills
  receiver_capacity: high
```

Unresolved dimensions = skill refuses to execute.

## Sources

- Signal Theory pp.14-18
- the workspace manifest `protocol/signal-theory.md` lines 9-24
- `spec/SIGNAL.md`

---
*v1.0 — 2026-04-19.*
