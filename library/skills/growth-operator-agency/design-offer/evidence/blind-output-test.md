# Blind Output Test — /design-offer

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces an **Offer Document**. Classification: **sacred-format** — requires **3/3 evaluator pass** before paid traffic or launch. The $10K Cycle 1 hero deliverable — if this fails blind test, every downstream sales asset inherits the failure.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. A high-ticket offer architect (the acquisition economist / the offer architect / the VSL director lineage preferred) who has priced $10K+ offers
2. A past buyer who has consumed 10+ hours of the creator's content and is inside the ICP's aspirant identity
3. A revenue operator (CFO / finance lead) who can stress-test the economics math (LTV:CAC, payback, gross margin)

## Test Protocol

### 1. Output Set
- 2 historical Offer Documents produced by the creator with a hired strategist
- 3 Offer Documents produced by `/design-offer` (different creator contexts)
- 1 generic-LLM offer doc (control — no Growth Operating Agency context, no compartments loaded)

All outputs anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per document)
For each offer, evaluator answers:
1. "Did a strategist/creator produce this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you pay this price for this offer?" yes / no / with revisions (buyer-evaluator only)
5. "Would you launch this offer as-is?" yes / no / with revisions (architect-evaluator)
6. "Rate the Unique Mechanism (Section 3) 1-10"
7. "Rate the Risk Reversal / Guarantee (Section 8) 1-10"
8. "Do the economics survive stress-test?" PASS / FAIL (finance-evaluator)

### 3. Pass Criteria
For `/design-offer` to be blind-test-validated (sacred tier 3/3):
- **3/3 Growth Operating Agency documents** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM document** should be identified as `creator`
- Average "Would you launch this?" score ≥ 70% yes for Growth Operating Agency docs
- Average Unique Mechanism rating ≥ 7/10
- Average Guarantee rating ≥ 7/10
- Economics stress-test PASS on 3/3 docs

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Value Equation denominator (Time Delay × Effort) too high → offer feels heavy
- Mechanism name is generic / adjective-form / > 5 words (not sticky)
- Bonuses don't map to specific ICP objections (bloat, not objection-killers)
- Pricing cost-plus (not identity-aligned) → price feels arbitrary
- Guarantee is standard 30-day money-back (not ROI-positive, doesn't move needle)
- Limiting belief mismatched to transformation type
- Economics math hand-waved (LTV:CAC based on guessed numbers)
- Fabricated case studies or results in value stack
- Banned vocabulary ("unlock," "supercharge," "transform" as verb)

## Known Failure Modes (to watch for)

1. **Limiting belief/transformation mismatch** — ICP diagnosed Hopeless but offer is structured as Status transformation. Fix: hard gate — Phase 2 must align mechanism framing to ICP limiting belief (Worthless→Status / Helpless→Capability / Hopeless→Safety).

2. **Generic mechanism name** — "My 8-week program" or "The Success Method" — not sticky, not ownable. Fix: require 2-5 word proprietary term + differentiator nobody else claims + 3-5 sub-steps for credibility.

3. **Bonuses that don't counter objections** — 5 bonuses listed but no map to ICP Section 10. Fix: Tacit Principle 4 — each bonus maps to specific objection or it gets cut.

4. **Weak guarantee** — "30-day money back" is not ROI-positive. Fix: require guarantee that ensures buyer nets value even if offer "fails" (extension / work-for-free / refund + keep value).

5. **Economics hand-waved** — LTV:CAC computed on guessed CAC. Fix: require actual channel-mix CAC data or explicit assumption disclosure; cross-validate against creator's paid channel history.

6. **Cost-plus pricing** — Price derived from hours × rate rather than identity anchor. Fix: Tacit Principle 1 — price the identity; show comparison anchor in Section 7.

7. **Missing 8 Required Beliefs installation** — One or more beliefs have no installation point. Fix: Section 11 hard gate — every belief needs offer-component + downstream-asset mapping.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending)
- **Ongoing:** Every 5 runs, sample 1 document for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production sacred-format use without 3/3 blind test pass. The $10K Cycle 1 hero skill — economics and offer architecture must survive stress-test before paid traffic.*
