# Blind Output Test — /revenue-report

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **Revenue Report** (P&L + unit economics + forecast). Classification: **internal** — requires **1/3 evaluator pass**.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. A finance / ops team member who owns the creator's P&L reporting day-to-day (knows the real numbers and what a usable weekly / monthly report looks like)
2. A fractional CFO serving multiple coaching / agency businesses (has reviewed 100+ LTV:CAC analyses and knows benchmark sanity)
3. A unit-economics-literate growth operator (e.g., the operations director-style KPI discipline practitioner) who can evaluate whether forecasts are defensible

## Test Protocol

### 1. Output Set
- 2 revenue reports produced by the creator's finance team (historical monthly or quarterly)
- 3 revenue reports produced by `/revenue-report` (different creator businesses or periods)
- 1 generic-LLM report (control — ChatGPT prompted with raw Stripe numbers and "write a monthly revenue report")

All reports anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per report)
For each report, evaluator answers:
1. "Did a finance/ops team produce this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you make capital-allocation decisions from this report?" yes / no / with revisions
5. "Rate the Unit Economics section 1-10" (LTV:CAC math sound, sources cited)
6. "Rate the Forecast 1-10" (assumptions stated, defensible, not hand-waved)

### 3. Pass Criteria
For `/revenue-report` to be blind-test-validated:
- **≥ 1 of 3 Growth Operating Agency reports** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM report** should be identified as `creator`
- Average "Would you make decisions?" score ≥ 50% yes
- Average Unit Economics rating ≥ 7/10
- Average Forecast rating ≥ 7/10

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Metrics estimated instead of pulled from source
- LTV formula missing cohort adjustment
- CAC calculation missing channel breakdown
- Revenue mix diagnosis missing vs 60/30/10 target
- Forecast assumptions unstated
- Recommendations generic ("raise prices") vs. specific fix path
- Banned vocabulary leaked through

## Known Failure Modes (to watch for)

1. **Metrics estimated** — Skill fills in plausible numbers when Stripe / GA4 data is missing. Fix: require every metric to be traced to a source artifact; unknowns marked `[GAP: source needed]` and not estimated.

2. **LTV hand-waved** — LTV computed without cohort adjustment (just AOV × arbitrary lifespan). Fix: require LTV = AOV × (1 - churn rate) × months retained + upsells + referrals, with each term sourced.

3. **CAC aggregated** — Single CAC across all channels hides the broken one. Fix: require per-channel CAC breakdown (paid Meta, paid YouTube, organic, affiliate, referral).

4. **Revenue mix skipped** — Report shows totals without 60/30/10 diagnosis. Fix: enforce Phase 3 Revenue Mix Diagnosis as a hard gate.

5. **Forecast without assumptions** — 30/60/90 numbers stated without run-rate basis, pipeline inputs, or seasonality notes. Fix: require assumptions block below every forecast period.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending)
- **Ongoing:** Every 20 runs, sample 1 report for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production internal use without 1/3 blind test pass.*
