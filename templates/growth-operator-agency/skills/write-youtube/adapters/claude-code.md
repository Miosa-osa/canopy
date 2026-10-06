---
description: Produce a YouTube long-form script in one of 7 types (Educational / Vlog / Tutorial / Case Study / Listicle / Reaction / Interview) or VSSL. MODULE 4 architecture.
argument-hint: [optional: "--type=1-7|VSSL" to force; else select by pillar + stage]
allowed-tools: Read, Write, Edit, Grep, Glob, WebSearch
---

# /write-youtube — slash-command runtime Runtime Binding

Load and execute `skills/write-youtube/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/write-youtube/SKILL.md` (full body)
   - `Read` upstream: calendar brief from `output/content-calendar/`, `output/build-icp/`, `output/build-positioning/`, `output/design-offer/`, `output/extract-voice/`
   - read `reference/frameworks/youtube/` (7-video-types, hook library, VSSL, title/thumbnail, session starter, binge loop, algo-phase) + the content OS director / the VSL director / the short-form-frameworks author operator files

2. **Pre-flight check:** Verify `audience_intelligence_system >= 60`, `offer_architecture >= 50`, `copy_messaging >= 40` in `company.yaml`. Confirm calendar brief ID + pillar + conversion stage specified (prompt if standalone).

3. **Execute Phase 0 → Phase 11** per SKILL.md Process: Load → Video Type Selection (or honor `--type=N|VSSL`) → Pre-Script Content Brief (60-90 min strategic per MODULE 4 Section 1) → Title + Thumbnail Planning (Complementary Principle — two distinct messages) → Hook 0-15s (Specificity ≥ 8) → Intro Structure 15-75s (Social Proof / Audience Callout / Content Roadmap / Pre-handle+Tease) → Body (type-specific, Three-Part Formula per section: Re-Hook → Story → Lesson) → Loop Management (3-5 curiosity loops opened + closed by 80% mark) → Outro (Binge Loop for non-VSSL; direct CTA for VSSL) → Voice-Match Pass → Production Notes → Compliance + Metadata.

4. **Write output:**
   - `Write` to `output/write-youtube/{YYYY-MM-DD}-youtube-{brief-id}.md`
   - Structure per SKILL.md Output Format section — pre-script content brief + title/thumbnail + full script + loop management table + production notes + description/metadata + 4 appendices

5. **Update company.yaml:** No compartment writes; log artifact + repurpose chain in content_strategy.published_assets.

6. **Post-ship:**
   - write `skills/write-youtube/evidence/runs/{YYYY-MM-DD}-run.md` with video type rationale + title/thumbnail complementary check + loop map + voice-match audit
   - Output next-skill recommendations — repurpose chain: `/write-reel` (3 reels), `/write-linkedin-post` (1 post), `/write-x-thread` (1 thread), `/email-sequence` (1 broadcast), orchestrated by `/repurpose`

## Arguments

If `$ARGUMENTS` contains `--type=N|VSSL`, force that video type. Otherwise select from pillar+stage decision table (Tutorial/Educational for How-To Awareness; Case Study/VSSL for Case Study Decision; Reaction/Educational for Myth-Bust Consideration; Listicle/Reaction for Trend).

`$ARGUMENTS`

## Tool usage patterns

- **Read** for loading SKILL.md, calendar brief, all upstream Docs, MODULE 4 reference files
- **Write / Edit** for producing the script + metadata + description
- **WebSearch** for topical research + trend context (especially for Reaction / Listicle / Trend content) + SEO keyword research
- **Grep** across `output/build-icp/` for VOC pain language + `output/extract-voice/` for phrases_to_use placement

## Quality gates

Before writing the artifact to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification
- Check `spec/BANNED-VOCABULARY.md` — full sweep
- Truth Gate (30-second screenshot test per claim)
- No income guarantees, no health claims without backing, FTC disclosure if testimonials referenced
- Confirm every `evidence_gate` condition: video type with reasoning, content brief complete, hook+60s structure complete, body follows Three-Part Formula, 3-5 curiosity loops opened+closed, binge loop closed, title+thumbnail complementary (two distinct messages), voice-matched (3+ phrases per 5-min), length calibrated to audience sophistication
- Signal Score ≥ 0.8
- Blind Output Test 2/3 (external tier) scheduled before publish

## Failure handling

If the skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode (usually thin content brief or open curiosity loops at outro)
- Attempt 2: surface the gap to creator with a targeted question
- If both fail: escalate to marketing-head, log to `skills/write-youtube/evidence/failure-modes.md`

## Cross-skill routing

After the script ships:
- Repurpose chain orchestrated by `/repurpose`:
  - `/write-reel` — 3 reels from key moments
  - `/write-linkedin-post` — 1 post from primary insight
  - `/write-x-thread` — 1 thread from main lesson
  - `/email-sequence` — 1 broadcast linking to video
- Session-starter plan (Appendix D) — link 2-3 related creator videos at end screen for YouTube session time
- If VSSL: funnel CTA routes to `/build-funnel` archetype (usually Archetype 1 VSL or 4 Book-a-Call)
- Post-publish: CTR at 24h < 3% → thumbnail swap (Tacit Principle 4)

---
*the slash-command adapter v1.0 — binds to skills/write-youtube/SKILL.md*
