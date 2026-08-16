---
description: Build a 7-section Positioning Document — Vehicle Switch, Unique Mechanism, Core Belief, Narrative Architecture. Messaging spine for every downstream copy asset.
argument-hint: [optional: offer name to position]
allowed-tools: Read, Write, Edit, Grep, Glob, WebSearch, WebFetch
---

# /build-positioning — slash-command runtime Runtime Binding

Load and execute `skills/build-positioning/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/build-positioning/SKILL.md` (full body)
   - `Read` upstream: `output/build-icp/` (latest ICP Document — Completeness >= 80 required) + `output/research/` (Market Research Brief)
   - read `skills/build-positioning/reference/` (all files, if present)

2. **Pre-flight check:** Verify `audience_intelligence_system >= 60`, `creator_identity_matrix >= 50`, `offer_architecture >= 10` in `company.yaml`. If below threshold, route to `/build-icp` first.

3. **Execute Phase 0 → Phase 7** per SKILL.md Process: Load → Market Sophistication Match → Old Vehicle Autopsy → Vehicle Switch → Unique Mechanism → Core Belief Statement (apply 3am Test) → Narrative Architecture (Isomorphic Story check) → Positioning Summary (LAST).

4. **Write output:**
   - `Write` to `output/build-positioning/{YYYY-MM-DD}-positioning-doc.md`
   - Structure per SKILL.md Output Format section (7 sections + appendices)
   - If any section fails cross-validation, mark `[GAP: section N]` and continue

5. **Update company.yaml:**
   - edit `company.yaml` to populate `offer_architecture.positioning` + `copy_messaging.mechanism_name` + `copy_messaging.core_belief`
   - Never overwrite existing values without confirmation

6. **Post-ship:**
   - write `skills/build-positioning/evidence/runs/{YYYY-MM-DD}-run.md` with phase log + confidence tags
   - Output next-skill recommendation (usually `/design-offer`; `/extract-voice` can run in parallel)

## Arguments

If `$ARGUMENTS` is provided, focus positioning on that offer. Otherwise target the offer covered by the ICP Document.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for loading SKILL.md, company.yaml, ICP Document, Market Research Brief, reference frameworks
- **Write / Edit** for producing the Positioning Document and updating company.yaml
- **WebSearch / WebFetch** for competitor positioning scan (to identify category whitespace + confirm Old Vehicle Autopsy)
- **Grep** across `output/` and `company.yaml` to check for existing mechanism names or positioning drafts

## Quality gates

Before writing the artifact to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification
- Check `spec/BANNED-VOCABULARY.md` — reject if any banned phrases
- Confirm every `evidence_gate` condition: all 7 sections, mechanism named + differentiated, Core Belief passes 3am Test, narrative passes Isomorphic check, market sophistication matched
- Signal Score ≥ 0.8
- Blind Output Test 3/3 (sacred-format tier) scheduled before any paid traffic

## Failure handling

If the skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode
- Attempt 2: surface the gap to creator with a targeted question
- If both fail: escalate to foundations-head, log to `skills/build-positioning/evidence/failure-modes.md`

## Cross-skill routing

After the Positioning Document ships:
- Default next skill: `/design-offer` (offer designed to deliver on positioning)
- Parallel: `/extract-voice` if not already complete
- Downstream: `/build-vsl` opens with Big Enemy + weaves Core Belief + closes with offer
- On sacred-format completion: ensure Blind Output Test 3/3 is queued before paid traffic

---
*the slash-command adapter v1.0 — binds to skills/build-positioning/SKILL.md*
