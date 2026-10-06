---
description: Build a 30-day content calendar across active channels with 40/30/20/10 pillar ratio + Core Four mix + per-post briefs routed to writing skills.
argument-hint: [optional: target month, e.g. "2026-05" or number of days to plan]
allowed-tools: Read, Write, Edit, Grep, Glob, WebSearch
---

# /content-calendar — slash-command runtime Runtime Binding

Load and execute `skills/content-calendar/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/content-calendar/SKILL.md` (full body)
   - `Read` upstream: `output/build-icp/` (VOC + objections + buying triggers), `output/build-positioning/` (Big Enemy + mechanism + core belief), `output/design-offer/` (bonuses, guarantee — for decision content), `output/extract-voice/` (phrases_to_use)
   - read `reference/frameworks/primitives/core-four.md` + the content OS director / the VSL director / the stories director operator files

2. **Pre-flight check:** Verify `audience_intelligence_system >= 60`, `offer_architecture >= 50`, `copy_messaging >= 30`, `content_strategy >= 20` in `company.yaml`. Verify Compartment 6 `platform_strategies` has at least 1 active: true channel. If < 1 active channel, enter Compartment 6 interview mode first.

3. **Execute Phase 0 → Phase 8** per SKILL.md Process: Load Dependencies → Channel Activation Check → Platform Cadence Mapping → Topic Pool Generation (80-120 candidates from VOC/triggers/objections/mechanism/Big Enemy) → 30-Day Calendar Layout → Content-to-Conversion Bridge Mapping (50/35/15) → Per-Post Brief Generation (routes to writing skills) → Metrics + Review Cadence → Calendar Export (markdown + Notion + Buffer JSON).

4. **Write output:**
   - `Write` to `output/content-calendar/{YYYY-MM-DD}-30day-calendar.md`
   - Structure per SKILL.md Output Format section — calendar overview + day-by-day table + per-post briefs + 4 appendices
   - Each calendar slot includes post ID, platform, format, pillar, stage, topic, skill routing, voice samples

5. **Update company.yaml:**
   - edit `company.yaml` Compartment 6 (content_strategy) with pillar allocation + channel cadence + anchor-to-derivative repurpose chain
   - Never overwrite existing calendar references without confirmation

6. **Post-ship:**
   - write `skills/content-calendar/evidence/runs/{YYYY-MM-DD}-run.md` with pillar ratio audit + topic pool inventory + conversion stage distribution
   - Output next-skill recommendations per calendar slot (routes to `/write-youtube`, `/write-reel`, `/write-linkedin-post`, `/write-x-thread`, `/story-sequence`, `/email-sequence`)

## Arguments

If `$ARGUMENTS` is provided, use it as the target month or day count. Otherwise plan the next calendar month starting from today.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for loading SKILL.md, all upstream Docs, content-strategy frameworks
- **Write / Edit** for producing the calendar (markdown + optional JSON/Notion exports) and updating company.yaml
- **WebSearch** for trend-scan (capped at 10% of calendar per Important Rules — avoid pure news-cycle chasing)
- **Grep** across `output/build-icp/` for VOC pain/desire language + buying triggers + objections to seed topic ideas

## Quality gates

Before writing the artifact to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification
- Check `spec/BANNED-VOCABULARY.md` — sweep all brief language
- Confirm every `evidence_gate` condition: 30-day calendar complete, 40/30/20/10 pillar ratio enforced weekly + monthly, content-to-conversion bridge 50/35/15 distributed, Core Four channel mix applied, per-post brief for every slot, platform-specific cadence respected (the VSL director Shorts Rule, LinkedIn 3-4/week NOT daily)
- Big Enemy appears at least weekly
- Signal Score ≥ 0.8
- Blind Output Test 2/3 (external tier) scheduled

## Failure handling

If the skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode (usually pillar imbalance or over-trend content)
- Attempt 2: surface the gap to creator with a targeted question ("we have 0 active channels marked — which 1-2 should we start with?")
- If both fail: escalate to marketing-head, log to `skills/content-calendar/evidence/failure-modes.md`

## Cross-skill routing

After the calendar ships:
- Per-post routing:
  - Long-form video slot → `/write-youtube`
  - Short-form slot → `/write-reel`
  - LinkedIn post → `/write-linkedin-post`
  - X thread → `/write-x-thread`
  - IG Stories sequence → `/story-sequence`
  - Email broadcast → `/email-sequence`
- Anchor-to-derivative chain → `/repurpose` expands 1 anchor into N derivatives
- Weekly metrics review drives adjustments; monthly regenerate for next cycle

---
*the slash-command adapter v1.0 — binds to skills/content-calendar/SKILL.md*
