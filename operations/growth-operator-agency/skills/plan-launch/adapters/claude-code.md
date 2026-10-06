---
description: Plan a launch in one of 5 variants (Live / Evergreen / Rolling / Flash / Beta) using Growth Operating Agency 5-phase SOP. Produces dated runbook with KPIs, team assignments, tech checklist. Sacred format.
argument-hint: [optional: --variant=1-5 | launch window date range]
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /plan-launch — slash-command runtime Runtime Binding

Load and execute `skills/plan-launch/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/plan-launch/SKILL.md` (full body)
   - read `skills/plan-launch/reference/` if present
   - `Read` ALL upstream: `output/design-offer/`, `output/build-funnel/`, `output/build-vsl/`, `output/content-calendar/`, `output/email-sequence/`, `output/ad-creative/`, `output/post-booking-nurture/`

2. **Pre-flight check:** Verify `required_compartments` — audience_intelligence_system ≥ 60, offer_architecture ≥ 70, funnel_systems ≥ 60, content_strategy ≥ 40. Sacred skill — thresholds strict. All upstream assets must exist or be flagged as gaps.

3. **Execute Phase 0 → Phase 7** per SKILL.md Process:
   - Phase 0 Load (all upstream assets) → Phase 1 Variant Selection (1 Live / 2 Evergreen / 3 Rolling / 4 Flash / 5 Beta) → Phase 2 Phase-by-Phase Runbook (5 phases × daily tasks) → Phase 3 Asset Dependency Check (VSL? landing page? emails wired? ads approved? pixel installed?) → Phase 4 Team Assignments (owner per task + deadline) → Phase 5 Tech Checklist (pixel + CAPI + tracking + integrations) → Phase 6 KPI Targets (opt-ins/day, sales/day, launch total, LTV:CAC) → Phase 7 Analyze Plan (daily metric review + optimization protocol)

4. **Write output:**
   - `Write` to `output/plan-launch/{YYYY-MM-DD}-variant{N}-{offer-slug}-launch-plan.md`
   - Structure per SKILL.md Output Format — 5 phases × daily runbook, dependency check, team grid, tech checklist, KPI targets

5. **Post-ship:**
   - write `skills/plan-launch/evidence/runs/{YYYY-MM-DD}-run.md`
   - Recommend next skill: `/launch-report` (post-launch analysis after window closes)

## Arguments

If `$ARGUMENTS` contains `--variant=1-5` or launch dates, honor; otherwise derive from offer readiness + audience state + timing.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for SKILL.md + ALL upstream outputs (offer, funnel, VSL, content calendar, emails, ads, show-rate stack)
- **Write / Edit** for dated runbook + team grid + tech checklist + KPI targets
- **Grep** `company.yaml` for team roles + integration credentials + historical launch metrics (if Cycle 6 revisit)

## Quality gates

Before writing to `output/`:
- Variant selected with reasoning (evidence gate)
- All 5 phases mapped with daily tasks (evidence gate)
- Asset dependency check listed (every upstream output cited or flagged) (evidence gate)
- Team assignments complete (owner per task + deadline) (evidence gate)
- Tech checklist passed (pixel + CAPI + tracking + integrations verified) (evidence gate)
- KPI targets set with specific numbers (evidence gate)
- Signal Score ≥ 0.8
- **Blind Output Test 3/3 required before launch day** (sacred gate)
- Banned vocabulary clean

## Failure handling

Per `workflows/handoffs/quality-revision.md`: auto-revise → surface gap → escalate to launch-head, log to `skills/plan-launch/evidence/failure-modes.md`. If pixel/CAPI unverified, block launch day. If any upstream asset missing, block plan from production use.

## Cross-skill routing

- Upstream dependency chain: requires `/design-offer` + `/build-funnel` + `/build-vsl` + `/content-calendar` + `/email-sequence` + `/ad-creative` + `/post-booking-nurture` all complete
- Downstream: `/launch-report` (post-launch), revisit `/build-funnel` / `/ad-creative` / `/email-sequence` per leak diagnosis
- **On sacred-format completion: 3/3 Blind Output Test required before paid-traffic spend on launch window**

---
*the slash-command adapter v1.0 — binds to skills/plan-launch/SKILL.md. Sacred format — 3/3 Blind Output Test mandatory.*
