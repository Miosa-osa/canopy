---
description: Produce a VSL script using one of 5 variants (15-step / pull-push-persuade 11-step / 13-step VSL / three-phase VSL formula / hidden-pitch long-form video). Voice-matched, mechanism-threaded, 8 beliefs installed.
argument-hint: [optional: "--variant=A|B|C|D|E" to force variant; else auto-select]
allowed-tools: Read, Write, Edit, Grep, Glob, WebSearch, WebFetch
---

# /build-vsl — slash-command runtime Runtime Binding

Load and execute `skills/build-vsl/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/build-vsl/SKILL.md` (full body)
   - `Read` upstream: `output/design-offer/` (Offer Doc — gate-passed required), `output/build-positioning/`, `output/build-icp/`, `output/extract-voice/`
   - read `reference/frameworks/vsl/` (all 5 variant files) + the VSL director/the psychological copywriter/the 13-step VSL author/the VSL copywriter/the growth engineer operator files + 8-required-beliefs + crossroads-close + value-stack-architecture

2. **Pre-flight check:** Verify `audience_intelligence_system >= 60`, `offer_architecture >= 70`, `copy_messaging >= 40` in `company.yaml`. Confirm mechanism named (Positioning), 5+ isomorphic case studies available, 15+ phrases_to_use (Brand Voice Doc). If any fails, HOLD with specific gap.

3. **Execute Phase 0 → Phase 12** per SKILL.md Process: Variant Selection → Context Validation → Variant-Specific Outline → 8 Beliefs Installation Map → Write Body Draft → Voice-Match Pass → Mechanism Thread Check → Case Study Selection (isomorphic) → Compliance Check → Runtime Calibration → Production Notes → Quality Gates → VSL Metadata Summary (LAST).

4. **Write output:**
   - `Write` to `output/build-vsl/{YYYY-MM-DD}-vsl-script-variant-{A|B|C|D|E}.md`
   - Structure per SKILL.md Output Format section — HEADER + variant-specific BODY (beat-by-beat with SPEAKER/SCREEN cues) + FOOTER + 5 appendices
   - Mark `[GAP]` if any belief not installable given current offer structure

5. **Update company.yaml:**
   - edit `company.yaml` Compartment 5 (copy_messaging) to reference the shipped VSL script path + variant selected
   - Never overwrite existing VSL references without confirmation

6. **Post-ship:**
   - write `skills/build-vsl/evidence/runs/{YYYY-MM-DD}-run.md` with variant rationale + voice-match audit + mechanism thread trace
   - Output next-skill recommendation (usually `/build-funnel` if funnel incomplete, else `/ad-creative` for traffic)

## Arguments

If `$ARGUMENTS` contains `--variant=A|B|C|D|E`, force that variant. Otherwise apply the Variant Selection Decision Tree based on offer price, creator on-camera, traffic source, niche emotionality.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for loading SKILL.md, all upstream Docs (Offer/Positioning/ICP/Voice), variant reference frameworks
- **Write / Edit** for producing the VSL Script (typically 1,500-6,000 words depending on variant) and updating company.yaml
- **WebSearch / WebFetch** for competitor VSL intelligence if needed (Truth Gate support, isomorphic case ranking)
- **Grep** across `output/` for existing case studies, phrases_to_use instances, mechanism sub-steps

## Quality gates

Before writing the artifact to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification
- Check `spec/BANNED-VOCABULARY.md` — full regex sweep (INV-7)
- Truth Gate on every claim (INV-5) — 30-second screenshot test
- No Fabrication (INV-6) — no invented case studies, numbers, or testimonials
- Confirm every `evidence_gate` condition: variant with reasoning, all beats complete, 8 beliefs installed, mechanism threaded through 5 key beats, voice-match verified, Crossroads Close (or equivalent) present
- Signal Score ≥ 0.8
- Blind Output Test 3/3 (sacred-format tier) scheduled before paid traffic
- Brand safety: no income guarantees, no health claims without clinical backing, FTC disclosure if testimonials

## Failure handling

If the skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode (usually voice-match or mechanism thread gaps)
- Attempt 2: surface the gap to creator with a targeted question
- If both fail: escalate to sales-head, log to `skills/build-vsl/evidence/failure-modes.md`

## Cross-skill routing

After the VSL Script ships (and passes Blind Test 3/3):
- Default next skill: `/build-funnel` (wrap VSL in correct funnel archetype)
- Downstream: `/landing-page` (opt-in page that sends to VSL), `/ad-creative` (paid creative targeted to VSL), `/call-prep` (closer prep for VSL-viewer inbound bookings)
- If conversion benchmark missed after 500+ qualified views: iterate Problem framing / mechanism specificity / Price Anchoring
- On sacred-format completion: Blind Output Test 3/3 REQUIRED before any paid traffic spend

---
*the slash-command adapter v1.0 — binds to skills/build-vsl/SKILL.md*
