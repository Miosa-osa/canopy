# BLIND-OUTPUT-TEST.md — The Encoding Completeness Protocol

> **The operational test of whether encoding is complete.** If at least one evaluator can't tell whether the output came from the creator or the system, encoding succeeded. If zero can tell, encoding is broken — revise.

## The Protocol

### Step 1 — Select 3 Evaluators
Three people who know the creator's work well enough to recognize their voice, mechanism, and decision-making. Candidates:
- Long-tenured team members (6+ months)
- Top customers who've consumed >10 hours of creator content
- Peers in the creator's network who've worked closely
- The creator's partner / spouse (often the best test)

Evaluators must NOT know which outputs were created by the system vs the creator.

### Step 2 — Prepare the Blind Set
Mix 5-10 outputs:
- 2-3 produced by the creator directly (historical or fresh)
- 3-5 produced by the Growth Operating Agency system
- (Optional) 1-2 produced by a generic LLM with no encoding (control group)

Strip all metadata. Remove timestamps. Randomize order.

### Step 3 — Ask Each Evaluator (independently, no comparison)
For each output, ask:
> "Did the creator produce this, or the system?"
>
> Options: [creator] / [system] / [can't tell]

Also capture (optional): "How confident?" (1-5 scale) + "What tipped you off?"

### Step 4 — Score

| Outcome per output | Interpretation |
|---|---|
| **≥ 1 evaluator says "creator" or "can't tell"** | PASS — encoding is complete for this output type |
| **0 say "creator" or "can't tell" (all say "system")** | FAIL — encoding is incomplete, revise |
| **Generic LLM output identified as "creator"** | FLAG — the encoding test is too permissive (re-calibrate) |

### Step 5 — Per-Skill Pass Rate
Each skill must demonstrate BlindTest pass rate:
- **Sacred formats** (VSL, core offer doc, brand voice doc): require **3/3 pass** (all three evaluators fooled or uncertain)
- **External/published formats** (posts, emails, ads): require **2/3 pass**
- **Internal/draft formats** (first passes, outlines): **1/3 pass** sufficient

## When to Run

- **Once per skill at development time** — before shipping the skill, run the test to baseline
- **Quarterly (ongoing)** — re-run on production outputs to catch drift
- **After any INVARIANTS.md or ENCODING.md change** — re-verify sacred formats
- **After major creator-context updates** — re-verify voice-dependent outputs

## What to Do With Results

### Pass
- Mark skill as "blind-test-validated" in `skills/{slug}/evidence/blind-output-test.md`
- Log the test date, evaluator identities, outputs tested
- Allow skill to produce the asset type without further gating

### Fail
- Identify WHICH outputs failed
- Interview the evaluators who identified them as "system": what tipped them off?
- Common failure modes:
  - Generic language (missing `voice_of_customer` pull)
  - Missing unique mechanism thread
  - Wrong tonal register
  - Banned vocabulary leaked through
  - Missing creator's signature quirks (compartment 1 language_patterns)
- Patch the skill's Decision Logic / Tacit Principles / Output Format
- Re-run the test with a fresh blind set

## Sacred Formats (always require 3/3 pass)

Per INVARIANTS.md, these output types require full pass before shipping:
- VSL script (any length)
- Core offer document
- Brand voice document
- Positioning document
- Guarantee copy
- Launch announcement assets
- Public-facing case studies

## Why This Matters

The Blind Output Test is the **operational proof** that the Encoded Founder methodology works. It's the test that makes "evaluated" a real brand claim instead of marketing language.

> "If three evaluators who know Jeff's work say 'Jeff' — the encoding is real. If all three say 'system' — we're shipping slop, and we're lying when we call it encoded."
>
> — (Adapted from the Encoded Founder methodology)

## Record-Keeping

Every Blind Output Test writes to:
```
skills/{slug}/evidence/blind-output-test.md
```

With structure:
```markdown
# Blind Output Test — {skill-name}

## Test Date
YYYY-MM-DD

## Evaluators
1. [Name or role, anonymized]
2. [Name or role, anonymized]
3. [Name or role, anonymized]

## Outputs Tested
| # | Source | Evaluator 1 | Evaluator 2 | Evaluator 3 | Result |
|---|---|---|---|---|---|
| 1 | Creator | creator ✓ | creator ✓ | creator ✓ | (control — PASS) |
| 2 | System | creator ✓ | creator ✓ | system ✗ | 2/3 PASS |
| 3 | System | system ✗ | system ✗ | can't-tell ✓ | 1/3 — FAIL for sacred |
| ... |

## Failure Analysis (if any outputs failed)
- Output #N failed because: [specific reason — e.g., "didn't use creator's signature closing phrase 'this is the play'"]
- Fix applied: [specific change to skill]
- Re-test scheduled: YYYY-MM-DD
```

## Source

- the Encoded Founder methodology — the Blind Output Test as verification of encoding completeness
- Heuresis vocabulary: "Every block is evaluated. Every workspace is evaluated. Every company we work with is evaluated."

---
*v1.0 — 2026-04-19*
