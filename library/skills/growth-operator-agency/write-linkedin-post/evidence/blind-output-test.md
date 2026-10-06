# Blind Output Test — /write-linkedin-post

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **LinkedIn Post (operator-own-offer scope, INV-8)**. Classification: **external** — requires **2/3 evaluator pass** before posting to creator's production feed.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. An active LinkedIn audience member in the creator's ICP (someone who has engaged with the creator's past posts or similar operators — their DM-and-comment behavior is the real verdict)
2. A peer LinkedIn content operator in the creator's space (not an agency-scale poster — another solo creator posting about their own offer, scope-matched to INV-8)
3. The creator themselves (voice calibration check — would they post this verbatim?)

## Test Protocol

### 1. Output Set
- 3 LinkedIn posts the creator has published historically (picking ones that drove real engagement/DMs)
- 3 posts produced by `/write-linkedin-post` (different post types: e.g., one Value Bomb, one Case Study, one Lead Magnet)
- 1 generic-LLM post (control — no Growth Operating Agency context, no voice doc, no positioning)

All outputs anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per post)
For each post, evaluator answers:
1. "Did the creator personally write this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you publish this on your feed?" yes / no / with revisions
5. "Rate the hook (first 140 chars) 1-10"
6. "Rate the CTA + overall save-ability 1-10"

### 3. Pass Criteria
For `/write-linkedin-post` to be blind-test-validated:
- **≥ 2 of 3 Growth Operating Agency posts** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM post** should be identified as `creator`
- Average "Would you publish this?" score ≥ 60% yes for Growth Operating Agency posts
- Average hook rating ≥ 7/10
- Average CTA/save-ability rating ≥ 7/10

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Hook felt generic / under-specific (specificity < 8)
- External link in post body (algo kill + detectability)
- Multiple CTAs stacked (not the outreach director-style single action)
- Banned vocabulary leaked through (thought leader / 10x / supercharge / etc.)
- Missing mechanism thread (no Named Mechanism reference)
- Voice drift — sentence rhythm didn't match creator's extract-voice output

## Known Failure Modes (to watch for)

1. **INV-8 scope violation** — Adapter produces agency-scale content (DM outreach at scale, multi-client content engine posts) instead of creator-posting-about-own-offer. Fix: lock every post to a specific offer from `company.yaml` offer_architecture.core_offers[0].

2. **Hook too generic** — Falls back to "I hit [milestone]" pattern. Real the outreach director hooks open a loop with specificity ≥ 8. Fix: enforce hook-variant requirement (3-5 drafts) + specificity check before selection.

3. **Daily-posting leak** — Calendar brief schedules 5+ posts/week. Dec 2025 algo penalty. Fix: cadence guard — max 4/week, flag if brief exceeds.

4. **External link in body** — Skill includes link in body for convenience. 70% reach kill. Fix: hard-reject any `http://` or `https://` in post body; route to first-comment section.

5. **CTA stack** — "Follow me AND comment X AND DM me." Multiple CTAs = zero action. Fix: single-CTA validator per post.

6. **Voice-match shortfall** — Fewer than 3 `phrases_to_use` from extract-voice output → post reads like generic business writer, not the creator. Fix: count phrases, reject if < 3.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending)
- **Ongoing:** Every 10 runs, sample 1 post for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test
- **Algo-change-triggered:** On any LinkedIn algorithm update (e.g., next Knowledge Graph revision), rerun

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production external use without 2/3 blind test pass.*
