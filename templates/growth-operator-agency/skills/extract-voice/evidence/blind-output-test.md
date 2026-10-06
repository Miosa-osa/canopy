# Blind Output Test — /extract-voice

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **Brand Voice Document**. Classification: **sacred-format** — requires **3/3 evaluator pass**. Voice-matching is THE primary blind-test target — if this skill fails here, every downstream copy skill leaks generic AI voice.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. The creator's long-tenured team member (6+ months) — someone who ghostwrites or edits in the creator's voice
2. A past buyer who has consumed 10+ hours of the creator's content (podcast + videos + posts)
3. A peer creator or ghostwriter in the creator's network who could plausibly imitate the voice

## Test Protocol

### 1. Output Set
- 2 historical Brand Voice Documents produced by the creator's team or a hired ghostwriter
- 3 Brand Voice Documents produced by `/extract-voice` (different creator contexts)
- 1 generic-LLM voice doc (control — no Growth Operating Agency context, no real sample library)

All outputs anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per document)
For each document, evaluator answers:
1. "Did a ghostwriter/team produce this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you use this doc to brief a copywriter?" yes / no / with revisions
5. "Rate the phrases_to_use accuracy (Section 6) 1-10"
6. "Rate the Contrarian Beliefs + Voice Samples (Section 10) 1-10"

### 3. Pass Criteria
For `/extract-voice` to be blind-test-validated (sacred tier 3/3):
- **3/3 Growth Operating Agency documents** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM document** should be identified as `creator`
- Average "Would you use this to brief a copywriter?" score ≥ 70% yes
- Average phrases_to_use accuracy rating ≥ 7/10
- Average Contrarian Beliefs rating ≥ 7/10

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Invented phrases that the creator doesn't actually use (biggest failure mode)
- Phrases listed without source + count (unverifiable signature claim)
- Communication style miscategorized (e.g., storytelling when creator is direct)
- Contrarian beliefs that don't actually recur across samples
- Channel-mixing failure (treating LinkedIn voice and podcast voice as one when they differ)
- Absence not flagged (creator doesn't use emojis / em-dashes / certain openers — unflagged)

## Known Failure Modes (to watch for)

1. **Invented phrases_to_use** — Skill infers plausible-sounding phrases rather than extracting verbatim. Fix: Tacit Principle 1 — "extraction, not invention" — hard-require `[VERBATIM: 3+ instances]` tagging with source citations.

2. **Under-count of instances** — Phrase appears once and gets listed as signature. Fix: Tacit Principle 2 — 3+ instances or it's not signature; tag single-instance phrases as `[INFERRED]` only.

3. **Voice sample generic** — 5 annotated samples but annotations are shallow ("this is engaging"). Fix: require specific phrase callouts + tone markers + sentence pattern analysis per sample.

4. **Cross-channel conflation** — Creator's LinkedIn voice is different from podcast voice but doc treats them as one. Fix: Tacit Principle 3 — note channel for each sample + flag cross-channel vs channel-specific patterns.

5. **Missing absence flags** — Creator NEVER uses emojis/em-dashes/certain openers but doc doesn't note this. Fix: Tacit Principle 6 — explicit "what's NOT there" section in Language Patterns.

6. **Creator review skipped** — Doc ships without creator confirmation. Fix: hard gate — no ship without creator "is this how you sound?" confirmation.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending)
- **Ongoing:** Every 5 runs, sample 1 document for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test
- **Annual re-extraction** — voices evolve over 12+ months

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production sacred-format use without 3/3 blind test pass. Voice extraction is the primary differentiator vs generic LLM output.*
