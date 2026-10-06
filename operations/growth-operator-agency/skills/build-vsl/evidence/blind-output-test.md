# Blind Output Test — /build-vsl

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **VSL Script**. Classification: **sacred-format** — requires **3/3 evaluator pass** before any paid traffic. This is the asset that ad spend points at — broken VSL = burned budget.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. A direct-response copywriter with VSL production experience (the VSL director / the psychological copywriter / the VSL copywriter lineage preferred)
2. A target prospect inside the ICP (someone at the offer's price-point aspirant identity) — blind read
3. A compliance/brand-safety reviewer who can stress-test Truth Gate + INV-6 No Fabrication + FTC disclosure

## Test Protocol

### 1. Output Set
- 2 historical VSL scripts produced by the creator's team or a hired VSL copywriter
- 3 VSL scripts produced by `/build-vsl` (different variants across different creator contexts — include at least one 15-step + one pull-push-persuade 11-step)
- 1 generic-LLM VSL (control — no compartments, just "write me a VSL for X offer")

All scripts anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per script)
For each VSL, evaluator answers:
1. "Did a copywriter/creator produce this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you watch this VSL to completion?" yes / no / partial (prospect-evaluator)
5. "Would you run paid traffic to this?" yes / no / with revisions (copywriter-evaluator)
6. "Rate the Hook + Lead (opening beats) 1-10"
7. "Rate the Crossroads/Persuade Close 1-10"
8. "Compliance: Truth Gate + Fabrication + Brand Safety" PASS / FAIL (compliance-evaluator)

### 3. Pass Criteria
For `/build-vsl` to be blind-test-validated (sacred tier 3/3):
- **3/3 Growth Operating Agency scripts** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM script** should be identified as `creator`
- Average "Would you run paid traffic?" score ≥ 70% yes
- Average Hook rating ≥ 7/10
- Average Close rating ≥ 7/10
- Compliance PASS on 3/3 scripts

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Selling before Step 9 / Persuade phase (the psychological copywriter invariant violation)
- Generic hook (doesn't filter for specific ICP)
- Missing mechanism thread (not in Hook / Problem / Solution / Testimonials / Close)
- Non-isomorphic case studies (starting situation doesn't match prospect)
- Voice mismatch ("creator wouldn't say these words")
- Wrong variant for context (slide-VSL where face-VSL required)
- Timid close (signals low creator confidence in offer)
- Missing or under-installed belief (not all 8 of the VSL director's beliefs present)
- Banned vocabulary leaked through
- Fabricated results / testimonials / numbers

## Known Failure Modes (to watch for)

1. **Voice mismatch is the #1 blind-test killer** — Script sounds "AI-written" because phrases_to_use weren't inserted or creator's rhythm wasn't matched. Fix: Phase 5 Voice-Match Pass is non-optional; require 3+ phrases_to_use per beat.

2. **Mechanism not threaded** — Mechanism named in Solution beat but missing from Hook / Problem / Testimonials / Close. Fix: Phase 6 Mechanism Thread Check — must appear in 5 key beats.

3. **Non-isomorphic case studies** — Impressive but not relatable case study leaks trust. Fix: Phase 7 — rank case studies by isomorphic fit (starting situation + outcome + process) before selection.

4. **Selling too early** — CTA or pitch before Step 9 (the VSL director/the psychological copywriter) or equivalent in other variants. Fix: beat-by-beat structural check — flag any pitch language before Persuade phase.

5. **Wrong variant selected** — Face-VSL written for creator who won't appear on-camera, or 15-step used on YouTube-native content. Fix: Variant Selection Decision Tree is hard-coded; confirm with creator before writing body.

6. **Under-installed beliefs** — Belief map shows 6/8 installed; script ships anyway. Fix: hard gate — all 8 installed or HOLD.

7. **Timid close** — Close reads "would be great if you clicked" instead of forcing decision. Fix: Tacit Principle 7 — "close like you mean it"; Crossroads Close non-optional for Variant A.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending) — must test at least 2 variants (A + B minimum) separately
- **Ongoing:** Every 5 runs, sample 1 script for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, Process, or variant reference files, rerun baseline test
- **Variant-specific tracking:** Track pass rate per variant independently (Variant A may pass while D struggles)

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment (including per-variant validation)

---
*Per INV-14 — no skill ships to production sacred-format use without 3/3 blind test pass. Cycle 2 Sales hero skill. Broken VSL = burned ad spend.*
