---
description: Produce a LinkedIn post promoting the operator's own offer (INV-8 scope). Hook-Loop-CTA + 30/50/20 pillar split + Knowledge Graph optimization. 3-4/week cadence.
argument-hint: [optional: --type=value-bomb|lead-magnet|case-study|authority|engagement|offer-tied]
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /write-linkedin-post — slash-command runtime Runtime Binding

Load and execute `skills/write-linkedin-post/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/write-linkedin-post/SKILL.md` (full body)
   - read `skills/write-linkedin-post/reference/` if present
   - `Read` upstream: `output/content-calendar/latest.md` for calendar brief
   - read `output/extract-voice/`, `output/build-positioning/`, `output/design-offer/` as relevant

2. **Pre-flight check:** Verify `required_compartments` — audience_intelligence_system ≥ 60, offer_architecture ≥ 40, copy_messaging ≥ 30, content_strategy ≥ 20. INV-8 scope guard: confirm this is creator-promoting-own-offer, NOT full LinkedIn agency content.

3. **Execute Phase 0 → Phase 9** per SKILL.md Process:
   - Phase 0 Load → Phase 1 Post Type Selection → Phase 2 Hook Writing (140 chars) → Phase 3 Body per post type → Phase 4 Knowledge Graph Optimization → Phase 5 Voice-Match → Phase 6 Visual Decision → Phase 7 CTA + Link Handling → Phase 8 Compliance → Phase 9 Publishing Plan

4. **Write output:**
   - `Write` to `output/write-linkedin-post/{YYYY-MM-DD}-{post-type}-{topic-slug}.md`
   - Structure per SKILL.md Output Format section
   - Include primary hook + 2 alts, full post, first-comment plan, reply-to-own plan

5. **Post-ship:**
   - write `skills/write-linkedin-post/evidence/runs/{YYYY-MM-DD}-run.md` with phase log
   - Output next-skill recommendation (usually `/write-x-thread` or `/email-sequence` for repurpose)

## Arguments

If `$ARGUMENTS` contains `--type=...`, honor the post type selection; otherwise apply the decision table from SKILL.md against the calendar brief pillar.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for SKILL.md, calendar brief, voice doc, positioning doc, offer doc
- **Write / Edit** for producing the post artifact
- **Grep** across `company.yaml` for Big Enemy / Core Belief / mechanism name

## Quality gates

Before writing to `output/`:
- Hook specificity ≥ 8 (evidence gate)
- Character count in range (1300-2200 for text post, 140 max hook)
- Hook-Loop-CTA structure present
- No external link in post body (link in first comment only)
- Voice-matched (3+ phrases_to_use)
- Banned vocabulary check (`spec/BANNED-VOCABULARY.md`) — reject if any leak
- Signal Score ≥ 0.8
- Blind Output Test 2/3 queued before production publishing

## Failure handling

Per `workflows/handoffs/quality-revision.md`: auto-revise → surface gap → escalate to marketing-head, log to `skills/write-linkedin-post/evidence/failure-modes.md`.

## Cross-skill routing

- Repurpose chain: `/write-x-thread` (expanded thesis), `/write-reel` (short-form), `/email-sequence` (broadcast reference)
- If Lead Magnet type: `/dm-sequence` for comment-to-DM setter flow
- On external-tier completion: ensure Blind Output Test 2/3 queued

---
*the slash-command adapter v1.0 — binds to skills/write-linkedin-post/SKILL.md*
