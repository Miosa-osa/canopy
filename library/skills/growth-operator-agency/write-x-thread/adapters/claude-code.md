---
description: Produce an X/Twitter thread in one of 7 types (Thread / Story / Hot Take / How-To / Listicle / Case Study / Daily Tweets). Specificity-first, 1-idea-per-tweet, final CTA.
argument-hint: [optional: --type=1-7]
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /write-x-thread — slash-command runtime Runtime Binding

Load and execute `skills/write-x-thread/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/write-x-thread/SKILL.md` (full body)
   - read `skills/write-x-thread/reference/` if present
   - `Read` upstream: `output/content-calendar/latest.md` for calendar brief
   - read `output/extract-voice/` for phrases_to_use + sentence rhythm

2. **Pre-flight check:** Verify `required_compartments` — audience_intelligence_system ≥ 50, offer_architecture ≥ 30, copy_messaging ≥ 30. If below, recommend upstream skills first.

3. **Execute Phase 0 → Phase 7** per SKILL.md Process:
   - Phase 0 Load → Phase 1 Thread Type Selection → Phase 2 Hook Tweet (3-5 variants, specificity ≥ 8) → Phase 3 Body Draft per type → Phase 4 Final CTA Tweet → Phase 5 Voice-Match + Compliance → Phase 6 Visual Decisions → Phase 7 Publishing Plan

4. **Write output:**
   - `Write` to `output/write-x-thread/{YYYY-MM-DD}-type{N}-{topic-slug}.md`
   - Structure per SKILL.md Output Format
   - Include hook variants, full thread, reply-to-thread, quote-tweet plan

5. **Post-ship:**
   - write `skills/write-x-thread/evidence/runs/{YYYY-MM-DD}-run.md`
   - Recommend next skill: `/write-linkedin-post` for cross-platform or `/email-sequence` for broadcast

## Arguments

If `$ARGUMENTS` contains `--type=1-7`, honor the selected thread type; otherwise apply decision logic from calendar brief pillar.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for SKILL.md, calendar brief, voice doc, positioning doc
- **Write / Edit** for thread artifact
- **Grep** `company.yaml` for Big Enemy / mechanism / core belief

## Quality gates

Before writing to `output/`:
- Thread type selected with reasoning
- Hook specificity ≥ 8 (evidence gate)
- Tweet count calibrated to type (7-12 standard, 3-5 hot take, etc.)
- Character limits respected (280 max per tweet, 180-280 ideal for body)
- Final CTA tweet — single action
- No external link in thread body (reply or last tweet only)
- Voice-matched (3+ phrases_to_use)
- Banned vocabulary clean
- Signal Score ≥ 0.8
- Blind Output Test 2/3 queued before promotion

## Failure handling

Per `workflows/handoffs/quality-revision.md`: auto-revise → surface gap → escalate to marketing-head, log to `skills/write-x-thread/evidence/failure-modes.md`.

## Cross-skill routing

- Repurpose chain: `/write-linkedin-post` (cross-platform), `/write-reel` (short-form version), `/email-sequence` (broadcast reference)
- On external-tier completion: Blind Output Test 2/3 queued

---
*the slash-command adapter v1.0 — binds to skills/write-x-thread/SKILL.md*
