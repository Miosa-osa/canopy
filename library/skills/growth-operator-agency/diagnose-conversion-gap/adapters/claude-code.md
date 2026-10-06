---
description: Funnel teardown — ingest past-launch data, surface biggest $ leak, triangulate root cause via 40/40/20, rank fixes by ROI, recommend next skill. First-pass audit before asset work.
argument-hint: [optional: path to funnel-data file (CSV / md), else pulls from company.yaml + _private/{client}/]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# /diagnose-conversion-gap — slash-command runtime Runtime Binding

Load and execute `skills/diagnose-conversion-gap/SKILL.md`.

## Runtime behavior

1. **Read context:**
   - `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - `skills/diagnose-conversion-gap/SKILL.md` (full body)
   - `spec/BANNED-VOCABULARY.md`
   - `_private/{client}/` for prior diagnostics, raw data, extracts
   - `reference/frameworks/primitives/` for benchmark reference

2. **Pre-flight check:**
   - Verify funnel_systems ≥ 30 AND conversion_sales ≥ 30
   - Verify at least one active funnel in `company.yaml.funnel_systems.active_funnels[]`
   - Verify ≥ 30 days of data OR ≥ 50 booked calls historically. If not, block with specific ask.
   - If `$ARGUMENTS` is a file path, read it. Else pull from `company.yaml` + `_private/{client}/`.

3. **Execute Phase 0 → Phase 6** per SKILL.md:
   - Phase 0: data intake
   - Phase 1: funnel table with CVR + benchmarks
   - Phase 2: leak waterfall with $ impact per stage
   - Phase 3: 40/40/20 root-cause triangulation
   - Phase 4: rank fixes by ROI
   - Phase 5: measurement plan
   - Phase 6: write output

4. **Write output:**
   - `output/diagnose-conversion-gap/{YYYY-MM-DD}-{client-slug}.md` (6-section diagnostic)
   - `_private/{client}/diagnostics/{YYYY-MM-DD}.md` (long-term reference)
   - Log the Recommended Next Skill as a new task via TaskCreate

5. **Update company.yaml:**
   - Set `lifecycle_optimization.metrics_dashboard.optimization_priorities` to ranked fix list
   - Update `funnel_systems.active_funnels[*].conversion_metrics.optimization_priorities`
   - Log this diagnostic run in `fill_log`

6. **Post-ship:**
   - Write `skills/diagnose-conversion-gap/evidence/runs/{YYYY-MM-DD}-{client-slug}.md` with data confidence + fix ranking
   - Schedule 14-21 day re-run trigger in `PROJECT-STATE.md` log
   - Output next-skill recommendation

## Arguments

If `$ARGUMENTS` is a file path (CSV / md / json), treat it as the funnel data source. Else pull from `company.yaml` + `_private/{client}/`.

`$ARGUMENTS`

## Tool usage patterns

- **Read** — SKILL.md, company.yaml, funnel data files, prior diagnostics
- **Write** — 6-section diagnostic output, private diagnostics archive, evidence run log
- **Edit** — company.yaml optimization_priorities updates
- **Grep** — pull current_cvr values from company.yaml funnels
- **Bash** — basic CSV parsing for raw funnel data if needed (jq / awk-equivalent); file existence checks

## Quality gates

Before writing the diagnostic:
- All 6 sections populated
- Funnel table has zero TBD entries
- Dollar impacts are computed (formula shown)
- Recommended Next Skill is a valid slug from `skills/_INDEX.md`
- Confidence rating (HIGH / MEDIUM / LOW) is honest
- If data is partial, explicit `[CONFIDENCE: LOW — ask for X]` markers included
- Signal Score ≥ 0.8
- Banned-vocabulary filter passed

## Failure handling

Follow `workflows/handoffs/quality-revision.md`:
- **Attempt 1**: auto-revise — usually data gap, ask for specific field
- **Attempt 2**: produce degraded-mode diagnostic with LOW confidence flag
- **If both fail**: escalate to sales-head + growth-ceo, log to `skills/diagnose-conversion-gap/evidence/failure-modes.md`

## Cross-skill routing

- **Downstream (most common):**
  - Show rate leak → auto-suggest `/show-rate-surgery`
  - Audience mismatch → `/build-icp` or `/research`
  - Offer weakness → `/design-offer`
  - Copy weakness → `/build-vsl`, `/ad-creative`, `/landing-page`
  - Top-of-funnel hook weakness → `/write-reel`, `/ig-stories-drop`
- **Debrief loop:** after fix ships, re-run in 14-21 days to measure lift. This skill is the closing bracket on every conversion-optimization cycle.
- **First-pass audit:** run this as Day 1 skill on every new client engagement.

---
*the slash-command adapter v1.0 — binds to skills/diagnose-conversion-gap/SKILL.md*
