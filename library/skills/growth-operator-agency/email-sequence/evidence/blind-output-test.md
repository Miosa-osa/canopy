# Blind Output Test — /email-sequence

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces an **Email Sequence** (one of 8 types). Classification: **external** — requires **2/3 evaluator pass** before sending to creator's production list.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. An active subscriber on the creator's list (someone who opens + replies regularly — their inbox-reflex is the verdict on "does this feel like a creator email or a blast")
2. A peer email operator in the creator's vertical (someone running their own list, not an agency-scale email marketer)
3. The creator themselves (signature voice + P.S. style calibration)

## Test Protocol

### 1. Output Set
- 3 emails the creator has personally written (from historical sends — pick ones with real reply + click traction)
- 3 emails produced by `/email-sequence` (different types: e.g., one Nurture Day 7, one Launch Shout email, one Post-Purchase Day 3)
- 1 generic-LLM email (control — no Growth Operating Agency context)

All outputs anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per email)
For each email, evaluator answers:
1. "Did the creator write this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you send this to your list?" yes / no / with revisions
5. "Rate the subject + preview text 1-10"
6. "Rate the body + CTA 1-10"

### 3. Pass Criteria
For `/email-sequence` to be blind-test-validated:
- **≥ 2 of 3 Growth Operating Agency emails** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM email** should be identified as `creator`
- Average "Would you send this?" ≥ 60% yes for Growth Operating Agency emails
- Average subject+preview rating ≥ 7/10
- Average body+CTA rating ≥ 7/10

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Subject feels generic / low-specificity (< 8)
- Preview repeats subject verbatim (wastes the second hook)
- Body reads like a blast, not a personal note
- Multiple CTAs stacked
- Missing P.S. (highest-read line wasted)
- Banned vocabulary (thought leader / supercharge / paradigm shift)
- CAN-SPAM gap (missing address or unsubscribe)

## Known Failure Modes (to watch for)

1. **Subject too generic** — Specificity < 8. "Quick tip" or "An update" pattern. Destroys open rate. Fix: enforce specificity ≥ 8 + 3 subject-variant requirement per email.

2. **Stacked CTAs** — Body has "reply to this + click here + book a call." Zero clicks result. Fix: single-CTA validator per email.

3. **Launch sent to cold list without nurture** — Type 3 Launch triggered on subscribers who haven't been through Type 2 Nurture. Burns the list. Fix: segmentation gate — Launch sequences require nurture-complete tag on segment.

4. **P.S. missing or wasted** — No P.S., or P.S. just says "thanks." Highest-read line wasted. Fix: require P.S. with urgency reminder OR second CTA repeat OR punchline.

5. **Fake-reply subject ("Re:") or "Quick question"** — Explicit banned patterns. Trust-leak + potential deliverability hit. Fix: hard-reject these patterns.

6. **Post-Purchase day-cadence too aggressive** — Type 7 sends Day 0/1/3/7 with no breathing room. New buyer gets overwhelmed. Fix: validate cadence against SKILL.md table + adjust per offer complexity.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending)
- **Ongoing:** Every 10 sequences (or every Launch sequence regardless), sample for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production external use without 2/3 blind test pass.*
