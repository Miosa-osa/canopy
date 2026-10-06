---
description: Design a funnel architecture using one of 7 archetypes (VSL / Webinar / Application / Book-a-Call / Tripwire / Challenge / Community LM). 8-section blueprint with stage KPIs + tracking.
argument-hint: [optional: "--archetype=1-7" to force; else auto-select]
allowed-tools: Read, Write, Edit, Grep, Glob, WebSearch, WebFetch
---

# /build-funnel — slash-command runtime Runtime Binding

Load and execute `skills/build-funnel/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/build-funnel/SKILL.md` (full body)
   - `Read` upstream: `output/design-offer/` (Offer Doc — gate-passed required), `output/build-positioning/`, `output/build-icp/`, `output/build-vsl/` if exists
   - read `reference/frameworks/primitives/call-funnel.md`, `core-four.md`, `value-equation.md` + the growth engineer / the operations director / the paid media director / the VSL director operator files

2. **Pre-flight check:** Verify `audience_intelligence_system >= 60`, `offer_architecture >= 70`, `funnel_systems >= 10` in `company.yaml`. If Archetype 1/2 (VSL/Webinar) selected, confirm VSL exists at `output/build-vsl/`.

3. **Execute Phase 0 → Phase 9** per SKILL.md Process: Dependency Load → Archetype Selection → Traffic Source Strategy → Stage-by-Stage Architecture (5 stages) → Conversion Metrics Targets → Tracking & Attribution Plan → Dependency Chain → Economics Cross-Validation (LTV:CAC ≥ 3) → Leak-Check Audit Plan (the operations director 8-stage) → Funnel Summary (LAST).

4. **Write output:**
   - `Write` to `output/build-funnel/{YYYY-MM-DD}-funnel-blueprint-archetype-{1-7}.md`
   - Structure per SKILL.md Output Format section (8 sections + 4 appendices)
   - If economics cross-check fails, HOLD and reconcile against Offer Doc LTV:CAC

5. **Update company.yaml:**
   - edit `company.yaml` Compartment 4 (funnel_systems) to 70%+ with archetype + traffic mix + dependency status
   - Never overwrite existing values without confirmation

6. **Post-ship:**
   - write `skills/build-funnel/evidence/runs/{YYYY-MM-DD}-run.md` with archetype rationale + economics cross-check + dependency inventory
   - Output next-skill recommendations (usually `/ad-creative` or `/landing-page`; `/post-booking-nurture` + `/sales-script` for call funnels)

## Arguments

If `$ARGUMENTS` contains `--archetype=N`, force that archetype. Otherwise apply the Archetype Selection Decision Tree based on offer price, team capability, creator distribution mix.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for loading SKILL.md, all upstream Docs, funnel primitives, operator frameworks
- **Write / Edit** for producing the Funnel a longevity-protocol and updating company.yaml
- **WebSearch / WebFetch** for benchmark validation (industry-vertical conversion norms) + competitor funnel intelligence
- **Grep** across `output/` to inventory which dependency assets exist (VSL / landing page / email sequences / ad creative)

## Quality gates

Before writing the artifact to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification
- Check `spec/BANNED-VOCABULARY.md` — reject if any banned phrases
- Confirm every `evidence_gate` condition: archetype with reasoning, all 5 stages mapped, conversion metrics tabled, tracking plan specified, full dependency chain, economics validated against Offer Doc (LTV:CAC ≥ 3 per INV-4)
- Signal Score ≥ 0.8
- Blind Output Test 2/3 (external tier) scheduled before paid launch

## Failure handling

If the skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode (usually economics reconciliation or dependency gap)
- Attempt 2: surface the gap to creator with a targeted question ("VSL not ready — are we selecting Archetype 3 or waiting for VSL?")
- If both fail: escalate to sales-head, log to `skills/build-funnel/evidence/failure-modes.md`

## Cross-skill routing

After the Funnel a longevity-protocol ships:
- Default next skills by archetype:
  - Archetype 1 (VSL) → `/landing-page` + `/ad-creative`
  - Archetype 2 (Webinar) → `/webinar-script` + `/email-sequence`
  - Archetype 3-4 (Application / Book-a-Call) → `/post-booking-nurture` + `/sales-script` + `/application-form`
  - Archetype 5 (Tripwire) → `/email-sequence` for ascension + `/ad-creative`
  - Archetype 6 (Challenge) → `/email-sequence` for daily challenge + community infrastructure
  - Archetype 7 (Community LM) → `/content-calendar` + `/story-sequence` + DM setter SOP
- Wrap with `/plan-launch` when all dependencies queued
- Weekly the operations director 8-stage audit post-launch (owned by sales-head)

---
*the slash-command adapter v1.0 — binds to skills/build-funnel/SKILL.md*
