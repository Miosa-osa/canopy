# Blind Output Test — /post-booking-nurture

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **Post-Booking Nurture Stack** (confirmation page + email + SMS + optional phone triage). Classification: **external** — requires **2/3 evaluator pass** before activating the stack on live bookings.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. A past booked caller from the creator's funnel — someone who went from opt-in through to the call (and ideally one who didn't show, to capture the silent-killer lens)
2. A peer operator running a Book-a-Call or Application funnel in a similar price tier — someone who knows 40% vs 70% show-rate feel
3. The creator themselves (confirmation-page video + voice + setter-DM tone calibration)

## Test Protocol

### 1. Output Set
- 2 historical show-rate stacks the creator has run (with known show-rate data — one that performed, one that leaked)
- 3 stacks produced by `/post-booking-nurture` (different offer tiers: e.g., $3K / $10K / $25K)
- 1 generic-LLM stack (control — no Growth Operating Agency context, no the paid media director timing, no the growth engineer 5-function page)

All outputs anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order. Reviewers see confirmation page copy + video script + all 4 emails + all 5 SMS + phone-triage spec (if any).

### 2. Evaluation Questions (per stack)
For each stack, evaluator answers:
1. "Did the creator + their ops team build this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you activate this stack on your funnel tomorrow?" yes / no / with revisions
5. "Rate the confirmation page (copy + video script) 1-10"
6. "Rate the SMS cadence (timing + copy) 1-10"
7. "If you booked this call, would you show up?" yes / no / probably

### 3. Pass Criteria
For `/post-booking-nurture` to be blind-test-validated:
- **≥ 2 of 3 Growth Operating Agency stacks** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM stack** should be identified as `creator`
- Average "Would you activate this?" ≥ 60% yes for Growth Operating Agency stacks
- Average confirmation-page rating ≥ 7/10
- Average SMS cadence rating ≥ 7/10
- Average "Would you show up?" ≥ 70% yes (direct show-rate proxy)

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Confirmation page missing creator video (20%+ show-rate lift skipped)
- Homework list generic or absent (commitment missing)
- SMS timing wrong (e.g., T+5m not T+30m)
- Email stack stuffed with CTAs (burn-out)
- Phone triage missing on $10K+ (silent revenue leak)
- Reschedule link absent (no-shows convert to ghosts instead of reschedules)
- TCPA consent not specified at booking step (compliance violation)

## Known Failure Modes (to watch for)

1. **First-touch > 5 min** — Skill produces confirmation flow but doesn't wire the T+5m SMS trigger. Trust-window missed. Show-rate craters. Fix: Phase 4 SMS cadence validator — within-5m trigger is non-optional.

2. **Video missing on confirmation page** — Skill produces copy-only page. Known 20%+ show-rate lift lost. Fix: Phase 2 requires creator video script 30-90s; reject if missing.

3. **Homework absent or generic** — Homework field says "Review our website" instead of 3-5 specific items. Commitment-building lost. Fix: Phase 2 requires specific homework list with time estimates.

4. **Phone triage missing on high-ticket** — Offer ≥ $10K but no phone-triage spec. Silent revenue leak on most expensive funnel. Fix: Phase 1 component-selection validator — $10K+ requires phone triage.

5. **Over-stack burn** — Skill adds 6+ emails + 7+ SMS "to be safe." Prospect unsubscribes before call. Fix: SKILL.md max stack is 4 email + 5 SMS; reject excess.

6. **Reschedule link missing** — Prospect has conflict, has no reschedule path, ghosts. Show-rate drops 10-15%. Fix: Phase 2 + Phase 3 require reschedule link in confirmation page + every email.

7. **TCPA consent gap** — SMS sequence specified without opt-in consent captured at booking. Legal exposure. Fix: Phase 6 compliance validator — TCPA/GDPR consent tracked or SMS stack blocked.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending)
- **Ongoing:** Every 10 activations, sample 1 stack for blind-test review
- **Low-show-rate-triggered:** If any live funnel drops below 60% show-rate, rerun blind test before adjustment
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production external use without 2/3 blind test pass. Show-rate stack is the silent-killer layer — a 10% miss on show-rate = 25%+ revenue miss.*
