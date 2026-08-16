---
description: Extract the creator's Brand Voice Architecture (10 sections) from existing content + interviews. Populates Compartment 1 brand_voice_architecture.
argument-hint: [optional: specific channel to prioritize, e.g. "podcast" or "LinkedIn"]
allowed-tools: Read, Write, Edit, Grep, Glob, WebFetch
---

# /extract-voice — slash-command runtime Runtime Binding

Load and execute `skills/extract-voice/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/extract-voice/SKILL.md` (full body)
   - read `spec/BANNED-VOCABULARY.md` (baseline for phrases_to_avoid)
   - read `skills/extract-voice/reference/` (all files, if present) + operator voice references

2. **Pre-flight check:** Verify `creator_identity_matrix >= 30` in `company.yaml` and confirm the creator has 3+ hours of content available (podcasts, long-form posts, video transcripts, newsletters). If below threshold, flag for content capture before proceeding.

3. **Execute Phase 0 → Phase 11** per SKILL.md Process: Collect Samples → Annotation → Communication Style → Tone Framework → Personality Traits → Language Patterns → phrases_to_use (15+) → phrases_to_avoid (10+) → Persuasion Style → Authority Positioning → Contrarian Beliefs + Voice Samples → Voice Summary (LAST).

4. **Write output:**
   - `Write` to `output/extract-voice/{YYYY-MM-DD}-brand-voice-doc.md`
   - Structure per SKILL.md Output Format section (10 sections + appendices)
   - If any section fails verbatim-count gate, mark `[GAP: section N — needs more samples]` and continue

5. **Update company.yaml:**
   - edit `company.yaml` to populate Compartment 1 `brand_voice_architecture` sub-fields (communication_style, tone_framework, personality_traits, language_patterns, phrases_to_use, phrases_to_avoid, persuasion_style, authority_positioning)
   - Never overwrite existing values without creator review confirmation

6. **Post-ship:**
   - write `skills/extract-voice/evidence/runs/{YYYY-MM-DD}-run.md` with sample inventory + confidence tags
   - Schedule creator review (voice extraction is load-bearing and requires human sign-off per Tacit Principle 7)
   - Output next-skill recommendation (enables every downstream copy skill)

## Arguments

If `$ARGUMENTS` is provided, prioritize that channel's samples (e.g., "podcast" → weight podcast transcripts heaviest). Otherwise balance across all available sample types.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for loading SKILL.md, company.yaml, reference materials, and any existing content samples stored locally
- **Write / Edit** for producing the Brand Voice Document and updating company.yaml
- **WebFetch** for pulling podcast transcripts, YouTube transcripts, LinkedIn posts, newsletter archives if URL-based
- **Grep** across content samples to count phrase occurrences (3+ instances = signature per Tacit Principle 2)

## Quality gates

Before writing the artifact to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification
- Check `spec/BANNED-VOCABULARY.md` — reject if any banned phrases leak through
- Confirm every `evidence_gate` condition: all 10 sections, phrases_to_use ≥ 15 verbatim, phrases_to_avoid ≥ 10, language_patterns ≥ 5, voice_samples_annotated ≥ 5
- Signal Score ≥ 0.8
- Creator review scheduled (REQUIRED before shipping)
- Blind Output Test 3/3 (sacred-format tier) scheduled — voice-matching IS the primary blind-test

## Failure handling

If the skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode (usually sparse samples → pause for more content capture)
- Attempt 2: surface gap to creator with targeted question ("we need 2 more podcast transcripts to hit the 3+ instance threshold")
- If both fail: escalate to foundations-head, log to `skills/extract-voice/evidence/failure-modes.md`

## Cross-skill routing

After the Brand Voice Document ships + creator confirms:
- Enables EVERY downstream copy skill: `/build-vsl`, `/write-linkedin-post`, `/write-reel`, `/email-sequence`, `/ad-creative`, `/sales-script`, `/write-youtube`, `/write-x-thread`, `/story-sequence`
- On sacred-format completion: ensure Blind Output Test 3/3 is queued before any public copy ships
- Annual re-extraction recommended as voice evolves

---
*the slash-command adapter v1.0 — binds to skills/extract-voice/SKILL.md*
