---
description: Produce competitor teardown + positioning whitespace analysis across 3-tier matrix (direct / adjacent / alternative). 10-dimension teardown per direct competitor.
argument-hint: "[optional: competitor list or market slug]"
allowed-tools: Read, Write, Edit, Grep, Glob, WebSearch, WebFetch
---

# /competitor-intel — slash-command runtime Runtime Binding

Load and execute `skills/competitor-intel/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/competitor-intel/SKILL.md` (full body)
   - read `skills/competitor-intel/reference/` (all files, if present)
   - `Read` upstream dependency output: `output/research/latest-market-research-brief.md` (target market + initial competitor list)
   - read `output/build-positioning/latest.md` if present (for whitespace implications)

2. **Pre-flight check:** Verify `company.yaml` thresholds — audience_intelligence_system ≥ 50, offer_architecture ≥ 40. If below, recommend running `/research` first.

3. **Execute Phase 0 → Phase 4** per SKILL.md Process section — Load, Competitor List, Per-Competitor Teardown (10-dimension via WebFetch + WebSearch + Meta Ad Library), Whitespace Synthesis, Positioning Implications.

4. **Write output:**
   - `Write` to `output/competitor-intel/{YYYY-MM-DD}-competitor-intel.md`
   - Structure per SKILL.md Output Format (3-tier matrix + per-competitor teardowns + cross-competitor patterns + whitespace opportunities + positioning implications)
   - If any section fails cross-validation, mark `[GAP: section N]` and continue

5. **Update company.yaml:** `Edit` compartment 2 (audience_intelligence_system) — append competitor roster + whitespace opportunities. Never overwrite existing values without confirmation.

6. **Post-ship:**
   - write `skills/competitor-intel/evidence/runs/{YYYY-MM-DD}-run.md` with phase log + confidence tags + competitor count per tier + source URLs
   - Output next-skill recommendation (usually `/build-positioning` if whitespace reshapes positioning)

## Arguments

If `$ARGUMENTS` names competitors or a market slug, target that list. Otherwise pull the competitor roster from the most recent `/research` brief.

`$ARGUMENTS`

## Tool usage patterns

- **WebSearch** for discovering competitors beyond the research brief, Meta Ad Library scans, pricing searches
- **WebFetch** for pulling competitor sales pages, VSL transcripts, Meta Ad Library creative, public Stripe/Kajabi pricing pages
- **Read** for loading SKILL.md, company.yaml, reference/, research brief
- **Write / Edit** for producing the report and updating compartment 2
- **Grep** across `company.yaml` to check prior competitor data

## Quality gates

Before writing the report to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification (formal 40% + semantic 35% + information-theoretic 25%)
- Check `spec/BANNED-VOCABULARY.md` — reject if any banned phrases
- Confirm every evidence_gate condition (3_tier_matrix_complete, min_3_direct_competitors, whitespace_identified)
- Signal Score ≥ 0.8
- No plagiarized competitor content; all sources cited with URL + date

## Failure handling

If skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode
- Attempt 2: surface the gap to creator with targeted question (often competitor visibility limited)
- If both fail: escalate to scale-head, log to `skills/competitor-intel/evidence/failure-modes.md`

## Cross-skill routing

After report ships:
- Recommend `/build-positioning` if whitespace reshapes the creator's angle
- Recommend `/ad-creative` for differentiated ad angles using identified whitespace
- Recommend `/write-linkedin-post` for contrarian content using whitespace

---
*the slash-command adapter v1.0 — binds to skills/competitor-intel/SKILL.md*
