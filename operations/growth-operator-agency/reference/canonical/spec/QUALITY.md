# QUALITY.md — Triple-Layer Verification + Quality Gates

> **The output gate.** Every skill output passes through this gate before ship. If the gate fails, the skill revises (max 2 attempts) then escalates.

## The Triple-Layer Verification Model

Quality is not a single score. It's three independent measurements combined:

```
Quality = (0.40 × Formal) + (0.35 × Semantic) + (0.25 × Information-Theoretic)
```

Each layer is a precondition for the next:
- Formal failure → skip semantic/info-theoretic (output is structurally broken)
- Semantic failure → skip info-theoretic (meaning is wrong, novelty doesn't matter)

## Layer 1 — Formal Verification (40% weight)

**Tests structural requirements and formal logic.**

### Automated checks
- [ ] All 5 Signal dimensions resolved (Mode, Genre, Type, Format, Structure) — see spec/SIGNAL.md
- [ ] Output follows the Structure (W) declared for the Genre (e.g., VSL follows 15-step W(vsl))
- [ ] Required compartments from ENCODING.md are referenced (not null substitutions)
- [ ] Required sections present per skill's Output Format declaration
- [ ] Markdown renders without error
- [ ] YAML frontmatter (if declared) parses
- [ ] Citations present where claims made
- [ ] Length within bounds declared by the skill (not 10× over-target)
- [ ] No banned vocabulary from spec/BANNED-VOCABULARY.md
- [ ] Signal frontmatter declares receiver + receiver_capacity

### Failure modes
- Missing sections → FAIL
- Invalid markdown → FAIL
- Unresolved variables (`{{...}}` left in output) → FAIL
- Banned vocabulary used → FAIL
- Output length > 2× the minimum required = information theory violation → FAIL

## Layer 2 — Semantic Verification (35% weight)

**Tests whether the encoded meaning matches intended meaning.**

### Automated checks (LLM-as-judge + rule-based)
- [ ] Output addresses the actual input (not tangentially related)
- [ ] Key concepts from compartment context appear in output
- [ ] Creator's brand voice (tone_framework + phrases_to_use) reflected
- [ ] Creator's `phrases_to_avoid` NOT used
- [ ] Voice of customer language present (pain/desire/objection phrases from compartment 2)
- [ ] Output genre matches receiver's expected input genre (no genre mismatch)
- [ ] Intent-type match (if `direct` type, output compels action; if `inform`, no hard CTA)
- [ ] Isomorphic story check (if story used: same structure + situation + outcome + process as creator's proven frameworks)

### Failure modes
- Output is on-topic but doesn't answer the actual question → FAIL
- Generic copy that doesn't pull from creator context → FAIL
- Uses phrases_to_avoid → FAIL
- Wrong voice/tone → FAIL

## Layer 3 — Information-Theoretic Verification (25% weight)

**Tests whether output reduces uncertainty for the receiver — entropy reduction.**

### Automated checks
- [ ] Specificity score: does output contain concrete numbers/names/dates (vs vague)?
- [ ] Novelty score: does output tell receiver something they couldn't derive from their own compartments?
- [ ] Actionability score: can the receiver take a specific action from this output?
- [ ] Compression score: could the same meaning be conveyed more concisely? (high = entropy preserved, low = padding)

### Failure modes
- Generic advice applicable to anyone → FAIL (zero novelty)
- Restates inputs without adding insight → FAIL (zero entropy reduction)
- "In conclusion, here are some thoughts" → FAIL (padding)

## The S/N Score Bands

```
0.0 – 0.3   REJECT  — noise exceeds signal, full rewrite
0.3 – 0.5   WARN    — significant noise, revision recommended
0.5 – 0.7   PASS    — acceptable, minor noise tolerated (internal-only)
0.7 – 0.9   GOOD    — strong signal (external publishing allowed)
0.9 – 1.0   OPTIMAL — blind-test indistinguishable from creator's own
```

## Gate Thresholds

| Output context | Minimum quality score | Action if below |
|---|---|---|
| External / client-facing / published | 0.8 | REJECT — revise |
| Internal / draft shared with creator | 0.5 | WARN — flag gaps, ship with caveats |
| Exploratory / scratch | 0.3 | PASS with disclaimer |
| Blind-test-required (production sacred) | 0.9 | REJECT — must be indistinguishable from creator |

## The 5 Internal Quality Validation Tests

Before delivery, skills run these 5 tests (from Growth Operating Agency Master Prompt Section 7):

### Test 1 — Verbatim Language Test
Does output use the audience's **actual words** from compartment 2's `voice_of_customer.actual_customer_language`?
- PASS: at least 3 verbatim phrases used
- FAIL: generic language throughout

### Test 2 — Specificity Test
Specific numbers, names, situations — or generic?
- PASS: concrete, pulled from compartment context
- FAIL: "many", "a lot", "most", "often" without numbers

### Test 3 — Voice Consistency Test
Would the creator recognize this as their own voice?
- PASS: matches `tone_framework.primary` + uses `phrases_to_use`
- FAIL: tonal mismatch, uses banned phrases or `phrases_to_avoid`

### Test 4 — Mechanism Uniqueness Test
Does output reference the creator's **unique mechanism** (compartment 1)?
- PASS: mechanism named and threaded through
- FAIL: generic "the framework" with no creator-specific mechanism

### Test 5 — Results Quantification Test
Are results backed by specific numbers from context (compartment 5 social_proof_assets)?
- PASS: specific claims tied to specific proofs
- FAIL: results claimed without numeric backing (= INV-6 violation + T-gate fail)

## Enforcement in Skills

Every SKILL.md must include a `## Verification` section declaring:
1. Which triple-layer weights apply (usually 40/35/25 default, some skills override)
2. Which of the 5 internal tests are required for pass
3. Whether this output requires Blind Output Test (sacred formats = yes)
4. Signal threshold (external 0.8 default, internal 0.5 default)

## Violation Handling

1. **Attempt 1 (auto-revise):** Skill identifies the failure mode and produces one revision addressing it
2. **Attempt 2 (creator-assisted):** If revision fails, skill surfaces the specific gap + asks creator a targeted question to fill it
3. **Escalate:** After 2 attempts, skill halts and logs to `evidence/failure-modes.md`. Creator manually resolves.

## Relationship to INVARIANTS.md

Quality gates operationalize INV-5 (Truth), INV-6 (No Fabrication), INV-7 (Banned Vocab), INV-12 (Signal 5-tuple), INV-13 (S/N gate), INV-14 (Blind Output Test). Violations of those invariants trigger REJECT regardless of score.

## Sources

- Signal Theory p.41 (Triple-Layer Verification formula)
- Growth Operating Agency Master Prompt Section 7 (5 Internal Quality Tests)
- the workspace manifest `protocol/verification.md`

---
*v1.0 — 2026-04-19*
