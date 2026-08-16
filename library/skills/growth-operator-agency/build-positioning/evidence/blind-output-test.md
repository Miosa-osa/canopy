# Blind Output Test — /build-positioning

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **Positioning Document**. Classification: **sacred-format** — requires **3/3 evaluator pass** before the positioning is used to drive VSL, ad creative, or any paid-traffic asset.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. A positioning specialist or brand strategist from the creator's network (the campaign director / the VSL director-lineage preferred)
2. A top customer of the creator who can recognize the creator's voice in the Core Belief Statement
3. A direct competitor's past customer (to validate the Old Vehicle Autopsy resonates)

## Test Protocol

### 1. Output Set
- 2 historical Positioning Documents produced by the creator or a hired strategist
- 3 Positioning Documents produced by `/build-positioning` (different creator contexts)
- 1 generic-LLM positioning (control — no Growth Operating Agency context)

All outputs anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per document)
For each document, evaluator answers:
1. "Did a strategist/creator produce this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you act on this positioning (build VSL / ads / sales)?" yes / no / with revisions
5. "Rate the Unique Mechanism (Section 5) 1-10"
6. "Rate the Core Belief Statement (Section 6) 1-10"

### 3. Pass Criteria
For `/build-positioning` to be blind-test-validated (sacred tier 3/3):
- **3/3 Growth Operating Agency documents** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM document** should be identified as `creator`
- Average "Would you act on this?" score ≥ 70% yes for Growth Operating Agency docs
- Average Unique Mechanism rating ≥ 7/10
- Average Core Belief rating ≥ 7/10

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Mechanism name is adjective-form instead of noun (category failure)
- Old Vehicle Autopsy blames competitors instead of naming category-level structural failure
- Core Belief Statement reads intellectual (fails 3am Test)
- Big Enemy not named or vague
- Narrative doesn't pass Isomorphic Story check (no 3+ real cases fit)
- Positioning strategy doesn't match declared Market Sophistication stage
- Banned vocabulary leaked through

## Known Failure Modes (to watch for)

1. **Adjective-form Vehicle Switch** — "Better content strategy" instead of "Content Operating System." Fix: hard reject any category name that isn't noun-form; Tacit Principle 2.

2. **Competitor-level Old Vehicle Autopsy** — "X competitor is bad" instead of "the entire category of X structurally fails because Y." Fix: require named CATEGORY failure with evidence from ICP VOC + competitor analysis.

3. **Intellectual Core Belief Statement** — Reads like a LinkedIn tagline rather than a belief the ICP wakes up agreeing with at 3am. Fix: draft 3-5 candidates + rank by 3am Test + Big Enemy embedded + creator defensibility.

4. **Missing Big Enemy** — Positioning without a named opposition is mush. Fix: require Big Enemy explicitly named in Section 1 summary.

5. **Non-isomorphic narrative** — Hero's Journey protagonist is the creator, not the ICP. Fix: Tacit Principle 5 — narrative mirrors ICP; creator is Mentor.

6. **Sophistication-strategy mismatch** — Declares Exhausted stage but proposes simple benefit positioning. Fix: cross-check Phase 1 declaration against Phase 2-6 strategy application.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending)
- **Ongoing:** Every 5 runs, sample 1 document for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production sacred-format use without 3/3 blind test pass.*
