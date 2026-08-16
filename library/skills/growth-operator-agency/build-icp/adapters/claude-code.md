---
description: Build a 13-section ICP Document with Completeness Score >= 80. Consumes Market Research Brief. Populates Audience Intelligence to 70%+.
argument-hint: [optional: offer name the ICP targets]
allowed-tools: Read, Write, Edit, Grep, Glob, WebSearch, WebFetch
---

# /build-icp — slash-command runtime Runtime Binding

Load and execute `skills/build-icp/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/build-icp/SKILL.md` (full body)
   - read `skills/build-icp/reference/` (all files, if present)
   - `Read` upstream Market Research Brief at `output/research/` (latest)

2. **Pre-flight check:** Verify `audience_intelligence_system >= 30` and `creator_identity_matrix >= 30` in `company.yaml`. If below threshold, route back to `/research` or enter Compartment Interview Mode.

3. **Execute Phase 0 → Phase 13** per SKILL.md Process: Load → Demographic → Firmographic/Life-Stage → Psychological Architecture (apply 3am Test) → Belief System → Awareness Level → Buying Intelligence → Capability Audit → Voice of Customer (20+ verbatim) → Objection Library → Market Context → Strategic Implications → Confidence+Gaps → ICP Summary (LAST).

4. **Write output:**
   - `Write` to `output/build-icp/{YYYY-MM-DD}-icp-doc.md`
   - Structure per SKILL.md Output Format section (13 sections + appendices)
   - If any section fails cross-validation, mark `[GAP: section N]` and continue

5. **Update company.yaml:**
   - edit `company.yaml` to populate Compartment 2 (audience_intelligence_system) to 70%+
   - Never overwrite existing values without confirmation

6. **Post-ship:**
   - write `skills/build-icp/evidence/runs/{YYYY-MM-DD}-run.md` with phase log + confidence tags
   - Output next-skill recommendation (usually `/build-positioning`)

## Arguments

If `$ARGUMENTS` is provided, focus the ICP on that specific offer. Otherwise target the creator's primary offer per `company.yaml` offer_architecture.core_offers[0].

`$ARGUMENTS`

## Tool usage patterns

- **Read** for loading SKILL.md, company.yaml, upstream Market Research Brief, reference frameworks
- **Write / Edit** for producing the ICP Document and updating company.yaml
- **WebSearch / WebFetch** for supplemental VOC gathering if brief's VOC is sparse (Reddit/Quora/community threads)
- **Grep** across `company.yaml` and `reference/` to check what's already known

## Quality gates

Before writing the artifact to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification (formal 40% + semantic 35% + information-theoretic 25%)
- Check `spec/BANNED-VOCABULARY.md` — reject if any banned phrases
- Confirm every `evidence_gate` condition is satisfied
- Completeness Score >= 80
- 20+ verbatim VOC quotes with sources
- Limiting belief diagnosed with 3+ behavioral evidence pieces
- Signal Score ≥ 0.8
- Blind Output Test (internal tier 1/3) scheduled

## Failure handling

If the skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode
- Attempt 2: surface the gap to creator with a targeted question
- If both fail: escalate to foundations-head, log to `skills/build-icp/evidence/failure-modes.md`

## Cross-skill routing

After the ICP Document ships:
- Default next skill: `/build-positioning`
- If Compartment 1 Brand Voice data is sparse: recommend `/extract-voice` to run in parallel
- If Completeness Score < 80: HOLD and run targeted audience interviews before revision
- On Blind Output Test completion: open gate for `/design-offer`

---
*the slash-command adapter v1.0 — binds to skills/build-icp/SKILL.md*
