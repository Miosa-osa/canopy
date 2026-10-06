---
description: Produce a high-ticket sales script with 8-stage structure, 12+ inlined objection reframes, and 3 closing archetypes. R1 Founder-Led / R2 Setter+Closer / R3 Single Closer.
argument-hint: [optional: "--role=R1|R2|R3" to force; else auto-select from team_structure + offer tier]
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /sales-script — slash-command runtime Runtime Binding

Load and execute `skills/sales-script/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/sales-script/SKILL.md` (full body)
   - `Read` upstream: `output/design-offer/` (Offer Doc — gate-passed required), `output/build-positioning/`, `output/build-icp/`, `output/extract-voice/`, `output/objection-library/` if exists, `output/build-vsl/` if exists
   - read `reference/frameworks/sales/` (crossroads-close, value-stack-architecture) + `reference/frameworks/primitives/` (unique-mechanism, educate-before-pitch, call-funnel) + relevant operator files (sales-director, vsl-director, offer-architect, copy-director)

2. **Pre-flight check:** Verify `audience_intelligence_system >= 60`, `offer_architecture >= 70`, `conversion_sales_systems >= 50` in `company.yaml`. Confirm mechanism named (Positioning), 10+ objections in ICP Section 10, 15+ phrases_to_use in Brand Voice Doc. If any fails, HOLD with specific gap.

3. **Execute Phase 0 -> Phase 11** per SKILL.md Process: Role Archetype Selection -> Context Validation -> 8-Stage Outline -> Objection Reframes Inline -> Stage Copy Draft -> 3 Closes Draft -> Mechanism Thread Check -> Voice-Match Pass -> Compliance Check -> Role-Play Protocol -> Quality Gates -> Script Metadata Summary (LAST).

4. **Write output:**
   - `Write` to `output/sales-script/{YYYY-MM-DD}-sales-script-role-{R1|R2|R3}.md`
   - Structure per SKILL.md Output Format section — HEADER + Setter handoff (if R2) + 8-Stage closer flow + 12-objection table + 3-close decision tree + mechanism thread trace + compliance + 5 appendices
   - Mark `[GAP]` if any objection has no ICP Section 10 source or any mechanism sub-step is unspecified

5. **Update company.yaml:**
   - edit `company.yaml` Compartment 8 (conversion_sales_systems) to reference the shipped script path + role archetype + close-rate benchmark
   - Never overwrite existing script references without confirmation

6. **Post-ship:**
   - write `skills/sales-script/evidence/runs/{YYYY-MM-DD}-run.md` with role rationale + objection-coverage audit + mechanism thread trace + role-play schedule
   - Output next-skill recommendations (usually `/objection-library` for full library + `/call-prep` per-prospect briefing; `/post-booking-nurture` for post-close flow)

## Arguments

If `$ARGUMENTS` contains `--role=R1|R2|R3`, force that role archetype. Otherwise apply the Role Selection Decision Tree based on team_structure, offer tier, call volume signals.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for loading SKILL.md, all upstream Docs (Offer/Positioning/ICP/Voice/Objection Library), sales frameworks and operator files
- **Write / Edit** for producing the Sales Script (typically 3,500-6,500 words across 8 stages + objections + closes + appendices) and updating company.yaml
- **Grep** across `output/build-icp/` to pull Section 10 objection language verbatim + across `output/extract-voice/` to pull phrases_to_use placements

## Quality gates

Before writing the artifact to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification
- Check `spec/BANNED-VOCABULARY.md` — full regex sweep (INV-7)
- Truth Gate on every claim (INV-5) — 30-second screenshot test per cited result / testimonial / guarantee term / price
- No Fabrication (INV-6) — case studies real, numbers real, guarantee language real
- Confirm every `evidence_gate` condition: role selected with reasoning, all 8 stages complete, 12+ objections inlined, 3 closes present, mechanism threaded through Stage 4/5/6, voice-match verified, role-play 3/3 scheduled
- Signal Score >= 0.8
- Blind Output Test 3/3 (sacred-format sales-ops tier) scheduled before any live paid-traffic calls
- Brand safety: no income guarantees, no health claims without clinical backing

## Failure handling

If the skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode (usually mechanism threading gap or voice-match drift)
- Attempt 2: surface the gap to creator with a targeted question (e.g., "Only 8 objections in ICP Section 10 — need 4 more before script can ship")
- If both fail: escalate to sales-head, log to `skills/sales-script/evidence/failure-modes.md`

## Cross-skill routing

After the Sales Script ships (and passes role-play 3/3):
- Default next skill: `/objection-library` (full 20+ objection library for closer reference outside Stage 6 inlined set)
- Downstream: `/call-prep` (per-prospect 15-min briefing), `/proposal` (post-call written summary if prospect requests), `/post-booking-nurture` (pre-call show-rate optimization)
- Upstream if gap: `/build-icp` if objections <10, `/design-offer` if guarantee/price unclear, `/extract-voice` if phrases_to_use <15
- Weekly the operations director 8-stage audit on close rate (owned by sales-head)

---
*the slash-command adapter v1.0 — binds to skills/sales-script/SKILL.md*
