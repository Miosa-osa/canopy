---
description: Produce a 20+ objection library across 6 categories (money/timing/trust/spouse/format/past-failure) with 3-layer reframes, proof stacks, and escalation scripts. Feeds /sales-script Stage 6 + /call-prep + /proposal FAQ.
argument-hint: [optional: "--min=20" to force minimum count; "--refresh" to refresh existing library]
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /objection-library — slash-command runtime Runtime Binding

Load and execute `skills/objection-library/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/objection-library/SKILL.md` (full body)
   - `Read` upstream: `output/build-icp/` (Section 10 Objections required — 10+ entries), `output/design-offer/` (guarantee + bonuses), `output/build-positioning/`, `output/extract-voice/`
   - read `reference/frameworks/sales/` (value-stack-architecture, crossroads-close) + relevant operator files (copy-director, offer-architect, sales-director)
   - read `reference/sub-agents/sales-conversations/examples/` for case study pool

2. **Pre-flight check:** Verify `audience_intelligence_system >= 60`, `offer_architecture >= 70`, `copy_messaging >= 40` in `company.yaml`. Confirm ICP Section 10 has 10+ objection patterns in `voice_of_customer.objection_patterns`. Confirm 5+ real case studies available. If any fails, HOLD with specific gap.

3. **Execute Phase 0 -> Phase 11** per SKILL.md Process: Context Load -> Context Validation -> Objection Inventory (6-category coverage) -> 3-Layer Reframe Drafting -> Proof Stack Assignment -> Escalation Script Drafting -> Role-Play Scenario Generation -> Voice-Match Pass -> Compliance Check -> Cross-Reference with /sales-script -> Quality Gates -> Library Summary (LAST).

4. **Write output:**
   - `Write` to `output/objection-library/{YYYY-MM-DD}-objection-library.md`
   - Structure per SKILL.md Output Format — HEADER + 6 category sections (26 objections default) + inline priority set table + proof stack audit + 20 role-play scenarios + compliance + 5 appendices
   - Mark `[PROOF GAP — capture required]` for any objection that needs an isomorphic case study but none exists

5. **Update company.yaml:**
   - edit `company.yaml` Compartment 5 (copy_messaging.objection_handling_library) with full library reference + top-12 inline priority set + last-refresh date
   - Never overwrite existing library entries without confirmation — append new, update changed

6. **Post-ship:**
   - write `skills/objection-library/evidence/runs/{YYYY-MM-DD}-run.md` with category coverage stats + ICP Section 10 cross-reference + proof stack coverage audit
   - Output next-skill recommendations (usually `/sales-script` to inline top 12 + `/call-prep` for per-prospect pre-empts; `/landing-page` FAQ update)

## Arguments

If `$ARGUMENTS` contains `--min=N`, force minimum objection count. If `--refresh`, update existing library with new call-note patterns rather than full rebuild.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for SKILL.md, ICP Section 10, Offer Doc guarantee + bonuses, case study pool, operator files
- **Write / Edit** for producing the library (typically 5,000-8,000 words across 26 objections + role-plays + appendices) and updating company.yaml
- **Grep** across `output/build-icp/` for Section 10 voice_of_customer.objection_patterns + across `reference/sub-agents/sales-conversations/` for case study isomorphic matches

## Quality gates

Before writing the artifact to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification
- Check `spec/BANNED-VOCABULARY.md` — full regex sweep (INV-7)
- Truth Gate on every cited case study / number / guarantee term (INV-5)
- No Fabrication (INV-6) — every case study real, every number sourced
- Confirm every `evidence_gate` condition: 20+ objections, 6 categories covered, 3-layer reframe per objection, proof stack per objection, escalation script per objection, ICP Section 10 sourced, voice-match verified
- Signal Score >= 0.8
- Blind Output Test 3/3 (sacred-format sales-ops tier) scheduled before closer training
- Brand safety: no income guarantees, no health claims without clinical backing, FTC disclosure for testimonials

## Failure handling

If the skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode (usually isomorphic case study gap or voice-match drift)
- Attempt 2: surface the gap to creator (e.g., "3 objections have no isomorphic case study in the pool — need either case study capture or category prune")
- If both fail: escalate to sales-head, log to `skills/objection-library/evidence/failure-modes.md`

## Cross-skill routing

After the Library ships:
- Primary downstream: `/sales-script` (inline top 12 objections into Stage 6)
- Secondary downstream: `/call-prep` (per-prospect pre-empts from the library), `/proposal` (FAQ section uses top-5 reframes), `/landing-page` (FAQ pre-framing for opt-in / sales page)
- Upstream if gap: `/build-icp` refresh if Section 10 <10 entries; `/design-offer` if guarantee / bonus architecture doesn't match objection countering
- Quarterly refresh triggered by new call-note patterns (owned by sales-head)

---
*the slash-command adapter v1.0 — binds to skills/objection-library/SKILL.md*
