---
description: Score client health, detect churn risk, propose interventions. Produces per-client Health Score + portfolio dashboard + intervention playbook.
argument-hint: "[optional: --period=last-30-days]"
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /retention-check — slash-command runtime Runtime Binding

Load and execute `skills/retention-check/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/retention-check/SKILL.md` (full body)
   - read `skills/retention-check/reference/` (all files, if present)
   - `Read` upstream dependency output: `output/build-sop/latest-cs.md` (CS SOP baselines intervention cadence)

2. **Pre-flight check:** Verify `company.yaml` thresholds — lifecycle_optimization ≥ 40, operational_intelligence ≥ 30. If below, recommend running `/build-sop` for CS first or enter Compartment 10 Interview Mode.

3. **Execute Phase 0 → Phase 4** per SKILL.md Process section — Load, Per-Client Score, Portfolio Dashboard, Intervention Recommendations, Thriving Capture.

4. **Write output:**
   - `Write` to `output/retention-check/{YYYY-MM-DD}-retention-report.md`
   - Structure per SKILL.md Output Format (portfolio dashboard + per-client scores + interventions + thriving capture + trending)
   - If any section fails cross-validation, mark `[GAP: section N]` and continue

5. **Update company.yaml:** `Edit` compartment 10 (lifecycle_optimization) — append health-score rubric + last-run date. Never overwrite existing values without confirmation.

6. **Post-ship:**
   - write `skills/retention-check/evidence/runs/{YYYY-MM-DD}-run.md` with phase log + confidence tags + client count + churn-risk distribution
   - Output next-skill recommendation (usually `/case-study` for Thriving clients)

## Arguments

If `$ARGUMENTS` includes `--period=<range>`, score over that period. Otherwise default to last 30 days.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for loading SKILL.md, company.yaml, reference/, CS SOP, CRM extracts
- **Write / Edit** for producing the report and updating compartment 10
- **Grep** across `company.yaml` to check current client roster + prior health scores

## Quality gates

Before writing the report to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification (formal 40% + semantic 35% + information-theoretic 25%)
- Check `spec/BANNED-VOCABULARY.md` — reject if any banned phrases
- Confirm every evidence_gate condition (health_score_rubric_defined, per_client_scored, churn_risk_classified, intervention_playbook_present)
- Signal Score ≥ 0.8
- No client scored from vibes — every score traces to signal source

## Failure handling

If skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode
- Attempt 2: surface the gap to creator with targeted question (often CRM signal data missing)
- If both fail: escalate to scale-head, log to `skills/retention-check/evidence/failure-modes.md`

## Cross-skill routing

After report ships:
- For each Thriving client, recommend `/case-study` (Level 5-6 social proof opportunity)
- If CS SOP gaps surface, recommend `/build-sop --variant=cs`
- For At-Risk clients, recommend `/email-sequence` (re-engagement)

---
*the slash-command adapter v1.0 — binds to skills/retention-check/SKILL.md*
