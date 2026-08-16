# Blind Output Test — /story-sequence

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **7-day IG Story Sequence**. Classification: **external** — requires **2/3 evaluator pass** before the creator publishes a full week-run on their main IG or Close Friends list.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. An active IG follower of the creator (someone in the Close Friends list or heavy story-viewer — their sentiment on authenticity vs salesy is the real signal)
2. A peer IG story operator who runs stories-director-style sequences (a fellow creator or small-team operator in the creator's space, not an agency)
3. The creator themselves (voice + brand-fit + comfort-to-publish check)

## Test Protocol

### 1. Output Set
- 2 historical week-sequences the creator has actually run (pick weeks with DM + conversion traction, not just view-count)
- 3 week-sequences produced by `/story-sequence` (different creator contexts or different weekly themes)
- 1 generic-LLM sequence (control — no Growth Operating Agency context)

All outputs anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order. Reviewers see text scripts + visual concepts (not final designs — this tests copy + structure).

### 2. Evaluation Questions (per week-sequence)
For each sequence, evaluator answers:
1. "Did the creator plan this week, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you run this on your own feed?" yes / no / with revisions
5. "Rate the orange/grey balance 1-10"
6. "Rate the Day 3 objection-break 1-10"

### 3. Pass Criteria
For `/story-sequence` to be blind-test-validated:
- **≥ 2 of 3 Growth Operating Agency sequences** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM sequence** should be identified as `creator`
- Average "Would you run this?" ≥ 60% yes for Growth Operating Agency sequences
- Average orange/grey balance rating ≥ 7/10
- Average Day 3 objection-break rating ≥ 7/10

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Orange-heavy week (too salesy — missed 4+3 balance)
- Same framework repeated 2 days in a row (pattern fatigue)
- Day 3 objection generic instead of pulled from ICP Section 10
- Blank backgrounds specified (violates 4-layer anatomy)
- Claim without screenshot proof (Truth Gate violation)
- Day 5 + Day 7 grey days don't humanize (still reads as orange)

## Known Failure Modes (to watch for)

1. **Orange/grey imbalance** — Skill produces 6 orange + 1 grey (too salesy) or 5 grey + 2 orange (no conversion pressure). Fix: enforce 4+3 validator; reject if off.

2. **Same framework Day N and Day N+1** — E.g., Day 1 Proof-From-Many + Day 2 also Proof. Pattern fatigue. Fix: framework-rotation check in Phase 2.

3. **Day 3 objection guessed** — Skill fabricates an objection instead of pulling from ICP Section 10 Objection Library. Result: objection doesn't resonate, day wasted. Fix: require explicit reference to ICP objection entry with source quote.

4. **Blank background specified** — Skill suggests "clean white background" or "just text." Violates 4-layer anatomy subconscious-proof rule. Fix: hard-reject blank; require image concept per slide.

5. **Claim without screenshot** — "I helped 50 clients hit $10K" with no Stripe/testimonial screenshot cited. Truth Gate violation + trust leak. Fix: proof-screenshot field required when any claim is in the text layer.

6. **Day 7 Mission generic** — Reads like a LinkedIn "why I do this" post, not a specific mission. Day 7 is supposed to seed next week's cycle. Fix: require specific next-week-setup line in Day 7 close.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending)
- **Ongoing:** Every 10 week-sequences, sample 1 for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production external use without 2/3 blind test pass.*
