---
description: Convert client wins into isomorphic-story-compliant case studies. Produces 800-1500 word case study + VSL insert + ad variant + social post.
argument-hint: "[optional: client name or retention-check Thriving ID]"
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /case-study — slash-command runtime Runtime Binding

Load and execute `skills/case-study/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/case-study/SKILL.md` (full body)
   - read `skills/case-study/reference/` (all files, if present)
   - `Read` upstream dependency output: `output/retention-check/latest.md` (Thriving client pool source)
   - read `output/build-icp/latest.md` + `output/design-offer/latest.md` for isomorphic fit check

2. **Pre-flight check:** Verify `company.yaml` thresholds — audience_intelligence_system ≥ 50, copy_messaging ≥ 40, lifecycle_optimization ≥ 30. If below, recommend running `/retention-check` first to surface Thriving pool.

3. **Execute Phase 0 → Phase 6** per SKILL.md Process section — Load, Client Qualification, Raw Interview Capture, Isomorphic Fit Verification, Write Case Study, Derivative Outputs, Client Approval + FTC.

4. **Write output:**
   - `Write` to `output/case-study/{YYYY-MM-DD}-case-study-{client-slug}.md`
   - Structure per SKILL.md Output Format (8-section case study + derivatives: VSL insert, ad variant, LinkedIn post, X thread, email broadcast)
   - If any section fails cross-validation, mark `[GAP: section N]` and continue

5. **Update company.yaml:** `Edit` compartment 6 (copy_messaging) — append case-study reference + social-proof level assigned. Never overwrite existing values without confirmation.

6. **Post-ship:**
   - write `skills/case-study/evidence/runs/{YYYY-MM-DD}-run.md` with phase log + confidence tags + isomorphic-fit verdict + social-proof level
   - Output next-skill recommendation (usually `/build-vsl`, `/ad-creative`, `/write-linkedin-post`)

## Arguments

If `$ARGUMENTS` names a client or Thriving ID from retention-check, target that client. Otherwise pick the top Thriving client flagged in the most recent `/retention-check` output.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for loading SKILL.md, company.yaml, reference/, retention-check output, ICP + Offer docs, raw interview transcripts
- **Write / Edit** for producing the case study, derivatives, and updating compartment 6
- **Grep** across `company.yaml` and prior case studies to avoid duplicate claim patterns

## Quality gates

Before writing the case study to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification (formal 40% + semantic 35% + information-theoretic 25%)
- Check `spec/BANNED-VOCABULARY.md` — reject if any banned phrases
- Confirm every evidence_gate condition (isomorphic_fit_verified, raw_interview_captured, 6_level_hierarchy_classified, multiple_format_outputs, ftc_disclosure, client_approval)
- Signal Score ≥ 0.8
- **Sacred-format gate:** Blind Output Test 3/3 required before the case study publishes to paid traffic
- Social-proof level must be 5 or 6 for hero case studies (else route to aggregate testimonial)

## Failure handling

If skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode
- Attempt 2: surface the gap to creator with targeted question (often missing raw-interview quotes or non-isomorphic client selected)
- If both fail: escalate to scale-head, log to `skills/case-study/evidence/failure-modes.md`

## Cross-skill routing

After case study ships:
- Recommend `/build-vsl` to slot the case-study VSL insert
- Recommend `/ad-creative` for the 30-sec ad variant
- Recommend `/write-linkedin-post` + `/write-x-thread` for organic distribution
- Recommend `/email-sequence` for broadcast reference
- **On sacred-format completion: ensure Blind Output Test is queued before paid traffic**

---
*the slash-command adapter v1.0 — binds to skills/case-study/SKILL.md*
