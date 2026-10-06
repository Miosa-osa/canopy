# Blind Output Test — /research

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **Market Research Brief**. The brief is a "sacred format" because every downstream asset inherits from it — requires **3/3 evaluator pass** before skill is considered blind-test-validated.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. A creator who has run this skill on their own business
2. A seasoned market researcher from the creator's network
3. A top customer of the creator (someone who's given feedback on past research docs)

## Test Protocol

### 1. Output Set
- 2 briefs produced by the creator or their research team (historical or fresh)
- 3 briefs produced by `/research` (different creator contexts)
- 1 generic-LLM brief (control — no Growth Operating Agency context, just ChatGPT with basic prompt)

All briefs anonymized: strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per brief)
For each brief, evaluator answers:
1. "Did a creator/researcher produce this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you act on this brief?" yes / no / with revisions
5. "Rate the ICP section 1-10"
6. "Rate the Voice of Customer section 1-10"

### 3. Pass Criteria
For `/research` to be blind-test-validated:
- **≥ 2 of 3 Growth Operating Agency briefs** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM brief** should be identified as `creator` (re-calibrate test if so)
- Average "Would you act on this?" score ≥ 60% yes for Growth Operating Agency briefs
- Average ICP section rating ≥ 7/10
- Average VOC section rating ≥ 7/10

### 4. Post-Test Analysis
For any Growth Operating Agency brief flagged as `system`:
- What tipped them off? Look for patterns:
  - Generic pain language (missing verbatim VOC)
  - No specific limiting belief diagnosis
  - Weak or missing competitor whitespace
  - Banned vocabulary leaked through
  - Tonal mismatch with creator voice
  - Vague confidence tags

## Known Failure Modes (to watch for)

From Phase A skill authoring — most likely places `/research` will fail blind test:

1. **Voice of Customer section too generic** — If the creator has sparse real audience data, the skill falls back to inferred language which reads generic. Fix: enforce minimum 5 verbatim quotes with sources before section completes.

2. **Limiting belief misdiagnosed** — The the offer architect triad (Worthless/Helpless/Hopeless) is subtle. Wrong diagnosis = wrong offer downstream. Fix: add explicit self-check question "Could this belief alternately be [other two]? Why this one?"

3. **Competitor analysis shallow** — If the skill just lists 3 competitors without identifying whitespace, the output is descriptive not diagnostic. Fix: require named whitespace with specific evidence.

4. **Economics hand-waved** — If LTV:CAC math is based on guessed numbers, the 3:1 gate is fake. Fix: require actual paid-channel CPL data or explicit assumption disclosure.

5. **Executive Summary generic** — If Phase 9 reads like a LinkedIn post rather than a specific Go/No-Go, encoding failed. Fix: require specific Go/No-Go + specific North Star Insight + specific next action.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending)
- **Ongoing:** Every 10 runs, sample 1 brief for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production sacred-format use without 3/3 blind test pass.*
