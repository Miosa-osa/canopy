---
description: Post-launch analysis. Consumes launch plan + actual performance data. Diagnoses which of 5 phases leaked. Produces plan-vs-actual variance + fix paths + next-launch playbook.
argument-hint: [optional: launch-slug to report on]
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /launch-report — slash-command runtime Runtime Binding

Load and execute `skills/launch-report/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/launch-report/SKILL.md` (full body)
   - read `skills/launch-report/reference/` if present
   - `Read` upstream: `output/plan-launch/latest.md` (target plan), actual performance data from `company.yaml` launch_strategy.actuals + integration outputs (GA4, Stripe, GHL, Meta)

2. **Pre-flight check:** Verify `required_compartments` — funnel_systems ≥ 60, lifecycle_optimization ≥ 30. Launch must be T+7 or later (post-launch window closed). Actual performance data must be populated.

3. **Execute Phase 0 → Phase 4** per SKILL.md Process:
   - Phase 0 Load (plan + actuals) → Phase 1 Plan vs Actual Variance (per KPI: target vs actual, variance %) → Phase 2 Phase-by-Phase Leak Diagnosis (the operations director 8-stage journey audit × 5 launch phases) → Phase 3 Fix Paths (per leak: specific fix + owner + deadline) → Phase 4 Next-Launch Recommendations (repeat / change / cut)

4. **Write output:**
   - `Write` to `output/launch-report/{YYYY-MM-DD}-{offer-slug}-launch-report.md`
   - Structure per SKILL.md Output Format — plan vs actual table, phase-by-phase diagnosis, fix paths grid, next-launch recommendations, asset performance breakdown

5. **Update company.yaml:**
   - edit `company.yaml` compartment 11 (lifecycle_optimization) with learnings
   - Append to launch_strategy.historical_actuals for baseline reference

6. **Post-ship:**
   - write `skills/launch-report/evidence/runs/{YYYY-MM-DD}-run.md`
   - Recommend next skills: `/plan-launch` (next launch with corrections), `/build-funnel` (if funnel leaks), `/ad-creative` (if creative underperformed)

## Arguments

If `$ARGUMENTS` contains a launch-slug, target that specific launch's plan + actuals. Otherwise default to most recent `/plan-launch` output.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for SKILL.md, launch plan, company.yaml actuals, integration analytics
- **Write / Edit** for report artifact + company.yaml historical updates
- **Grep** `company.yaml` for historical baselines + prior launch variance patterns

## Quality gates

Before writing to `output/`:
- Plan vs actual variance computed per KPI (evidence gate)
- Phase-by-phase leak diagnosis complete (5 phases) (evidence gate)
- Fix paths with owner + deadline per leak (evidence gate)
- Next-launch recommendations (repeat / change / cut) (evidence gate)
- Signal Score ≥ 0.8
- Banned vocabulary clean
- Blind Output Test 1/3 queued (internal tier)

## Failure handling

Per `workflows/handoffs/quality-revision.md`: auto-revise → surface gap → escalate to launch-head, log to `skills/launch-report/evidence/failure-modes.md`.

## Cross-skill routing

- Downstream: `/plan-launch` (apply corrections to next launch), `/build-funnel` (if funnel leaks), `/ad-creative` (if creative underperformed), `/email-sequence` (if email leak), `/post-booking-nurture` (if show-rate leak)
- On internal-tier completion: Blind Output Test 1/3 optional but recommended

---
*the slash-command adapter v1.0 — binds to skills/launch-report/SKILL.md*
