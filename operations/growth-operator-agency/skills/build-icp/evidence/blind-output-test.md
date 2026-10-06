# Blind Output Test — /build-icp

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces an **ICP Document**. Classification: **internal** — requires **1/3 evaluator pass** before the artifact is used as audience ground truth for downstream external-facing skills.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. The creator or their long-tenured research/sales lead (6+ months in role)
2. A past buyer of the creator's offer who has given feedback on internal research docs
3. A peer founder in an adjacent niche who has built their own ICP

## Test Protocol

### 1. Output Set
- 2 historical ICP Documents produced by the creator or their team
- 3 ICP Documents produced by `/build-icp` (different creator contexts)
- 1 generic-LLM ICP (control — no Growth Operating Agency context)

All outputs anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per ICP)
For each ICP, evaluator answers:
1. "Did the creator/team produce this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you act on this ICP (for offer design / copy / targeting)?" yes / no / with revisions
5. "Rate the Psychological Architecture (Section 4) 1-10"
6. "Rate the Voice of Customer (Section 9) 1-10"

### 3. Pass Criteria
For `/build-icp` to be blind-test-validated (internal tier 1/3):
- **≥ 1 of 3 Growth Operating Agency ICPs** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM ICP** should be identified as `creator`
- Average "Would you act on this?" score ≥ 50% yes for Growth Operating Agency ICPs
- Average Psychological Architecture rating ≥ 7/10
- Average VOC rating ≥ 7/10

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Generic pain language (missing verbatim VOC from Section 9)
- Missing or wrong limiting belief diagnosis
- Awareness level assigned without behavioral evidence
- Banned vocabulary leaked through
- Psychographics that fail the 3am Test
- Completeness Score inflated without evidence depth

## Known Failure Modes (to watch for)

1. **Verbatim VOC under-count** — If creator has sparse real audience data, Section 9 falls back to inferred paraphrase. Fix: enforce `[VERBATIM: source]` tagging and block section at < 20 verbatim quotes.

2. **Limiting belief misdiagnosed** — Worthless / Helpless / Hopeless triad is subtle; wrong diagnosis corrupts every downstream offer+copy asset. Fix: require 3+ behavioral evidence pieces + explicit self-check question ("Could this alternately be [other two]?").

3. **Current-customer anchoring bias** — Creator's existing $2K customers anchor the ICP when the offer being designed is $10K. Fix: Tacit Principle 3 — "aspirant, not the current" — flag and re-separate.

4. **3am Test skipped** — Psychological Architecture reads intellectual, not visceral. Fix: hard gate Section 4 at 3am Test pass or cap score at 5/10.

5. **Completeness Score inflated** — Sections scored HIGH without the evidence depth to warrant it. Fix: require per-section confidence tags + cap LOW-confidence sections at 7/10.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending)
- **Ongoing:** Every 20 runs, sample 1 ICP for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production internal use without 1/3 blind test pass.*
