---
description: Produce paid ad creative briefs + copy variants across 8 ad types. Specificity ≥ 8, voice-matched, compliance-checked. Meta Ads Library-ready.
argument-hint: [optional: "--type=1-8" to force; else auto-select by audience + budget + format]
allowed-tools: Read, Write, Edit, Grep, Glob, WebSearch, WebFetch
---

# /ad-creative — slash-command runtime Runtime Binding

Load and execute `skills/ad-creative/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/ad-creative/SKILL.md` (full body)
   - `Read` upstream: `output/design-offer/`, `output/build-icp/` (VOC Section 9 is critical), `output/build-positioning/` (mechanism), `output/extract-voice/` (phrases_to_use)
   - read `reference/frameworks/primitives/specificity.md` (media-testing methodology), `reference/frameworks/instagram-profile-funnel/README.md` (Instagram profile-funnel methodology), the growth engineer + the operations director operator files

2. **Pre-flight check:** Verify `audience_intelligence_system >= 70`, `offer_architecture >= 50`, `copy_messaging >= 40`, `traffic_acquisition >= 20` in `company.yaml`. Confirm Meta pixel + CAPI are wired before any live-traffic recommendation.

3. **Execute Phase 0 → Phase 8** per SKILL.md Process: Load Dependencies → Ad Type Selection → Creative Family Plan (3-5 variants sharing angle + hook + offer) → Hook + Copy Writing (voice-matched) → Visual Brief → Compliance Check → Specificity Scoring (5 dimensions, target ≥ 8) → Pixel Conditioning Plan → Creative Brief Summary.

4. **Write output:**
   - `Write` to `output/ad-creative/{YYYY-MM-DD}-ad-brief-type-{1-8}.md`
   - Structure per SKILL.md Output Format section — header + family variants + campaign structure + compliance + 3 appendices
   - Per variant: hook + body copy + CTA + visual brief + platform adaptations

5. **Update company.yaml:**
   - edit `company.yaml` Compartment 7 (traffic_acquisition) to reference creative brief + campaign structure
   - Never overwrite existing creative references without confirmation

6. **Post-ship:**
   - write `skills/ad-creative/evidence/runs/{YYYY-MM-DD}-run.md` with ad type rationale + specificity scores + voice-match audit
   - Output next-skill recommendations (`/landing-page` to match promise, `/post-booking-nurture` if call funnel, `/content-calendar` for organic lift, `/ig-profile-funnel` if Type 1 selected)

## Arguments

If `$ARGUMENTS` contains `--type=N`, force that ad type. Otherwise auto-select based on creator organic infrastructure, budget tier, offer price, testimonial availability, audience temperature.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for loading SKILL.md, all upstream Docs, specificity/the paid media director references
- **Write / Edit** for producing the creative brief and updating company.yaml
- **WebSearch** for competitor ad intelligence (Meta Ad Library scan — Appendix A)
- **WebFetch** for pulling specific competitor ad creatives + analyzing angles / formats / frequencies
- **Grep** across `output/build-icp/` Section 9 to pull verbatim VOC for ad copy

## Quality gates

Before writing the artifact to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification
- Check `spec/BANNED-VOCABULARY.md` — full INV-7 sweep
- Compliance: no income guarantees, no health claims without clinical backing, no before/after without disclaimer, Meta restricted category check if applicable, FTC disclosure if testimonials
- Confirm every `evidence_gate` condition: ad type with reasoning, Specificity Score ≥ 8 per variant, mechanism referenced, voice-matched, compliance passed, variant count ≥ 3
- Signal Score ≥ 0.8
- Blind Output Test 2/3 (external tier) scheduled before live traffic

## Failure handling

If the skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode (usually specificity gap or voice mismatch)
- Attempt 2: surface the gap to creator with a targeted question
- If both fail: escalate to marketing-head, log to `skills/ad-creative/evidence/failure-modes.md`

## Cross-skill routing

After the creative brief ships:
- If Type 1 (Profile Funnel) selected: recommend `/ig-profile-funnel` to optimize the profile before running ads
- If targeting call funnels: pair with `/post-booking-nurture` for show-rate stack
- Always pair with `/landing-page` to ensure promise-match
- Parallel: `/content-calendar` for organic lift (pixel conditioning benefits from organic warm audiences)
- Scale via the growth engineer Creative Family Micro Tests — duplicate winner at 2× budget, never bid-increase

---
*the slash-command adapter v1.0 — binds to skills/ad-creative/SKILL.md*
