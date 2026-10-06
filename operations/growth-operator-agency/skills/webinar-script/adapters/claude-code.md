---
description: Produce a 7-Figure Webinar Script in one of 6 variants (Live / Evergreen / 3-Day / 5-Day / 7-Day Challenge / Workshop). 5-section structure. 8 beliefs installed. Crossroads close. Sacred format.
argument-hint: [optional: --variant=1-6]
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /webinar-script — slash-command runtime Runtime Binding

Load and execute `skills/webinar-script/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/webinar-script/SKILL.md` (full body)
   - read `skills/webinar-script/reference/` if present
   - `Read` upstream: `output/design-offer/latest.md` (value stack, bonuses, guarantee, mechanism), `output/build-icp/` (objections, VOC, limiting belief), `output/build-positioning/` (core belief, Big Enemy), `output/extract-voice/`

2. **Pre-flight check:** Verify `required_compartments` — audience_intelligence_system ≥ 70, offer_architecture ≥ 70, copy_messaging ≥ 50, education_nurture ≥ 30. This is a sacred skill — thresholds are strict.

3. **Execute Phase 0 → Phase 9** per SKILL.md Process:
   - Phase 0 Load → Phase 1 Variant Selection (1 Live / 2 Evergreen / 3 3-Day / 4 5-Day / 5 7-Day / 6 Workshop) → Phase 2 Section 1 Intro (15-30 min) → Phase 3 Section 2 Content (45-60 min, teach WHAT not HOW) → Phase 4 Section 3 Transition (Crossroads Close) → Phase 5 Section 4 Pitch (5+ bonuses, 2nd-best first, best last) → Phase 6 Section 5 Q&A (scripted objection destruction) → Phase 7 Challenge Variants (if 3/4/5) → Phase 8 Voice-Match + Compliance → Phase 9 Production Notes

4. **Write output:**
   - `Write` to `output/webinar-script/{YYYY-MM-DD}-variant{N}-{title-slug}.md`
   - Structure per SKILL.md Output Format — 5 sections with time targets, 8 Beliefs Installation Map, Bonus → Objection Map, Isomorphic Case Studies, Production Notes

5. **Post-ship:**
   - write `skills/webinar-script/evidence/runs/{YYYY-MM-DD}-run.md`
   - Recommend next skill: `/email-sequence` type 4 Webinar (promo sequence), `/post-booking-nurture` (if routes to calls), `/write-linkedin-post` (invite content)

## Arguments

If `$ARGUMENTS` contains `--variant=1-6`, honor variant; otherwise apply decision tree (offer price + creator delivery capacity + launch window).

`$ARGUMENTS`

## Tool usage patterns

- **Read** for SKILL.md, offer doc, ICP objection library, positioning core belief + Big Enemy, voice doc, 8-required-beliefs reference
- **Write / Edit** for 5-section script + production notes + appendices
- **Grep** `company.yaml` for isomorphic case studies + testimonial types

## Quality gates

Before writing to `output/`:
- Variant selected with reasoning (evidence gate)
- 5-section structure complete with time targets (evidence gate)
- 8 Required Beliefs installation map complete (evidence gate)
- 10+ objections handled in Q&A (evidence gate)
- Bonus stack 5+ with each countering a specific objection (evidence gate)
- Crossroads Close present verbatim (evidence gate)
- Isomorphic case studies 3+ (evidence gate)
- Voice-matched (3+ phrases per section)
- No income guarantees / no fabricated results / no "this isn't selling you"
- Banned vocabulary clean
- Signal Score ≥ 0.8
- **Blind Output Test 3/3 required before live delivery to paid registrants** (sacred gate)

## Failure handling

Per `workflows/handoffs/quality-revision.md`: auto-revise → surface gap → escalate to nurture-head, log to `skills/webinar-script/evidence/failure-modes.md`. If 8-beliefs map incomplete, block shipping.

## Cross-skill routing

- Upstream: requires `/design-offer` complete (bonuses, guarantee, mechanism locked)
- Downstream: `/email-sequence` type 4 Webinar (promo), `/post-booking-nurture` (if call-routing variant), `/write-linkedin-post` + `/write-x-thread` (invite content), `/ad-creative` (paid traffic to reg page)
- **On sacred-format completion: 3/3 Blind Output Test required before any paid-registrant delivery**

---
*the slash-command adapter v1.0 — binds to skills/webinar-script/SKILL.md. Sacred format — 3/3 Blind Output Test mandatory.*
