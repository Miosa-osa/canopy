# Blind Output Test — /write-youtube

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **YouTube Long-Form Script**. Classification: **external** — requires **2/3 evaluator pass** before publishing. YouTube is the content OS director's "only platform that nurtures to high-ticket" — broken long-form = broken authority-build + broken conversion nurture.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. A YouTube creator operating at 100K+ subs with evergreen-video experience (the content OS director / the VSL director / the short-form-frameworks author / creator-native methodology lineage preferred)
2. A target prospect inside the ICP who consumes the creator's existing YouTube content
3. An algorithm-savvy YouTube strategist who can predict CTR + AVD + session-starter behavior

## Test Protocol

### 1. Output Set
- 2 historical YouTube scripts produced by the creator or their writer
- 3 YouTube scripts produced by `/write-youtube` (different types across different creator contexts — include at least one Educational + one Case Study + one VSSL)
- 1 generic-LLM YouTube script (control — no compartments, no voice extraction)

All scripts anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per script)
For each script, evaluator answers:
1. "Did a YouTube creator produce this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you publish this script?" yes / no / with revisions
5. "Would you watch past 30 seconds?" yes / no (prospect-evaluator)
6. "Rate the Hook (0-15s) 1-10"
7. "Rate the Title + Thumbnail Complementary Check 1-10"
8. "Predict CTR + AVD vs type benchmark" above / at / below (strategist-evaluator)

### 3. Pass Criteria
For `/write-youtube` to be blind-test-validated (external tier 2/3):
- **2/3 Growth Operating Agency scripts** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM script** should be identified as `creator`
- Average "Would you publish?" score ≥ 60% yes
- Average Hook rating ≥ 7/10
- Average Title/Thumbnail rating ≥ 7/10
- Predicted CTR at-or-above benchmark on 2/3 scripts

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Hook fails to pay off title promise in first 10-15s
- Title + thumbnail redundant (same message — Facebook-ad principle violated)
- Curiosity loops opened but not closed by 80% mark
- Binge Loop missing on non-VSSL videos
- VSSL flipped to 20% story / 80% mechanism (wrong ratio)
- Length miscalibrated (30-min script for cold audience; 8-min for VSSL)
- Voice mismatch (phrases_to_use absent)
- Pre-script content brief thin or skipped
- Three-Part Formula absent from body sections
- Banned vocabulary leaked through
- Fabricated results / case studies

## Known Failure Modes (to watch for)

1. **Title promise not paid off in hook** — Title promises X, first 15 seconds don't deliver. Fix: Tacit Principle 1 — hook must pay off title promise immediately; 10-15s structural check before body writing.

2. **Title + thumbnail redundant** — Both say the same thing. Fix: Phase 3 Complementary Check — must convey 2 distinct messages per Facebook-ad principle.

3. **Open curiosity loops at outro** — Video ends with a loop still open. Fix: Tacit Principle 8 + Phase 7 Loop Management — 3-5 loops, all closed by 80% mark.

4. **Missing Binge Loop** — Non-VSSL video has no Link-Back → New Problem → Next Video Promise outro. Fix: Tacit Principle 9 — Binge Loop mandatory for non-VSSL; seeds next video for session time.

5. **VSSL 80/20 flipped** — Script is 70% mechanism teaching / 30% story. Fix: hard rule — VSSL is 80% story+problem / 20% mechanism+solution; reject if flipped.

6. **Length miscalibrated** — 30-min script targeted at cold/low-quality audience. Fix: Length Calibration table — cold = 7-12 min; VSSL = 20-45 min; match audience sophistication.

7. **Read-aloud fails** — Script sounds like "reading" not "speaking." Fix: Tacit Principle 7 — read aloud, rewrite if it sounds like reading; voice-match non-negotiable.

8. **Thin content brief** — Phase 2 brief has Essential Question but no ICP persona, no Three-Answer Framework, no Viral Value Elements. Fix: Phase 2 hard gate — all brief sub-fields required before script body.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending) — test at least 3 types (Educational + Case Study + VSSL minimum)
- **Ongoing:** Every 10 runs, sample 1 script for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, Process, or MODULE 4 reference, rerun baseline test
- **Post-publish validation:** 24h CTR + 7d AVD + 30d session-starter-behavior measured against type benchmark

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production external use without 2/3 blind test pass. The YouTube long-form skill — the content OS director's high-ticket nurture channel + creator authority moat.*
