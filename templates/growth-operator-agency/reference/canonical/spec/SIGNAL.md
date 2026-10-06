# SIGNAL.md — Signal Theory Encoding Specification

> **The quality substrate.** Every output this workspace produces is a Signal. This spec defines what counts as a Signal, how it's encoded, how it's measured, and when it fails.
>
> **Foundational sources:** Signal Theory, *Signal Theory: Optimal Intent Encoding* (63pp); workspace protocol `protocol/signal-theory.md`; information theory (1948), cybernetics (1956), viable systems (1972), feedback-loop theory (1948).

---

## 1. Definition

A **Signal** is *an encoded unit of intent that carries actionable information through a communication channel, designed to be decoded by the receiver into executable action.*

Anything that is not a Signal is either:
- **Data** — raw, un-encoded, not yet actionable
- **Noise** — encoded but not carrying actionable intent, or carrying intent the receiver cannot decode

The root objective of this workspace is to **maximize Signal-to-Noise Ratio (S/N) on every output.**

## 2. The 5-Tuple Encoding

Every Signal is specified across five orthogonal dimensions:

```
S = (Mode, Genre, Type, Format, Structure)
```

### Mode (M) — How is it perceived?
The sensory channel. Options:
- `linguistic` — text / speech
- `visual` — diagram / image / video frame
- `auditory` — audio / podcast / voice
- `gestural` — demo / motion
- `spatial` — map / physical layout
- `code` — executable logic
- `data` — structured tables

### Genre (G) — What conventionalized form?
The socially recognized pattern the receiver is trained to decode. Growth Operating Agency genre catalog:
- `spec` — formal specification
- `brief` — short directive
- `report` — findings + implications
- `proposal` — offer with terms
- `pitch` — persuasive selling argument
- `plan` — ordered action sequence
- `transcript` — verbatim dialogue
- `note` — informal capture
- `email` — conversational async message
- `adr` — architecture decision record
- `battlecard` — positioning matrix vs competitors
- `vsl` — video sales letter
- `webinar` — live teaching + offer
- `landing-page` — single-page sales doc
- `ad` — short paid creative
- `post` — social media unit
- `thread` — multi-post sequence
- `sequence` — ordered email/SMS series
- `sop` — standard operating procedure
- `icp-doc` — ideal customer profile document
- `offer-doc` — offer architecture document
- `positioning-doc` — category/mechanism positioning

### Type (T) — What does it DO? (Searle's speech act)
The communicative function. Options:
- `direct` — compel action (buy, click, apply, book)
- `inform` — deliver information without action ask
- `commit` — promise future behavior (guarantee, delivery)
- `decide` — conclude and lock in a choice
- `express` — emotional/identity declaration

Type is **the independent axis** — any Type can ride any Genre/Mode/Format combination.

### Format (F) — What container?
The physical/digital vessel:
- `markdown` — structured text (most skill outputs)
- `yaml` / `json` — structured data
- `code` — source code
- `pdf` / `docx` — document
- `slide-deck` — presentation
- `spreadsheet` — tabular
- `video` / `audio` — media file
- `html` — rendered page
- `live-session` — synchronous human exchange

### Structure (W) — How is it internally organized?
The internal skeleton/template. Structure is a function of Genre: **W(G)**.
Examples:
- `W(proposal)` = Problem → Solution → Scope → Approach → Timeline → Budget → Terms
- `W(vsl)` = Hook → Lead → Qualification → Problem → Hero Story → Solution → Features → Testimonials → Price Anchor → Guarantee → Urgency → Crossroads Close → Takeaway → Help Them Buy → Future Pace (15-step)
- `W(icp-doc)` = Demographics → Firmographics → Psychographics → Behavioral Patterns → Market Sophistication → Voice of Customer → Limiting Belief
- `W(offer-doc)` = Transformation → Mechanism → Capability Removal → Value Stack → Bonuses → Guarantee → Pricing → Upsell Ecosystem → Economics Validation

## 3. The Dimension Cascade

The five dimensions are **not independent — they cascade**:

```
Format  →  constrains Mode
Mode    →  constrains Genre
Genre   →  determines Structure: W(G)
Type    →  independent (any Type can ride any Genre/Mode/Format)
```

An audio file cannot carry visual mode. A demo requires gestural mode. A `vsl` genre follows `W(vsl)` structure regardless of content. The encoder's decision tree: **Format → Mode → Genre → (Type parallel) → Structure**.

## 4. The Receiver as Constraint Field

The receiver/destination is **not a sixth dimension** — it is the constraint field within which all five dimensions are optimized.

> "A Signal encoded without knowing its destination is a broadcast. Broadcasting is a information theory violation — it ignores channel capacity by assuming all receivers are the same." — Signal Theory

Every Signal declaration must include: **who decodes this, and what's their decoding capacity?**

## 5. The 4 Governing Principles

Every Signal is constrained by four principles. Violating any = Signal failure.

### information theory (The Ceiling)
Every channel has finite capacity: `C = B × log₂(1 + S/N)`. Exceeding capacity = reliable communication impossible.
**In practice:** context windows are finite. Output length has a ceiling. A 500-line answer when 20 lines suffice is a information theory violation.

### cybernetics theory (The Repertoire)
*Only variety can absorb variety.* The system's Signal repertoire (genres, modes, formats, structures) must have enough variety to handle every situation the environment produces. Requisite Variety Ratio `R = V(system) / V(disturbance)`:
- R < 1.0 failing
- R 1.0–3.0 marginal
- R 3.0–10.0 adequate
- R ≥ 10.0 robust

**In practice:** you need ~R × actual_situations templates for a domain. If VSLs need 5 variants (15-step, pull-push-persuade 11-step, 13-step VSL, three-phase VSL formula, hidden-pitch long-form video), not 1.

### viable systems theory (The Architecture)
Any viable system requires five recursive subsystems:
- **System 1** Operations (produce/consume Signals)
- **System 2** Coordination (prevent Signal conflicts)
- **System 3** Control (manage Signal flow + resources; 3* audit)
- **System 4** Intelligence (scan external environment)
- **System 5** Policy (define encoding standards + identity)

**In practice:** Growth Operating Agency department mapping —
- Foundations = System 5 (Policy)
- Marketing = Transmission Layer
- Nurture = System 2 (Coordination)
- Sales = Conversion Chain
- Launch = System 3 (Control)
- Scale = System 1 (Operations)
- Partnerships = Cross-cutting (System 4 scan)

### feedback-loop theory (The Feedback Loop)
A system cannot self-correct without feedback. Linear/broadcast communication cannot achieve optimal fidelity. Every Signal must have a feedback path.
**In practice:** every skill produces output AND expects a response (accepted / rejected / refined). Output without response channel = broken Signal.

## 6. The 6 Encoding Principles (applied to every output)

| # | Principle | What it means |
|---|---|---|
| 1 | Mode-message alignment | Sequential logic → text/code. Relational logic → diagrams/tables. |
| 2 | Genre-receiver alignment | Match the genre to the receiver. Developers decode specs. Prospects decode pitches. |
| 3 | Structure imposition | Raw information is noise. Always impose structure. Headers, sections, templates. |
| 4 | Redundancy proportional to noise | High-stakes → more structure, more explicit intent. Simple context → minimal. |
| 5 | Entropy preservation | Maximum meaning per unit of output. No filler, no hedging, no padding. |
| 6 | Bandwidth matching | Match output density to receiver's decoding capacity. 3 bullets when 3 is enough. |

## 7. Signal Frontmatter (every SKILL.md must declare)

Every skill's output declares its Signal:

```yaml
signal:
  mode: linguistic              # Mode dimension
  genre: icp-doc                # Genre dimension
  type: inform                  # Type dimension
  format: markdown              # Format dimension
  structure: w-icp-doc          # Structure reference (or explicit W outline)
  receiver: creator             # who decodes this
  receiver_capacity: high       # high | medium | low
```

Unresolved dimensions = noise. Skill refuses to execute.

## 8. S/N Measurement

Quality is measured across three layers with explicit weights:

- **Formal verification (40%):** structural requirements satisfied, logical consistency, preconditions met
- **Semantic verification (35%):** meaning preserved, intent decoded correctly by receiver
- **Information-theoretic verification (25%):** entropy reduction — does it tell the receiver something they didn't know?

`Quality = 0.40·formal + 0.35·semantic + 0.25·info_theoretic`

Formal is a precondition for semantic. Semantic is a precondition for info-theoretic.

### Six proxy metrics for S/N
1. **Action Completion Rate** — % of Signals that result in intended action
2. **Re-encoding Frequency** — how often the receiver asks for clarification
3. **Time-to-Decode** — how long receiver takes to understand
4. **Signal Bounce Rate** — % routed to wrong receiver
5. **Genre Recognition Rate** — % of receivers who recognize the genre correctly
6. **Feedback Loop Closure Rate** — % of Signals that receive acknowledgment

### S/N Score Bands

| Range | Status | Action |
|---|---|---|
| 0.0 – 0.3 | REJECT | Noise exceeds signal, rewrite required |
| 0.3 – 0.5 | WARN | Significant noise, revision recommended |
| 0.5 – 0.7 | PASS | Acceptable signal, minor noise tolerated (internal OK) |
| 0.7 – 0.9 | GOOD | Strong signal, minimal noise (external OK) |
| 0.9 – 1.0 | OPTIMAL | Maximum meaning per unit of output |

**Gate thresholds:**
- External / client-facing output: ≥ 0.8
- Internal / draft output: ≥ 0.5
- Below 0.5 = REJECT + revise

## 9. The Package (Signal Bundle)

Multi-Signal deliverables group into a Package:
- `dossier` — collected findings
- `brief-package` — multi-asset quick deliverable
- `deliverable-package` — formal handoff
- `onboarding-kit` — client activation bundle
- `handoff-package` — role-to-role transition
- `data-drop` — bulk data export
- `rfp` — request-for-proposal bundle

Each Signal in a Package maintains its own 5-tuple.

## 10. Violation Handling

When a Signal fails the gate:

1. **Log** the failure in the skill's `evidence/failure-modes.md`
2. **Identify** which principle(s) violated (information theory / cybernetics theory / viable systems theory / feedback-loop theory)
3. **Attempt one revision** if the fix is clear
4. **If revision fails:** escalate to creator with the specific gap flagged

## 11. Alignment with workspace protocol

the workspace manifest's `protocol/signal-theory.md` uses the identical 5-tuple and 4 principles. Growth Operating Agency extends this with:
- Signal Theory's 7-Layer Optimal System mapping (L1 Network → L7 Governance)
- Encoded Founder's M = T × S × K × A × E × I × L formula
- Impact Distribution Principle (40/40/20) as the applied cybernetics theory ratio for growth businesses
- Blind Output Test as the operational completeness test

## 12. Sources

- Signal Theory — *Signal Theory: Optimal Intent Encoding* (63pp)
- workspace protocol — `protocol/signal-theory.md`
- the workspace author —  (V4)
- information theory (1948) *A Mathematical Theory of Communication*
- cybernetics (1956) *An Introduction to Cybernetics*
- viable systems (1972) *Brain of the Firm*
- feedback-loop theory (1948) *Cybernetics: Or Control and Communication*

---

*v1.0 — 2026-04-19. Changes to this spec are sacred-format changes requiring creator sign-off.*
