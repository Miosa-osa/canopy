# Blind Output Test — /launch-report

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **Launch Report** (internal retrospective — not buyer-facing, not published externally). Classification: **internal** — requires **1/3 evaluator pass** for internal-use validity.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. The creator themselves (primary reviewer — the fix paths must be ones they can execute, the next-launch recommendations must match their reality)

Optional secondary reviewers (not required for 1/3 pass but recommended):
2. A launch-team member who ran the launch (ops or marketing lead on the actual execution)
3. A peer launch-manager from the creator's network (external calibration on whether the diagnosis logic is sound)

## Test Protocol

### 1. Output Set
- 2 historical post-launch retrospectives the creator + team wrote (ideally with their actual fix paths and next-launch deltas documented)
- 3 reports produced by `/launch-report` (different launch variants — e.g., one Live Launch win, one Flash Sale miss, one Beta)
- 1 generic-LLM report (control — no Growth Operating Agency context, no phase-by-phase diagnosis framework)

All outputs anonymized where possible. Strip creator names, replace brand names with `[BRAND]`, randomize order. Reviewers see plan-vs-actual tables + phase diagnoses + fix paths + next-launch recommendations.

### 2. Evaluation Questions (per report)
For each report, evaluator answers:
1. "Did the creator + team author this retrospective, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you use this report to plan the next launch?" yes / no / with revisions
5. "Rate the leak-diagnosis accuracy 1-10"
6. "Rate the fix-path specificity 1-10"

### 3. Pass Criteria (internal tier — 1/3)
For `/launch-report` to be blind-test-validated:
- **≥ 1 of 3 Growth Operating Agency reports** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM report** should be identified as `creator`
- Average "Would you use this?" ≥ 50% yes for Growth Operating Agency reports
- Average leak-diagnosis rating ≥ 6/10
- Average fix-path rating ≥ 6/10

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Plan-vs-actual variance numbers fabricated (no actual data source)
- Leak diagnosis generic ("emails underperformed") instead of specific
- Fix paths without named owner
- Fix paths without deadline
- Next-launch recommendations vague ("do better next time")
- Missing asset-performance breakdown (per-email, per-ad, per-stage)
- Banned vocabulary (disruptor / paradigm shift)

## Known Failure Modes (to watch for)

1. **Variance numbers fabricated** — Skill produces plan-vs-actual table without actually reading integration data (GA4, Stripe, GHL). Report looks rigorous but numbers are imagined. Fix: Phase 1 requires explicit integration-output citation; reject if no sourced data.

2. **Leak diagnosis generic** — "Emails underperformed" instead of "Email 3 open rate 12% vs target 30% — subject too generic." No actionable path. Fix: Phase 2 requires specific metric + specific cause hypothesis + specific evidence citation.

3. **Fix paths without owner or deadline** — "Improve subject lines." No owner. No date. Never happens. Fix: Phase 3 requires owner column + deadline column; reject blanks.

4. **Next-launch recommendations vague** — "Do more of what worked." Not useful. Fix: Phase 4 requires concrete Repeat / Change / Cut items with specific asset references.

5. **Missing asset-performance breakdown** — Top-line revenue reported but no per-email, per-ad, per-stage data. Can't diagnose the actual leak. Fix: Asset Performance section mandatory.

6. **the operations director 8-stage journey audit not applied** — Skill lists 5 phases but doesn't audit each with the 8-stage customer journey lens. Fix: Phase 2 requires explicit the operations director audit mapping per phase.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending)
- **Ongoing:** Every 5 launch reports, sample 1 for blind-test review
- **Drift check:** Semi-annually (launches are less frequent than other artifacts)
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — internal-tier skills require 1/3 blind test pass. Launch reports are internal retrospectives, not buyer-facing; lower bar reflects audience (creator + team) vs external tier.*
