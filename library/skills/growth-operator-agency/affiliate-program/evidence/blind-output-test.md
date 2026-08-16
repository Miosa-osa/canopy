# Blind Output Test — /affiliate-program

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces an **Affiliate Program Specification**. Classification: **external** (published and read by real affiliate partners) — requires **2/3 evaluator pass**.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. An existing affiliate program operator (has run a Rewardful / FirstPromoter / Everflow program for 12+ months and knows what terms actually convert top affiliates)
2. A Tier 1 affiliate / JV partner (someone who personally promotes 5+ offers and can evaluate whether the program terms are competitive)
3. An affiliate-ops manager or affiliate-network broker who has onboarded 50+ creators into affiliate programs

## Test Protocol

### 1. Output Set
- 2 affiliate program specs produced by the creator or a peer creator's partnerships team (historical)
- 3 affiliate program specs produced by `/affiliate-program` (different offer types: info / digital / SaaS / done-for-you)
- 1 generic-LLM spec (control — ChatGPT prompted with "Design an affiliate program for a $2K course")

All specs anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per spec)
For each spec, evaluator answers:
1. "Did a partnerships team produce this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you (as affiliate) promote a program on these terms?" yes / no / with revisions
5. "Rate the Commission Structure 1-10" (competitive, tiered sensibly, math works)
6. "Rate the Compliance section 1-10" (FTC + tax forms + contract present and specific)

### 3. Pass Criteria
For `/affiliate-program` to be blind-test-validated:
- **≥ 2 of 3 Growth Operating Agency specs** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM spec** should be identified as `creator`
- Average "Would you promote?" score ≥ 60% yes
- Average Commission rating ≥ 7/10
- Average Compliance rating ≥ 7/10

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Commission rates off-market (too low or unsustainable)
- Cookie window generic (30 days default for a 90-day consideration offer)
- Tier structure collapsed (only one rate, no Tier 1 incentive for top affiliates)
- Compliance hand-waved (FTC disclosure template missing, W-9/W-8BEN not referenced)
- Promotion assets list-only (no actual swipe copy or ad creative briefs)
- Economics validation skipped (payout breaks ≥ 3:1 LTV:CAC)
- Banned vocabulary leaked through

## Known Failure Modes (to watch for)

1. **Economics break LTV:CAC** — 50% commission on a product with 2:1 LTV:CAC destroys margin. Fix: enforce Phase 7 Economics Validation as a hard gate; reject if post-payout LTV:CAC drops below 3:1.

2. **Cookie window mismatched to offer cycle** — 30-day window on a high-consideration $10K offer. Fix: require cookie window to scale with offer price (30 days ≤ $1K, 60 days $1K-$5K, 90+ days > $5K).

3. **Tier structure missing** — Single flat commission rate. Top affiliates ignore flat-rate programs. Fix: require minimum 2 tiers with named differentiation (Tier 1 custom terms, Tier 2 standard, optional Tier 3 self-serve).

4. **Compliance template generic** — FTC disclosure mentioned but no actual template provided. Fix: require a copy-ready FTC disclosure block + W-9/W-8BEN collection process + affiliate agreement reference.

5. **Promotion assets listed, not delivered** — "3-5 email swipes" stated but no swipe copy. Fix: require actual asset drafts (or explicit handoff to `/email-sequence`) before the spec ships.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending) — required before the program ships to real affiliates
- **Ongoing:** Every 10 runs, sample 1 spec for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production external use without 2/3 blind test pass.*
