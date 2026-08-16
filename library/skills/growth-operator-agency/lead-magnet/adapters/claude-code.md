---
description: Design a lead magnet in one of 9 types (Guide / Checklist / Cheat Sheet / Swipe File / Mini Course / Quiz / Calculator / Free Training / Custom). the acquisition economist a lead-generation canon. Opt-in target 30%+.
argument-hint: [optional: --type=1-9 or describe desired magnet]
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /lead-magnet — slash-command runtime Runtime Binding

Load and execute `skills/lead-magnet/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/lead-magnet/SKILL.md` (full body)
   - read `skills/lead-magnet/reference/` if present
   - `Read` upstream: `output/design-offer/latest.md` (mechanism + value stack), `output/build-icp/` (pain + desire + buying triggers), `output/build-positioning/` (Core Belief + Vehicle Switch)

2. **Pre-flight check:** Verify `required_compartments` — audience_intelligence_system ≥ 60, offer_architecture ≥ 50, copy_messaging ≥ 30.

3. **Execute Phase 0 → Phase 8** per SKILL.md Process:
   - Phase 0 Load → Phase 1 Type Selection → Phase 2 Hook + Title (specificity ≥ 8, 3-5 A/B variants) → Phase 3 Asset Outline (type-specific) → Phase 4 Bridge-to-Offer → Phase 5 Opt-in Copy → Phase 6 Delivery Automation Spec → Phase 7 Design Brief → Phase 8 Compliance

4. **Write output:**
   - `Write` to `output/lead-magnet/{YYYY-MM-DD}-{type}-{title-slug}.md`
   - Structure per SKILL.md Output Format — title variants, opt-in page copy, asset outline, bridge-to-offer, delivery automation spec, design brief

5. **Post-ship:**
   - write `skills/lead-magnet/evidence/runs/{YYYY-MM-DD}-run.md`
   - Recommend next skill: `/email-sequence` type 1 Welcome (triggered post-opt-in), `/landing-page`, `/ad-creative`

## Arguments

If `$ARGUMENTS` contains `--type=1-9`, honor type; otherwise apply ICP + offer decision table in SKILL.md.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for SKILL.md, offer mechanism, ICP pain/desire, positioning core belief
- **Write / Edit** for lead magnet brief + opt-in copy + asset outline + delivery spec
- **Grep** `company.yaml` for mechanism name + value-equation scores

## Quality gates

Before writing to `output/`:
- Type selected with reasoning (evidence gate)
- Value Equation Score ≥ 150 (Grand Slam for free) (evidence gate)
- Bridge-to-offer explicit (evidence gate)
- Specific outcome promised in title (specificity ≥ 8) (evidence gate)
- Delivery automation wired (ESP tag + 2-min delivery email + Welcome sequence trigger)
- Banned vocabulary clean
- Truth Gate on all claims
- Signal Score ≥ 0.8
- Blind Output Test 2/3 queued before traffic spend

## Failure handling

Per `workflows/handoffs/quality-revision.md`: auto-revise → surface gap → escalate to nurture-head, log to `skills/lead-magnet/evidence/failure-modes.md`.

## Cross-skill routing

- Downstream: `/email-sequence` type 1 Welcome (auto-triggered post-opt-in), `/landing-page` (opt-in page build), `/ad-creative` (traffic)
- On external-tier completion: Blind Output Test 2/3 queued before paid-traffic spend

---
*the slash-command adapter v1.0 — binds to skills/lead-magnet/SKILL.md*
