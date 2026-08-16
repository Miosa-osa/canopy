---
description: Revenue analysis + forecasting + P&L using unit economics + the operations director 60/30/10 revenue mix. Produces weekly/monthly/quarterly report with LTV:CAC.
argument-hint: "[optional: --period=weekly|monthly|quarterly]"
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /revenue-report — slash-command runtime Runtime Binding

Load and execute `skills/revenue-report/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/revenue-report/SKILL.md` (full body)
   - read `skills/revenue-report/reference/` (all files, if present)
   - `Read` upstream dependency output: `output/design-offer/latest.md` (offer economics baseline)
   - `Read` any Stripe / GA4 / GHL exports previously staged in `data/finance/`

2. **Pre-flight check:** Verify `company.yaml` thresholds — offer_architecture ≥ 70, lifecycle_optimization ≥ 30, operational_intelligence ≥ 20. If below, recommend running `/design-offer` first.

3. **Execute Phase 0 → Phase 6** per SKILL.md Process section — Load, Data Pull, Unit Economics Compute, Revenue Mix Diagnosis (vs 60/30/10), Cohort Analysis, Forecast (30/60/90), Recommendations.

4. **Write output:**
   - `Write` to `output/revenue-report/{YYYY-MM-DD}-revenue-report-{period}.md`
   - Structure per SKILL.md Output Format (8 sections: Executive Summary, Acquisition, Unit Economics, Revenue Mix, Cohort Analysis, Retention + Churn, Forecast, Recommendations)
   - If any section fails cross-validation, mark `[GAP: section N]` and continue

5. **Update company.yaml:** `Edit` compartment 3 (offer_architecture.economics_validation) + compartment 11 (operational_intelligence) — append period metrics + LTV:CAC verdict. Never overwrite existing values without confirmation.

6. **Post-ship:**
   - write `skills/revenue-report/evidence/runs/{YYYY-MM-DD}-run.md` with phase log + confidence tags + source breakdown per metric
   - Output next-skill recommendation per gap (e.g., `/design-offer` if LTV:CAC < 3:1, `/retention-check` if churn high)

## Arguments

If `$ARGUMENTS` includes `--period=<weekly|monthly|quarterly>`, scope the report to that period. Otherwise default to monthly.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for loading SKILL.md, company.yaml, reference/, staged Stripe/GA4/GHL exports
- **Write / Edit** for producing the report and updating compartments 3 + 11
- **Grep** across `company.yaml` and `data/finance/` to pull historical data points for trending

## Quality gates

Before writing the report to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification (formal 40% + semantic 35% + information-theoretic 25%)
- Check `spec/BANNED-VOCABULARY.md` — reject if any banned phrases
- Confirm every evidence_gate condition (all_metrics_pulled_from_source, ltv_cac_computed, revenue_mix_analyzed, forecast_generated)
- Signal Score ≥ 0.8
- No metric estimated — every number traces to a source (Stripe statement, GA4 property, CRM export)

## Failure handling

If skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode
- Attempt 2: surface the gap to creator with targeted question (often source data missing or stale)
- If both fail: escalate to scale-head, log to `skills/revenue-report/evidence/failure-modes.md`

## Cross-skill routing

After report ships:
- If LTV:CAC < 3:1 → recommend `/design-offer` (restructure price / continuity / upsells)
- If funnel economics broken → recommend `/build-funnel`
- If churn high → recommend `/retention-check`
- If revenue mix off 60/30/10 → recommend the underperforming channel's skill

---
*the slash-command adapter v1.0 — binds to skills/revenue-report/SKILL.md*
