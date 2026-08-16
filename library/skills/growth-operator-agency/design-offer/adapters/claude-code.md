---
description: Design a high-ticket offer — Value Equation ≥150, LTV:CAC ≥3:1, 12-section Offer Document. Consumes ICP + Positioning. Cycle 1 hero skill.
argument-hint: [optional: offer name or price anchor]
allowed-tools: Read, Write, Edit, Grep, Glob, WebSearch, WebFetch
---

# /design-offer — slash-command runtime Runtime Binding

Load and execute `skills/design-offer/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/design-offer/SKILL.md` (full body)
   - `Read` upstream: `output/build-icp/` (ICP Completeness >= 80 required) + `output/build-positioning/` if exists
   - read `skills/design-offer/reference/` + value-equation / unique-mechanism / 8-required-beliefs primitives + the acquisition economist + the VSL director operator references

2. **Pre-flight check:** Verify `audience_intelligence_system >= 70`, `offer_architecture >= 20`, `creator_identity_matrix >= 40` in `company.yaml`. If ICP Document missing or Completeness < 80, BLOCK and route to `/build-icp`.

3. **Execute Phase 0 → Phase 12** per SKILL.md Process: Load Dependencies → Transformation Architecture → Unique Mechanism → Capability & Resource Removal → Value Stack → Bonus Stack (5+, objection-mapped) → Pricing Structure → Risk Reversal & Guarantee (ROI-positive) → Upsell Ecosystem → Economics Validation (LTV:CAC ≥ 3) → 8 Required Beliefs Installation Map → Confidence + Invariants Log → Offer Summary (LAST).

4. **Write output:**
   - `Write` to `output/design-offer/{YYYY-MM-DD}-offer-doc.md`
   - Structure per SKILL.md Output Format section (12 sections + 3 appendices)
   - If economics fail the 3:1 gate, HOLD with fix-path recommendations (raise price / reduce CAC / add continuity / add upsells)

5. **Update company.yaml:**
   - edit `company.yaml` to populate Compartment 3 (offer_architecture) — core_offer, mechanism_name, price, guarantee, bonuses, economics — to 70%+
   - Require creator sign-off on pricing + guarantee copy per governance (pricing_change requires board approval per INV-11)

6. **Post-ship:**
   - write `skills/design-offer/evidence/runs/{YYYY-MM-DD}-run.md` with Value Equation scoring + LTV:CAC math + confidence tags
   - Output next-skill recommendation (usually `/build-vsl`; `/extract-voice` in parallel if not done)

## Arguments

If `$ARGUMENTS` is provided, use it as the working offer name or price anchor. Otherwise design for the offer covered by the ICP Document.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for loading SKILL.md, company.yaml, ICP Document, Positioning Document, reference frameworks
- **Write / Edit** for producing the Offer Document and updating company.yaml
- **WebSearch / WebFetch** for competitor offer comparison (price, guarantee, bonuses, mechanism — Appendix C)
- **Grep** across `output/` to pull ICP Section 8 capability gaps, Section 10 objection library, Positioning Section 5 mechanism

## Quality gates

Before writing the artifact to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification
- Check `spec/BANNED-VOCABULARY.md` — reject "unlock," "supercharge," "transform" as verb, "revolutionary" et al
- Confirm every `evidence_gate` condition: all 12 sections, Value Equation ≥ 150, LTV:CAC ≥ 3, limiting belief aligned to transformation type, 5+ bonuses objection-mapped, ROI-positive guarantee
- Signal Score ≥ 0.8
- Creator sign-off on pricing + guarantee (INV-11)
- Blind Output Test 3/3 (sacred-format tier) scheduled before paid traffic

## Failure handling

If the skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode (usually economics fix-path or bonus re-mapping)
- Attempt 2: surface the gap to creator with a targeted question
- If both fail: escalate to foundations-head, log to `skills/design-offer/evidence/failure-modes.md`

## Cross-skill routing

After the Offer Document ships + passes gate:
- Default next skill: `/build-vsl` (VSL that opens with mechanism, closes with offer — Cycle 2 hero)
- Parallel: `/extract-voice` if not yet complete
- Downstream: `/build-funnel` for funnel architecture matched to offer type
- If Value Equation Score 50-150: recommend `/offer-repositioning` (v1.1) to tighten before shipping
- On sacred-format completion: ensure Blind Output Test 3/3 is queued before paid traffic

---
*the slash-command adapter v1.0 — binds to skills/design-offer/SKILL.md*
