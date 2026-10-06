# Blind Output Test — /write-x-thread

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces an **X/Twitter Thread** (one of 7 types). Classification: **external** — requires **2/3 evaluator pass** before posting to creator's production feed.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. An active X audience member in the creator's ICP (someone whose bookmarks + replies pattern reveals what resonates on the platform)
2. A peer X operator in the creator's space who consistently lands threads with 100+ bookmarks (platform-native instinct)
3. The creator themselves (final voice + CTA-tolerance check)

## Test Protocol

### 1. Output Set
- 3 threads the creator published historically (pick ones with real bookmark + reply traction — not vanity-likes)
- 3 threads produced by `/write-x-thread` (different types: e.g., one Hot Take, one How-To, one Case Study)
- 1 generic-LLM thread (control — no Growth Operating Agency context)

All outputs anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per thread)
For each thread, evaluator answers:
1. "Did the creator write this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you bookmark this?" yes / no
5. "Rate the hook tweet (first 280 chars) 1-10"
6. "Rate the final-tweet CTA 1-10"

### 3. Pass Criteria
For `/write-x-thread` to be blind-test-validated:
- **≥ 2 of 3 Growth Operating Agency threads** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM thread** should be identified as `creator`
- Average "Would you bookmark this?" ≥ 60% yes for Growth Operating Agency threads
- Average hook tweet rating ≥ 7/10
- Average final CTA rating ≥ 7/10

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Hook tweet was generic ("A thread 🧵" lazy pattern)
- Tweets crammed multiple ideas (violates 1-idea-per-tweet)
- Thread over-threaded (15+ tweets = drop-off cliff)
- Banned vocabulary (thought leader / 10x / supercharge)
- CTA stacked multiple actions
- No save-optimization (no list/framework/checklist to bookmark)

## Known Failure Modes (to watch for)

1. **Hook "A thread 🧵" laziness** — Skill defaults to meta-hook ("Here's a thread about X") instead of content-hook with specificity ≥ 8. Fix: enforce hook-variant requirement (3-5 drafts) + specificity check + ban meta-hook opener.

2. **Over-threading** — Skill produces 15+ tweets in a "thread" type (not Daily Tweets batch). Drop-off cliff hits. Fix: enforce 7-12 tweet ceiling for standard threads; route to Daily Tweets type if creator has too much material.

3. **Multiple ideas per tweet** — Tweets get crammed to save on thread length. Threadability + readability die. Fix: 1-idea-per-tweet validator; split any tweet with multiple claims.

4. **External link in thread body** — Kills algorithmic distribution on X. Fix: link goes in final tweet or reply only; body-link hard-reject.

5. **Hot-Take thread mild** — Hot Take type produced without genuine polarization. Reads like a mild opinion. Fix: enforce "Big Enemy reference" from positioning doc for Hot Take type; if no enemy nameable, suggest different type.

6. **Daily Tweets aren't thematically linked** — Type 7 produces 5 random tweets instead of 5 tweets around one theme. Fix: weekly-theme gate on batch output.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending)
- **Ongoing:** Every 10 runs, sample 1 thread for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production external use without 2/3 blind test pass.*
