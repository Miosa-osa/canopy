---
description: Produce a 1-page pre-call brief in 15 min — prospect-specific hooks, pain anchors, decision-style flag, identity match, objection pre-empts, tension-setting cues. 8 sections, scannable in 3 min.
argument-hint: [prospect name or application submission ID]
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /call-prep — slash-command runtime Runtime Binding

Load and execute `skills/call-prep/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/call-prep/SKILL.md` (full body)
   - `Read` upstream: `output/build-icp/` (Section 3 avatars + Section 10 objections), `output/design-offer/` (mechanism sub-steps), `output/build-positioning/`, `output/objection-library/` if exists
   - read the prospect's application form response (supplied as input, typically referenced in `$ARGUMENTS`)
   - read any prior DM / email / CRM note history if provided
   - read `reference/operators/sales-scripter.md`, `reference/operators/copy-director.md`, `reference/operators/copy-director.md` for diagnostic patterns

2. **Pre-flight check:** Verify `audience_intelligence_system >= 60`, `offer_architecture >= 60`, `conversion_sales_systems >= 50`. Confirm ICP has 3-5 avatar archetypes + Section 10 has 10+ objection patterns. If application form data is missing or thin, flag + request setter re-qualification.

3. **Execute Phase 0 -> Phase 8** per SKILL.md Process, respecting the 15-minute clock:
   - Minute 0-3: Application Signal Read
   - Minute 3-6: ICP Archetype Match + confidence flag
   - Minute 6-9: Decision-Style Diagnosis
   - Minute 9-12: Pain Anchors + Identity Match
   - Minute 12-14: Objection Pre-Empts (top 3)
   - Minute 14-15: Write the 1-page 8-section brief

4. **Write output:**
   - `Write` to `output/call-prep/{YYYY-MM-DD}-call-brief-{prospect-slug}.md`
   - Structure per SKILL.md Output Format — HEADER + 8 sections + post-call update flags
   - Enforce 1-page constraint (300-500 words target); if content exceeds, compress
   - Mark `[LOW CONFIDENCE]` if archetype match is uncertain

5. **Post-call update handoff:**
   - Append observations back into `output/build-icp/` Section 10 (new objection patterns)
   - Append observations into `output/objection-library/` (new reframes tested)
   - Append to case study pool if the call closes

6. **Log:**
   - write `skills/call-prep/evidence/runs/{YYYY-MM-DD}-run.md` with prep time logged + archetype confidence + observations

## Arguments

`$ARGUMENTS` expects the prospect identifier (name or application submission ID). The adapter pulls the application data keyed on that identifier.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for SKILL.md, ICP avatars, objection library, Offer Doc mechanism sub-steps, prospect application data
- **Write / Edit** for producing the 1-page brief (300-500 words) + appending post-call observations back into ICP + objection library + case study pool
- **Grep** across `output/build-icp/` for avatar archetype match + across `output/objection-library/` for top-3 objection reframes matching prospect signal

## Quality gates

Before writing the artifact to `output/`:
- Check `spec/BANNED-VOCABULARY.md` (INV-7)
- Truth Gate (INV-5) — pain quotes verbatim, no fabricated prospect signals
- No Fabrication (INV-6) — no invented decision-style markers
- Confirm every `evidence_gate` condition: archetype matched (+ confidence flag), 3+ pain anchors from application, decision-style flagged, 3 objection pre-empts, identity match stated, tension-setting cues present, 1-page scannable
- Signal Score >= 0.7 (internal tier, lower bar than external)
- Blind Output Test 1/3 (internal tier — 1 closer-evaluator sufficient)

## Failure handling

If prep inputs are missing (thin application, no prior DM history):
- Attempt 1: flag thin application + annotate brief with "Stage 1 extra qualifying question required"
- Attempt 2: surface the gap to sales-head — may require setter re-qualification before call runs
- If both fail: reschedule the call or move to lower-priority slot

## Cross-skill routing

After the Brief ships (per-call):
- **Pre-call:** closer reads brief 5 min before dial
- **On-call:** closer runs `/sales-script` with brief as side-reference + `/objection-library` for full objection handling
- **Post-call:** update ICP Section 10 (new objections) + objection library (new reframes) + case study pool (if close) + trigger `/proposal` (if prospect wants written summary) or `/post-booking-nurture` (if deferred to follow-up)
- **Quarterly pattern review:** aggregate closer observations -> `/build-icp` refresh

---
*the slash-command adapter v1.0 — binds to skills/call-prep/SKILL.md*
