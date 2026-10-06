---
description: Produce a Standard Operating Procedure for one of 14 role/process variants. Outputs SOP + KPIs + quality gates + escalation rules + training plan.
argument-hint: "[optional: --variant=<role|process>]"
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /build-sop — slash-command runtime Runtime Binding

Load and execute `skills/build-sop/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/build-sop/SKILL.md` (full body)
   - read `skills/build-sop/reference/` (all files, if present)
   - `Read` upstream dependency output: `output/design-offer/latest.md` (offer mechanism informs process)

2. **Pre-flight check:** Verify `company.yaml` thresholds — audience_intelligence_system ≥ 30, offer_architecture ≥ 50, conversion_sales ≥ 30, operational_intelligence ≥ 30. If below, recommend running upstream `/design-offer` first or enter Compartment Interview Mode for compartment 11 (team structure).

3. **Execute Phase 0 → Phase 10** per SKILL.md Process section — Load, Variant Selection, Role/Process Definition, Inputs + Triggers, Phase-by-Phase Workflow, Quality Gates, KPIs, Tools + Systems, Escalation Rules, Training Plan, Review Cadence.

4. **Write output:**
   - `Write` to `output/build-sop/{YYYY-MM-DD}-sop-{variant}.md`
   - Structure per SKILL.md Output Format (9 sections + 2 appendices)
   - If any section fails cross-validation, mark `[GAP: section N]` and continue

5. **Update company.yaml:** `Edit` compartment 11 (operational_intelligence) — append SOP reference + owner + review cadence. Never overwrite existing values without confirmation.

6. **Post-ship:**
   - write `skills/build-sop/evidence/runs/{YYYY-MM-DD}-run.md` with phase log + confidence tags + variant selected
   - Output next-skill recommendation (usually `/hiring-brief` for the role)

## Arguments

If `$ARGUMENTS` includes `--variant=<role|process>`, select that specific SOP variant. Otherwise, interview the creator for team gap identification and select.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for loading SKILL.md, company.yaml, reference/, and upstream `/design-offer` output
- **Write / Edit** for producing the SOP and updating compartment 11
- **Grep** across `company.yaml` to check current team structure + existing SOPs

## Quality gates

Before writing the SOP to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification (formal 40% + semantic 35% + information-theoretic 25%)
- Check `spec/BANNED-VOCABULARY.md` — reject if any banned phrases
- Confirm every evidence_gate condition (variant_selected, full_process_mapped_phase_by_phase, kpis_specified, quality_gates_declared, escalation_rules, training_plan)
- Signal Score ≥ 0.8
- Every phase has a DONE criterion; every KPI is numeric + time-bound

## Failure handling

If skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode
- Attempt 2: surface the gap to creator with targeted question (often team structure ambiguity)
- If both fail: escalate to scale-head, log to `skills/build-sop/evidence/failure-modes.md`

## Cross-skill routing

After SOP ships:
- Recommend `/hiring-brief` if role is unfilled
- Recommend `/retention-check` if CS SOP is the variant
- Recommend `/revenue-report` if Reporting SOP is the variant

---
*the slash-command adapter v1.0 — binds to skills/build-sop/SKILL.md*
