# Blind Output Test — /plan-launch

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **Launch Plan** (sacred format — a broken launch plan compounds losses across ad spend + email burn + team hours + reputational cost). Classification: **sacred-format** — requires **3/3 evaluator pass** before paid-traffic spend.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit — all three mandatory for sacred tier)

1. **The creator themselves** (mandatory — they carry execution risk; plan must be something they can actually deliver with their team + tech stack; every task assignment must be realistic)
2. **A launch-manager or operator from the creator's direct network** (someone who has run 5+ launches themselves; evaluates runbook realism, team-assignment feasibility, tech-checklist completeness, and phase-to-phase transition logic)
3. **A past paying customer from a previous launch** (deep-audience member who bought during a prior launch window; evaluates whether the buyer-facing cadence will feel like momentum or like a blast — catches tone/pace mismatches a third-party consultant would miss)

## Test Protocol

### 1. Output Set
- 2 historical launch plans the creator + team built for past launches (with known outcomes — ideally one hit, one miss)
- 3 plans produced by `/plan-launch` (different variants: e.g., one Live Launch, one 5-Day Flash Sale, one Beta)
- 1 generic-LLM launch plan (control — no Growth Operating Agency context, no upstream asset integration)

All outputs anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order. Reviewers see full runbook + dependency check + team grid + tech checklist + KPI targets.

### 2. Evaluation Questions (per plan)
For each plan, evaluator answers:
1. "Did the creator + launch team build this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "If you were on the launch team, would you execute this plan as written?" yes / no / with revisions
5. "Rate the dependency check 1-10"
6. "Rate the team-assignment realism 1-10"
7. "Rate the tech checklist completeness 1-10"
8. "Rate the KPI targets (realistic vs fantasy) 1-10"

### 3. Pass Criteria (sacred tier — 3/3)
For `/plan-launch` to be blind-test-validated:
- **3 of 3 Growth Operating Agency plans** must have ≥ 1 evaluator say `creator` or `can't tell` (sacred tier — no slack)
- **No generic-LLM plan** should be identified as `creator`
- Average "Would you execute this?" ≥ 70% yes for Growth Operating Agency plans
- Average dependency-check rating ≥ 7/10
- Average team-assignment rating ≥ 7/10
- Average tech-checklist rating ≥ 7/10
- Average KPI-realism rating ≥ 7/10

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Dependency check incomplete (VSL or landing page listed as "in progress" on launch day)
- Team assignments to "team" instead of named owner
- Tech checklist missing pixel + CAPI verification
- KPI targets generic ("sell more") instead of specific numbers
- Hour-by-hour launch-day runbook missing
- Analyze phase handwaved ("review metrics") with no optimization protocol
- Banned vocabulary (disruptor / paradigm shift / leverage)

## Known Failure Modes (to watch for)

1. **Dependency check hand-waved** — Plan lists "VSL ready" as checked without referencing actual output file. Launch day discovers VSL isn't done. Money-burn begins. Fix: Phase 3 requires explicit file-path citation to `/output/build-vsl/...` etc.; reject if any dependency unresolved.

2. **Team assignments to "team"** — Tasks owned by "marketing" or "ops" instead of named person. Accountability gap. Fix: Phase 4 requires named owner per task; reject "team" as owner.

3. **Pixel/CAPI not verified in tech checklist** — Skill auto-checks the box without verification step. Launch ads run without proper tracking. Attribution broken. Fix: Phase 5 requires verification command/screenshot reference, not just a checkbox.

4. **KPI targets fantasy math** — "1000 opt-ins/day" on a list that historically does 50. Teams demoralize by Day 2. Fix: Phase 6 requires historical-baseline reference from `company.yaml` + variance analysis; reject if variance > 3x without explicit reasoning.

5. **Launch-day runbook missing hourly detail** — Just says "Day 1: send emails." No hourly cadence. Chaos ensues. Fix: Phase 2 requires hourly table for T+0 (launch day) at minimum.

6. **Analyze phase handwaved** — "Review metrics at end" with no daily optimization cadence. Leaks compound. Fix: Phase 7 requires daily review time + specific metric thresholds + fix-path protocol.

7. **Upstream asset missing but plan produced anyway** — E.g., `/post-booking-nurture` incomplete but plan proceeds. Show-rate collapses. Fix: Pre-flight gate — all upstream outputs must exist or be explicitly flagged as blockers.

## Production Validation Cadence (sacred — strict)

- **Baseline test:** At skill v1.0 launch (pending — MANDATORY before any production run)
- **Pre-launch (every launch):** 3/3 blind-test panel review before paid-traffic spend begins
- **Mid-launch (every launch):** After Phase 2 Launch Day, sanity check plan vs actual; if variance > 30%, escalate
- **Post-launch:** Feed results into `/launch-report`; if any sacred gate failed, rerun blind test before next launch
- **Change-triggered:** After ANY edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline 3/3 test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment (3/3 sacred — creator + launch-manager peer + past paying customer mandatory)

---
*Per INV-14 — no skill ships to production sacred-format use without 3/3 blind test pass. Launch plans are sacred because a broken plan compounds losses across every upstream asset. No exceptions.*
