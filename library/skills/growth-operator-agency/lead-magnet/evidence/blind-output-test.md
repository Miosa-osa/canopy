# Blind Output Test — /lead-magnet

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **Lead Magnet Brief** (one of 9 the acquisition economist types). Classification: **external** — requires **2/3 evaluator pass** before running paid traffic to the opt-in page.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. A past opt-in from the creator's list — someone who actually downloaded a lead magnet, consumed it, and later either bought or didn't (their reaction reveals bridge-to-offer quality)
2. A peer nurture operator in the creator's space who runs their own funnel (they know what drives 30%+ opt-in vs 10%)
3. The creator themselves (title + promise + mechanism-thread calibration)

## Test Protocol

### 1. Output Set
- 2 lead magnets the creator has historically run (pick ones with known opt-in rate data — one that converted well, one that didn't)
- 3 briefs produced by `/lead-magnet` (different types: e.g., one Checklist, one Quiz, one Free Training)
- 1 generic-LLM brief (control — no Growth Operating Agency context)

All outputs anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order. Reviewers see opt-in page copy + asset outline + bridge-to-offer section (not final designed PDFs).

### 2. Evaluation Questions (per brief)
For each brief, evaluator answers:
1. "Did the creator plan this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you opt in for this?" yes / no
5. "Rate the title + opt-in hook 1-10"
6. "Rate the bridge-to-offer section 1-10"

### 3. Pass Criteria
For `/lead-magnet` to be blind-test-validated:
- **≥ 2 of 3 Growth Operating Agency briefs** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM brief** should be identified as `creator`
- Average "Would you opt in?" ≥ 60% yes for Growth Operating Agency briefs
- Average title+hook rating ≥ 7/10
- Average bridge-to-offer rating ≥ 7/10

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Title generic ("Ultimate Guide to X")
- Specificity < 8 on title
- Bridge-to-offer missing or weak (lead magnet doesn't route to core offer)
- Mechanism name missing (generic teaching instead of creator's unique mechanism)
- Delivery email delayed > 2 min (implicit in spec)
- Asset too large to consume in 15 min (wrong value-equation math)

## Known Failure Modes (to watch for)

1. **Title generic / low-specificity** — "Ultimate Guide to Marketing" instead of "The 48-Hook Framework That Got Me 800K LinkedIn Impressions in 30 Days." Opt-in rate tanks from 30% to 8%. Fix: enforce specificity ≥ 8 + named outcome + timeframe check on all title variants.

2. **No bridge-to-offer** — Asset teaches the full solve, so prospect doesn't need the core offer. Attracts audience that never buys. Fix: Bridge-to-Offer section mandatory in Phase 4; reject if it doesn't explicitly name the mechanism + tease core offer + single CTA.

3. **Asset too big** — 50-page PDF nobody reads. Value Equation gets wrong Time Delay × Effort math. Fix: enforce 15-min-or-less consumption + page count ceilings per type (PDF Guide 8-15, Checklist 1-2, Cheat Sheet 1).

4. **Delivery delay** — Spec describes delivery email but doesn't wire instant automation. 2-min-plus delay = trust leak + unsub spike. Fix: Phase 6 hard-requires ESP API trigger + < 2-min send.

5. **Borrowed competitor magnet** — Skill produces a generic swipe-file or a "top-10 tips" that any coach could drop. No creator mechanism threaded. Fix: enforce explicit reference to creator's named mechanism from Positioning Doc + reject if mechanism doesn't appear.

6. **Segmentation data missing** — Quiz type produces questions but no segmentation spec on opt-in (role / stage / goal). Downstream sequences fly blind. Fix: Phase 6 requires intent-indicator capture on submit.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending)
- **Ongoing:** Every 10 lead magnets, sample 1 for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Traffic-spend-triggered:** Before any paid-traffic spend > $500, blind test required
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production external use without 2/3 blind test pass.*
