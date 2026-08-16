---
description: Produce a hiring brief for one of 8 roles — scorecard + ideal profile + compensation + 5-stage the growth engineer screening + 30/60/90 plan. Revenue-threshold-aware.
argument-hint: "[optional: --role=setter|closer|sdr|content-mgr|editor|cs|va|marketing-mgr]"
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /hiring-brief — slash-command runtime Runtime Binding

Load and execute `skills/hiring-brief/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/hiring-brief/SKILL.md` (full body)
   - read `skills/hiring-brief/reference/` (all files, if present)
   - `Read` upstream dependency output: `output/build-sop/latest-{role}.md` (SOP defines the role before the brief)

2. **Pre-flight check:** Verify `company.yaml` thresholds — offer_architecture ≥ 50, operational_intelligence ≥ 30. If below, recommend running `/build-sop` for the role first. Also cross-check creator's MRR against the VSL director's Revenue-Threshold Team Model.

3. **Execute Phase 0 → Phase 11** per SKILL.md Process section — Load, Revenue Threshold Check, Role Definition, Scorecard, Ideal Profile, Compensation, Outreach Script, Screening Flow (the growth engineer 5-stage), Interview Questions, Role Plays, 30/60/90 Plan, Compliance.

4. **Write output:**
   - `Write` to `output/hiring-brief/{YYYY-MM-DD}-hiring-brief-{role}.md`
   - Structure per SKILL.md Output Format (10 sections + 3 appendices)
   - If any section fails cross-validation, mark `[GAP: section N]` and continue

5. **Update company.yaml:** `Edit` compartment 11 (operational_intelligence) — append open-role reference + hiring timeline. Never overwrite existing values without confirmation.

6. **Post-ship:**
   - write `skills/hiring-brief/evidence/runs/{YYYY-MM-DD}-run.md` with phase log + confidence tags + role selected
   - Output next-skill recommendation (usually `/build-sop` if SOP missing, else skill for the role's function)

## Arguments

If `$ARGUMENTS` includes `--role=<role>`, select that specific role. Otherwise, interview the creator for team gap + revenue threshold and select.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for loading SKILL.md, company.yaml, reference/, upstream SOP
- **Write / Edit** for producing the brief and updating compartment 11
- **Grep** across `company.yaml` to check current team + revenue + existing open roles

## Quality gates

Before writing the brief to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification (formal 40% + semantic 35% + information-theoretic 25%)
- Check `spec/BANNED-VOCABULARY.md` — reject if any banned phrases
- Confirm every evidence_gate condition (role_selected, scorecard_5_plus_competencies, ideal_profile_specific, outreach_script_provided, interview_questions_5_plus_rounds, 30_60_90_plan_present, revenue_threshold_aligned)
- Signal Score ≥ 0.8
- Revenue threshold check is explicit PASS/HOLD with MRR named

## Failure handling

If skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode
- Attempt 2: surface the gap to creator with targeted question (often MRR/team data missing)
- If both fail: escalate to scale-head, log to `skills/hiring-brief/evidence/failure-modes.md`

## Cross-skill routing

After brief ships:
- Recommend `/build-sop` if SOP for the role does not yet exist
- Recommend `/retention-check` if role is CS (ties to retention tracking)
- Recommend `/revenue-report` to re-forecast P&L impact of the hire

---
*the slash-command adapter v1.0 — binds to skills/hiring-brief/SKILL.md*
