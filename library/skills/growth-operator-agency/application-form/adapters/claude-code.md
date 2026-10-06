---
description: Produce a high-ticket qualifying application form — 8-12 Q for A1 founder calls, 6-8 Q for A2 setter screen, 4-5 Q for A3 flywheel. Disqualification logic + conditional branching + Call Brief signal handoff.
argument-hint: [optional: "--archetype=A1|A2|A3" to force; else auto-select from team_structure + offer tier]
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /application-form — slash-command runtime Runtime Binding

Load and execute `skills/application-form/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/application-form/SKILL.md` (full body)
   - `Read` upstream: `output/design-offer/` (offer tier + price), `output/build-funnel/` (funnel archetype #3 or #4), `output/build-icp/` (avatar archetypes + Section 10 objections), `output/extract-voice/` (phrases_to_use)
   - read `reference/frameworks/primitives/call-funnel.md` + relevant operator files (agency-director, sales-director, operations-director, paid-media-director)

2. **Pre-flight check:** Verify `audience_intelligence_system >= 60`, `offer_architecture >= 60`, `conversion_sales_systems >= 50`, `funnel_systems >= 10`. Confirm offer tier is clear (price + revenue-gating if applicable) and ICP has 3-5 avatar archetypes. If any fails, HOLD with specific gap.

3. **Execute Phase 0 -> Phase 10** per SKILL.md Process: Archetype Selection -> Context Validation -> Question Set Design -> Disqualification Logic Specification -> Conditional Branching Specification (A1/A2) -> Voice-Match Pass -> Confirmation + Calendar Flow -> Compliance Check -> Call Brief Signal Handoff -> Quality Gates -> Form Metadata Summary (LAST).

4. **Write output:**
   - `Write` to `output/application-form/{YYYY-MM-DD}-application-form-archetype-{A1|A2|A3}.md`
   - Structure per SKILL.md Output Format — HEADER + all questions (with Signal + DQ + branching metadata) + DQ logic + branching map + confirmation flow + Call Brief handoff map + 5 appendices
   - Mark `[GAP]` if any signal category is uncovered or any DQ path has no auto-responder copy

5. **Update company.yaml:**
   - edit `company.yaml` Compartment 8 (conversion_sales_systems.application_qualification) to reference the shipped form + archetype + target completion/show/close rates
   - edit Compartment 4 (funnel_systems) to bind form to funnel archetype

6. **Post-ship:**
   - write `skills/application-form/evidence/runs/{YYYY-MM-DD}-run.md` with archetype rationale + question-to-signal mapping + DQ logic audit
   - Output next-skill recommendations (usually `/post-booking-nurture` for calendar-confirmation sequence + `/call-prep` for per-prospect briefing; `/email-sequence` for DQ nurture flow)

## Arguments

If `$ARGUMENTS` contains `--archetype=A1|A2|A3`, force that archetype. Otherwise apply the Archetype Decision Tree based on offer tier + team_structure + funnel archetype.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for SKILL.md, Offer Doc, Funnel a longevity-protocol, ICP avatars, Brand Voice Doc
- **Write / Edit** for producing the form schema + DQ logic + branching + confirmation copy (typically 2,000-3,500 words across schema + 5 appendices) and updating company.yaml
- **Grep** across `output/build-icp/` for avatar archetype language + across `output/extract-voice/` for phrases_to_use

## Quality gates

Before writing the artifact:
- Check `spec/BANNED-VOCABULARY.md` (INV-7)
- Truth Gate (INV-5) — no fabricated revenue expectations, no income guarantees in form copy
- No Fabrication (INV-6) — no invented ICP archetypes or objection patterns
- Confirm every `evidence_gate` condition: archetype with reasoning, 8-12 Q (A1) or 6-8 (A2) or 4-5 (A3), all signals captured, DQ logic specified, show/close/refund calibrated, Call Brief signal captured, voice-match verified
- Signal Score >= 0.7 (external-tier)
- Blind Output Test 2/3 scheduled (external tier — 2 evaluators sufficient)
- Brand safety: no income guarantees, no revenue promises

## Failure handling

If quality gate fails:
- Attempt 1: auto-revise the failure mode (usually DQ logic gap or voice-match drift)
- Attempt 2: surface to creator (e.g., "ICP archetype avatars thin — need A2 archetype defined before form can branch on revenue stage")
- If both fail: escalate to sales-head, log to `skills/application-form/evidence/failure-modes.md`

## Cross-skill routing

After the Form ships:
- Calendar-confirmation -> `/post-booking-nurture` (6h / 1h / SMS reminder sequence)
- Per-call prep -> `/call-prep` (pulls 8 signals into Call Brief)
- DQ prospects -> `/email-sequence` (nurture sequence), `/lead-magnet` (tripwire offer for budget-DQ)
- Call runs -> `/sales-script` (closer reads with Call Brief fed by this form)
- Quarterly refresh triggered by completion/show/close rate drift

---
*the slash-command adapter v1.0 — binds to skills/application-form/SKILL.md*
