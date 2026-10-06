---
description: Conduct deep market + audience research for a high-ticket offer. Produces 9-section Market Research Brief. Bootstrap skill — run this first.
argument-hint: [optional: offer name or topic to focus the research]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, WebFetch, WebSearch
---

# /research — slash-command runtime Runtime Binding

Load and execute `skills/research/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/research/SKILL.md` (full body)
   - read `skills/research/reference/` (all files)

2. **Pre-flight check:** Verify Compartment 1 basic_info is populated in `company.yaml`. If not, enter Compartment 1 Interview Mode first.

3. **Execute Phase 0 → Phase 9** per SKILL.md Process section:
   - Phase 0: Pre-flight
   - Phase 1: Market State (use `WebSearch` + `WebFetch` for industry reports, Google Trends, Meta Ad Library)
   - Phase 2: Market Maturity (use `WebFetch` on top 20 competitor sales pages from search)
   - Phase 3: Awareness Distribution
   - Phase 4: ICP demographic + firmographic
   - Phase 5: Psychographics (interview creator + mine available sources)
   - Phase 6: Voice of Customer (use `WebSearch` on Reddit/Quora/community threads + `WebFetch` to pull verbatim quotes)
   - Phase 7: Competitive Landscape
   - Phase 8: Economics Validation
   - Phase 9: Executive Summary (LAST)

4. **Write output:**
   - `Write` to `output/research/{YYYY-MM-DD}-market-research-brief.md`
   - Structure per SKILL.md Output Format section
   - If any section fails cross-validation, mark `[GAP: section N]` and continue

5. **Update company.yaml:**
   - edit `company.yaml` to populate:
     - Compartment 2 (audience_intelligence_system) from Phases 4-7
     - Compartment 3 (offer_architecture.economics_validation) from Phase 8
   - Never overwrite existing values without confirmation

6. **Post-ship:**
   - write `skills/research/evidence/runs/{YYYY-MM-DD}-run.md` with source list + confidence tags
   - Output next-skill recommendation at the end (usually `/build-icp`)

## Arguments

If `$ARGUMENTS` is provided, focus the research on that specific topic/offer. Otherwise research the creator's primary offer per `company.yaml` offer_architecture.core_offers[0].

`$ARGUMENTS`

## Tool usage patterns

- **WebSearch** for initial market scan, trend data, competitor discovery
- **WebFetch** for pulling specific pages (sales pages, Reddit threads, blog articles)
- **Grep** across `company.yaml` and `reference/` to check what's already known
- **Read** `reference/sub-agents/market-research-icp/` for the raw Growth Operating Agency methodology
- **Bash** for running any utility scripts (none required for v1)

## Quality gates

Before writing the brief to `output/`:
- Run through `reference/canonical/spec/QUALITY.md` triple-layer verification
- Check `spec/BANNED-VOCABULARY.md` — reject if any banned phrases
- Confirm 9 sections complete per SKILL.md Output Format
- Confirm Phase 9 Executive Summary was written LAST (not first)

## Failure handling

If the skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode
- Attempt 2: surface the gap to creator with a targeted question
- If both fail: escalate, log to `skills/research/evidence/failure-modes.md`

## Cross-skill routing

After the brief ships, output routing should recommend the next skill:
- If Audience score now ≥ 30%: recommend `/build-icp`
- If the brief reveals the offer needs repositioning: recommend `/build-positioning`
- If economics failed (LTV:CAC < 3:1): recommend `/design-offer` with repositioning emphasis

---
*the slash-command adapter v1.0 — binds to skills/research/SKILL.md*
