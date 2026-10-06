# Blind Output Test — /ad-creative

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces an **Ad Creative Brief**. Classification: **external** — requires **2/3 evaluator pass** before live paid traffic. Ads are the public face of the offer — broken creative burns ad spend + pollutes the pixel.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. A paid-acquisition operator running $50K+/mo on Meta with 3:1+ LTV:CAC (the growth engineer / the paid media director / the operations director lineage preferred)
2. A target prospect inside the ICP — blind-read the ad copy, gauge specificity + voice
3. A Meta compliance reviewer or ex-ad-account-rep who can stress-test policy compliance

## Test Protocol

### 1. Output Set
- 2 historical ad creative briefs produced by the creator or a hired paid-ads strategist
- 3 ad creative briefs produced by `/ad-creative` (different ad types across different creator contexts)
- 1 generic-LLM ad brief (control — no compartments, no VOC integration)

All briefs anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per brief)
For each brief, evaluator answers:
1. "Did a paid-ads strategist/creator produce this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you launch this family?" yes / no / with revisions (operator-evaluator)
5. "Does this ad speak to you?" yes / no / partial (prospect-evaluator)
6. "Rate the Hook specificity (variant 1) 1-10"
7. "Rate the overall Creative Family coherence 1-10"
8. "Compliance: Meta policy + FTC + banned vocab" PASS / FAIL (compliance-evaluator)

### 3. Pass Criteria
For `/ad-creative` to be blind-test-validated (external tier 2/3):
- **2/3 Growth Operating Agency briefs** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM brief** should be identified as `creator`
- Average "Would you launch this?" score ≥ 60% yes
- Average Hook specificity rating ≥ 7/10
- Average Creative Family coherence rating ≥ 7/10
- Compliance PASS on 3/3 briefs (hard gate — compliance failure = rejected by Meta)

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Generic hooks (missing verbatim VOC from ICP Section 9)
- Specificity Score below 8 on any dimension (audience / problem / mechanism / outcome / creative)
- Mechanism not referenced (no tie-back to Positioning Doc)
- Voice mismatch (creator wouldn't phrase it that way)
- Compliance violations (income guarantees, health claims, before/after without disclaimer)
- Ad type mismatch (polished creative for UGC-fatigued audience)
- Campaign structure wrong (multiple CTAs per ad, bid-increase scaling, broad cold reach from day 1)

## Known Failure Modes (to watch for)

1. **Specificity below 8** — Hook reads "significant income boost" instead of "$7,500 in 2 hours." Fix: Phase 6 hard gate — 5-dimension scoring + sum/5 ≥ 8 before ship.

2. **Generic hook (no VOC)** — Hook doesn't use ICP Section 9 verbatim language. Fix: require 3+ VOC phrases per variant family pulled from ICP doc.

3. **Voice mismatch** — Creator's direct/blunt voice comes through as consultative/friendly. Fix: Phase 3 Voice-Match against Compartment 1.phrases_to_use; 3+ placements per variant.

4. **Compliance miss** — Income guarantees or health claims slip through. Fix: Phase 5 checklist covers FTC + Meta restricted categories + banned vocab; reject immediately on violation.

5. **Multiple CTAs** — Ad has "Apply now" and "Book call" and "DM me." Fix: Tacit Principle 4 — one CTA per ad, hard rule.

6. **Wrong scaling plan** — Recommendation to raise bids rather than duplicate campaigns at 2× budget. Fix: the growth engineer Creative Family Micro Tests is the scaling playbook — bid-increase breaks pixel learning.

7. **Ad type mismatch** — UGC selected for creator who only has polished studio content, or Profile Funnel for creator without optimized profile. Fix: Decision Tree honors creator infrastructure signals; Appendix A documents alternatives considered.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending) — test at least 3 ad types (Profile Funnel + Video Hook + UGC minimum)
- **Ongoing:** Every 10 runs, sample 1 brief for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test
- **Post-launch validation:** After 500+ impressions per variant, check CPL / CTR / downstream conversion against ad type benchmark

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production external use without 2/3 blind test pass. Cycle 3 Attract cornerstone — paid ads without this skill = pixel pollution + LTV:CAC collapse.*
