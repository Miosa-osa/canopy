# Blind Output Test — /competitor-intel

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **Competitor Teardown + Whitespace Report**. Classification: **internal** — requires **1/3 evaluator pass**.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. A positioning strategist with deep knowledge of the creator's niche (has spent 100+ hours auditing competitor offers in that market)
2. A competitive-intelligence analyst who has built teardown reports across coaching / info / agency businesses
3. A peer creator in a neighboring niche who has personally purchased from 10+ competitors in their own space

## Test Protocol

### 1. Output Set
- 2 competitor reports produced by the creator or their positioning team (historical audits)
- 3 competitor reports produced by `/competitor-intel` (different niches / market maturities)
- 1 generic-LLM report (control — ChatGPT prompted with "Analyze competitors in [niche] and find whitespace")

All reports anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per report)
For each report, evaluator answers:
1. "Did a strategist/researcher produce this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you use this report to refine positioning?" yes / no / with revisions
5. "Rate the 10-Dimension Teardown 1-10" (specific, sourced, current)
6. "Rate the Whitespace section 1-10" (named specifically + evidenced + actionable)

### 3. Pass Criteria
For `/competitor-intel` to be blind-test-validated:
- **≥ 1 of 3 Growth Operating Agency reports** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM report** should be identified as `creator`
- Average "Would you use this?" score ≥ 50% yes
- Average Teardown rating ≥ 7/10
- Average Whitespace rating ≥ 7/10

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Teardown dimensions hand-waved (no source URL, no dated ad-library scan)
- Whitespace named generically ("be different," "stand out") vs specific named positioning gap
- Tier 2 / Tier 3 competitors missing or collapsed into Tier 1
- Pricing data stale or estimated instead of sourced from public pages
- Ad strategy section weak (no Meta Ad Library references, no creative type count)
- Banned vocabulary leaked through

## Known Failure Modes (to watch for)

1. **Whitespace generic** — "Be more authentic" or "Focus on results" instead of a specific unclaimed positioning / mechanism / proof gap. Fix: require whitespace to name a concrete positioning statement no competitor currently owns, with evidence from the 10-dimension teardowns.

2. **Source data stale** — Competitor pricing or offer structure from 12+ months ago. Fix: require WebFetch with a date-stamp per competitor + flag any data source older than 90 days.

3. **Tier collapse** — Only Tier 1 (direct) covered; adjacent + alternative missing. Fix: enforce the 3-tier matrix check before whitespace synthesis runs.

4. **Ad strategy missing** — Meta Ad Library not consulted. Fix: require at least 1 Meta Ad Library scan per direct competitor + creative-type count + frequency estimate.

5. **Positioning implications disconnected** — Whitespace identified but no clear recommendation for the creator's angle. Fix: require Phase 4 to map each whitespace opportunity to a specific positioning / ad-angle / content move.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending)
- **Ongoing:** Every 20 runs, sample 1 report for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production internal use without 1/3 blind test pass.*
