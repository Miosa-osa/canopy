# Triple-Layer Verification — 40% Formal + 35% Semantic + 25% Info-Theoretic

> **Source:** Signal Theory p.41 · the workspace manifest `protocol/signal-theory.md` lines 120-140
> **Status:** Load-bearing. Every skill output scored on all 3 layers before ship.

## The Formula

```
  Quality = (0.40 × Formal) + (0.35 × Semantic) + (0.25 × Info-Theoretic)
```

Each layer scored 0-1.0. Composite score:
- ≥ 0.8 = ship external
- ≥ 0.5 = ship internal (with caveats)
- < 0.5 = REJECT + revise

## Layer 1 — Formal (40% weight)

**Tests structural requirements.** Pass/fail checks:

- [ ] All 5 Signal dimensions resolved (M/G/T/F/W)
- [ ] Output follows declared Structure (W)
- [ ] Required compartments referenced (no null substitutions)
- [ ] Required sections present per Output Format
- [ ] Markdown renders
- [ ] YAML frontmatter parses
- [ ] Citations present where claims made
- [ ] Length within declared bounds
- [ ] No banned vocabulary
- [ ] Signal frontmatter declares receiver + receiver_capacity

**Formal fails = skip semantic/info-theoretic (output is structurally broken).**

## Layer 2 — Semantic (35% weight)

**Tests meaning preservation** — does the output actually convey what was intended?

Automated checks + LLM-as-judge:

- [ ] Output addresses the actual input (not tangent)
- [ ] Key concepts from compartment context appear
- [ ] Creator brand voice reflected (tone + phrases_to_use)
- [ ] Creator phrases_to_avoid NOT used
- [ ] Voice of customer language present (pain/desire/objection phrases)
- [ ] Output genre matches receiver's expected input genre
- [ ] Intent-type match (direct type → compels action; inform type → no hard CTA)
- [ ] Isomorphic story check (if story used)

**Semantic fails → skip info-theoretic. Meaning wrong, novelty moot.**

## Layer 3 — Info-Theoretic (25% weight)

**Tests entropy reduction** — does output reduce receiver uncertainty?

- [ ] Specificity score high (concrete numbers/names/dates)
- [ ] Novelty score — tells receiver something they couldn't derive alone
- [ ] Actionability — receiver can take specific action
- [ ] Compression — same meaning couldn't be conveyed more concisely (no padding)

## Why the Weights

- **40% formal** = you can't have meaning without structure
- **35% semantic** = structure without meaning is noise
- **25% info-theoretic** = without novelty, output is restating

Formal > semantic > info-theoretic reflects prerequisite order.

## The 6 Proxy Metrics (operational measurement)

Per Signal Theory p.39, S/N can be measured via 6 proxies:

1. **Action Completion Rate** — % of Signals resulting in intended action
2. **Re-encoding Frequency** — how often receiver asks for clarification
3. **Time-to-Decode** — how long receiver takes to understand
4. **Signal Bounce Rate** — % routed to wrong receiver
5. **Genre Recognition Rate** — % of receivers recognizing genre correctly
6. **Feedback Loop Closure Rate** — % of Signals receiving acknowledgment

Skills track these per output where measurable (most relevant for live-delivered assets like webinars, sales calls).

## Integration with INVARIANTS.md

Triple-layer verification operationalizes:
- INV-5 (Truth Gate)
- INV-6 (No Fabrication)
- INV-7 (Banned Vocabulary)
- INV-12 (Signal 5-tuple declared)
- INV-13 (S/N ≥ 0.8 external)

Violations of these = automatic reject regardless of composite score.

## Violation Handling

Per `workflows/handoffs/quality-revision.md`:
1. **Attempt 1** — auto-revise addressing the specific failure mode
2. **Attempt 2** — creator-assisted (surface the gap + targeted question)
3. **Escalate** — after 2 attempts, halt + log to `skills/{slug}/evidence/failure-modes.md`

## Sources

- Signal Theory p.41
- the workspace manifest `protocol/signal-theory.md` lines 120-140
- `spec/QUALITY.md`

---
*v1.0 — 2026-04-19. Scoring mechanism for every skill ship gate.*
