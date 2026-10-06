# Blind Output Test — /hiring-brief

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **Hiring Brief**. Classification: **internal** — requires **1/3 evaluator pass**.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. A hiring manager in the creator's network who has recently filled the same role (Setter / Closer / SDR / etc.) — knows what a usable brief looks like
2. A seasoned talent partner or recruiter (coaching/agency space) who has placed 50+ commercial hires
3. A recent hire (< 6 months) into a similar role — can evaluate whether the brief accurately represents the job they actually do

## Test Protocol

### 1. Output Set
- 2 hiring briefs produced by the creator's hiring team (or a peer's) — any roles
- 3 hiring briefs produced by `/hiring-brief` (different roles: e.g., Setter + Closer + Content Manager)
- 1 generic-LLM brief (control — ChatGPT prompted with "Write a hiring brief for a Setter role")

All briefs anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per brief)
For each brief, evaluator answers:
1. "Did a hiring team produce this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you run a hiring process from this brief?" yes / no / with revisions
5. "Rate the Scorecard 1-10" (measurable criteria + role-appropriate)
6. "Rate the 30/60/90 Plan 1-10" (realistic + milestone-specific)

### 3. Pass Criteria
For `/hiring-brief` to be blind-test-validated:
- **≥ 1 of 3 Growth Operating Agency briefs** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM brief** should be identified as `creator`
- Average "Would you run a hiring process?" score ≥ 50% yes
- Average Scorecard rating ≥ 7/10
- Average 30/60/90 rating ≥ 7/10

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Scorecard competencies generic (vs. role-specific measurable criteria)
- Revenue threshold missing or hand-waved
- Compensation bands off-market (either too high or too low for role+geography)
- Role plays generic (not rooted in real scenarios for the role)
- 30/60/90 vague (no week-by-week milestones or KPI targets)
- Banned vocabulary leaked through

## Known Failure Modes (to watch for)

1. **Revenue threshold skipped** — Skill recommends a $200K Marketing Mgr hire at $50K MRR. Fix: enforce the VSL director threshold check as a hard gate before the brief writes; flag mismatch and require creator override.

2. **Scorecard too generic** — "Strong communicator" instead of "< 5 min DM response 95% of the time on test week." Fix: require every competency to have a numeric + time-bound pass criterion.

3. **Compensation off-market** — Brief suggests $10K/mo base for a Setter. Fix: reference the per-role compensation table in SKILL.md with geography adjustment; flag deviations > 30%.

4. **Role plays generic** — "Handle an objection" vs. a specific scenario with named pain pattern. Fix: require role plays to reference real objection patterns from compartment 2 VOC.

5. **30/60/90 non-specific** — "Learn the product" vs. "By Day 30 — 3 booked calls, 80%+ qualify on-call." Fix: require each period to have a measurable KPI target.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending)
- **Ongoing:** Every 20 runs, sample 1 brief for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production internal use without 1/3 blind test pass.*
