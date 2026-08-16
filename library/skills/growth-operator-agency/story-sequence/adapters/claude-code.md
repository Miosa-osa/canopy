---
description: Produce a 7-day IG Story sequence using the stories director's 7-framework rotation + 4-layer anatomy. 2-4 stories/day. Orange/grey 4+3 balance.
argument-hint: [optional: weekly theme hint]
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /story-sequence — slash-command runtime Runtime Binding

Load and execute `skills/story-sequence/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/story-sequence/SKILL.md` (full body)
   - read `skills/story-sequence/reference/` if present
   - `Read` upstream: `output/content-calendar/latest.md`, `output/build-icp/` (Section 10 Objection Library), `output/design-offer/` (Social Proof), `output/extract-voice/`

2. **Pre-flight check:** Verify `required_compartments` — audience_intelligence_system ≥ 50, offer_architecture ≥ 40, copy_messaging ≥ 30, content_strategy ≥ 20. Specifically: ICP objection library must be populated (Day 3 depends on it).

3. **Execute Phase 0 → Phase 6** per SKILL.md Process:
   - Phase 0 Load → Phase 1 Weekly Topic Thread → Phase 2 Day-by-Day Planning (7 frameworks, never repeat 2 days) → Phase 3 Visual Asset Brief (4-layer anatomy per slide) → Phase 4 Orange/Grey Balance Check (4+3) → Phase 5 Voice-Match + Compliance → Phase 6 Publishing Plan

4. **Write output:**
   - `Write` to `output/story-sequence/{YYYY-MM-DD}-week-{N}-stories.md`
   - Structure per SKILL.md Output Format — 7 days, 2-4 stories each, 4-layer anatomy per story, Highlights save plan, Close Friends variant if applicable

5. **Post-ship:**
   - write `skills/story-sequence/evidence/runs/{YYYY-MM-DD}-run.md`
   - Recommend next skill: `/write-reel` (weekly highlights reel), `/email-sequence` (broadcast referencing stories), or `/content-calendar` (next week)

## Arguments

If `$ARGUMENTS` is provided, use as weekly connective theme. Otherwise pull from calendar brief.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for SKILL.md, ICP Section 10, offer social proof, voice doc
- **Write / Edit** for 7-day sequence artifact + shot list
- **Grep** `company.yaml` for client proof + testimonials

## Quality gates

Before writing to `output/`:
- 7 daily frameworks executed, never repeat 2 days in a row
- 4-layer anatomy per story (text + image + proof-screenshot + visual)
- No blank backgrounds (evidence gate)
- 4 orange + 3 grey days balanced (evidence gate)
- Day 3 objection pulled from ICP Section 10 Objection Library
- Day 5 + Day 7 grey days humanize
- Voice-matched across week (3+ phrases_to_use)
- Banned vocabulary clean
- Signal Score ≥ 0.8
- Blind Output Test 2/3 queued

## Failure handling

Per `workflows/handoffs/quality-revision.md`: auto-revise → surface gap → escalate to marketing-head, log to `skills/story-sequence/evidence/failure-modes.md`.

## Cross-skill routing

- Repurpose: `/write-reel` (weekly highlights), `/email-sequence` (broadcast)
- On external-tier completion: Blind Output Test 2/3 queued before CF publishing

---
*the slash-command adapter v1.0 — binds to skills/story-sequence/SKILL.md*
