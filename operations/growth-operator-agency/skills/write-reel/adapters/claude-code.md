---
description: Produce a short-form script (IG Reel / TikTok / YT Shorts) using one of 10 short-form frameworks. Second-by-second timing grid, voice-matched, platform adaptations.
argument-hint: [optional: "--framework=1-10" to force; else select by pillar + stage]
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /write-reel — slash-command runtime Runtime Binding

Load and execute `skills/write-reel/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/write-reel/SKILL.md` (full body)
   - `Read` upstream: calendar brief from `output/content-calendar/` (identifies which slot this reel fills), `output/extract-voice/` (phrases_to_use), `output/build-positioning/` (mechanism thread)
   - read `reference/frameworks/youtube/hook-library-20-formulas.md`, `reference/operators/content-os-director.md` (10 frameworks)

2. **Pre-flight check:** Verify `audience_intelligence_system >= 60`, `offer_architecture >= 40`, `copy_messaging >= 30` in `company.yaml`. Confirm calendar brief ID + pillar + conversion stage are specified (if invoked standalone without brief, prompt for these).

3. **Execute Phase 0 → Phase 9** per SKILL.md Process: Load → Framework Selection (or honor `--framework=N`) → Hook Writing 0-2s (Specificity ≥ 8, 3-5 variants) → Setup 2-8s → Body 8-45s (framework-specific) → Payoff 45-55s → CTA or Loop 55-60s → Platform Adaptations (IG / TikTok / YT Shorts) → Visual Brief (scene shot list, text overlays, transitions) → Compliance (banned vocab, no income/health claims, Specificity ≥ 8 validated).

4. **Write output:**
   - `Write` to `output/write-reel/{YYYY-MM-DD}-reel-{brief-id}.md`
   - Structure per SKILL.md Output Format section — header + hook variants + second-by-second grid + per-platform adaptations + visual brief + compliance + 3 appendices
   - Max 60s runtime hard cap

5. **Update company.yaml:** No compartment writes for per-asset skills — log artifact reference only.

6. **Post-ship:**
   - write `skills/write-reel/evidence/runs/{YYYY-MM-DD}-run.md` with framework rationale + specificity scores + voice-match audit
   - Output next-skill recommendations (`/write-linkedin-post` for repurpose, `/write-x-thread` to expand thesis, `/story-sequence` for IG Stories usage)

## Arguments

If `$ARGUMENTS` contains `--framework=N`, force that the short-form-frameworks author framework. Otherwise select from the pillar+stage decision table (Teaching/Discovery/Speed Build for How-To Awareness; Money Reveal/Transformation/Comparison for Case Study Decision; Challenge/Comparison/Weird Workflow for Myth-Bust Consideration; Discovery/Story Time for Trend).

`$ARGUMENTS`

## Tool usage patterns

- **Read** for loading SKILL.md, calendar brief, Brand Voice Doc, Positioning Doc, the short-form-frameworks author reference
- **Write / Edit** for producing the reel script + per-platform adaptations
- **Grep** across `output/build-icp/` Section 9 for VOC phrases to seed hooks + `output/extract-voice/` for phrases_to_use placement

## Quality gates

Before writing the artifact to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification
- Check `spec/BANNED-VOCABULARY.md` — reject if any banned phrases
- No income guarantees, no health claims without backing
- Confirm every `evidence_gate` condition: framework variant selected, 60s timing grid complete (hard cap — never exceed), Hook Specificity ≥ 8, Loop OR CTA present (not both), voice-matched (3+ phrases_to_use), platform adaptations for all target platforms
- Signal Score ≥ 0.8
- Blind Output Test 2/3 (external tier) scheduled before public posting

## Failure handling

If the skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode (usually Specificity below 8 or generic opener)
- Attempt 2: surface the gap to creator with a targeted question
- If both fail: escalate to marketing-head, log to `skills/write-reel/evidence/failure-modes.md`

## Cross-skill routing

After the reel ships:
- If part of anchor-to-derivative chain (from calendar): route back to `/repurpose` for chain completion
- `/write-linkedin-post` — repurpose concept for LinkedIn
- `/write-x-thread` — expand reel's thesis to thread
- `/story-sequence` — use reel excerpts in 7-day IG Stories
- Engagement feedback (after 48h + 7d) feeds framework performance data back to `/content-calendar` for next-cycle adjustments

---
*the slash-command adapter v1.0 — binds to skills/write-reel/SKILL.md*
