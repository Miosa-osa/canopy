---
description: Fix booked-to-show conversion on an application funnel. Ingests baseline metrics, outputs 4-intervention stack (SMS cadence / window tightening / quality filter / deposit). Target lift to 70%+ show rate.
argument-hint: [optional: current show rate as "43%" or "0.43", e.g. "/show-rate-surgery 43%"]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# /show-rate-surgery — slash-command runtime Runtime Binding

Load and execute `skills/show-rate-surgery/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - `skills/show-rate-surgery/SKILL.md` (full body)
   - `spec/BANNED-VOCABULARY.md` (filter for SMS/email copy)
   - `skills/show-rate-surgery/reference/` (if present)

2. **Pre-flight check:**
   - Verify `funnel_systems` compartment ≥ 40 AND `conversion_sales` compartment ≥ 40
   - Verify baseline show rate exists in `company.yaml` → `funnel_systems.active_funnels[*].conversion_metrics.current_cvr.book_to_show`
   - If `$ARGUMENTS` specifies a show rate, use that. Otherwise pull from `company.yaml`.
   - If baseline is missing entirely, emit a request for it and pause.

3. **Execute Phase 0 → Phase 6** per SKILL.md:
   - Phase 0: read state
   - Phase 1: diagnostic + $ impact calculation
   - Phase 2: intervention selection via decision tree
   - Phase 3: SMS + email cadence spec (voice-matched using `phrases_to_use`)
   - Phase 4: window + filter + deposit specs
   - Phase 5: measurement plan
   - Phase 6: handoff checklist

4. **Write output:**
   - `output/show-rate-surgery/{YYYY-MM-DD}-{client-slug}-playbook.md`
   - Use Output Format from SKILL.md (7 sections + metadata)
   - If SMS/email copy fails voice-match gate, mark `[VOICE: needs creator review]` and continue

5. **Update company.yaml:**
   - Set `funnel_systems.active_funnels[*].conversion_metrics.optimization_priorities` to include this playbook
   - Add milestone under `goals.initiatives[*].projects[*].milestones` if not already tracked
   - Never overwrite baseline metrics without explicit review confirmation

6. **Post-ship:**
   - Write `skills/show-rate-surgery/evidence/runs/{YYYY-MM-DD}-{client-slug}.md` with baseline, interventions deployed, forecast lift
   - Schedule Week 2 review in `PROJECT-STATE.md` log
   - Output next-skill recommendation (usually `/post-booking-nurture` for deeper email bodies, or `/sales-script` if close rate is also low)

## Arguments

If `$ARGUMENTS` is a percentage (e.g. `43%` or `0.43`), use it as the baseline show rate. Otherwise read from `company.yaml`.

`$ARGUMENTS`

## Tool usage patterns

- **Read** — SKILL.md, company.yaml, banned-vocab, creator's voice file if present
- **Write** — output playbook, evidence run log
- **Edit** — company.yaml optimization_priorities + goals
- **Grep** — pull `phrases_to_use` from company.yaml for voice-matched SMS
- **Bash** — run `.gitignore` check on output path if creator data sensitivity is a concern

## Quality gates

Before writing the playbook:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification
- Check `spec/BANNED-VOCABULARY.md` — SMS/email copy must pass
- Confirm every evidence_gate condition: baseline documented, target defined, cadence spec complete, window target set, filter criteria defined, deposit decision logged
- Signal Score ≥ 0.8
- $ impact of gap must be calculated numerically (not "significant")

## Failure handling

Follow `workflows/handoffs/quality-revision.md`:
- **Attempt 1**: auto-revise — usually missing baseline, solve by pulling from `company.yaml.foundations_status` or asking for raw booking data
- **Attempt 2**: surface gap to operator with specific data request ("need held-call count from last 30 days")
- **If both fail**: escalate to sales-head agent persona, log to `skills/show-rate-surgery/evidence/failure-modes.md`

## Cross-skill routing

After the playbook ships + operator confirms deployment:
- Feeds into `/post-booking-nurture` (for richer email sequences)
- Feeds into `/sales-script` (if close rate also needs work)
- Updates `/diagnose-conversion-gap` baseline (the loop closes: diagnostic → surgery → new diagnostic)
- Schedule Week 2 re-measurement — log delta in `PROJECT-STATE.md`

---
*the slash-command adapter v1.0 — binds to skills/show-rate-surgery/SKILL.md*
