# Blind Output Test — /referral-program

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **Referral Program Specification**. Classification: **external** (published and read by real customers) — requires **2/3 evaluator pass**.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. An existing referral program operator (has run a ReferralCandy / Rewardful customer-referral program for 12+ months and knows what triggers actually convert existing customers into referrers)
2. A lifecycle / CS leader with direct experience running first-win, NPS-9, and renewal-based referral asks
3. A premium-customer advocate (someone who has personally referred 5+ friends into high-ticket programs) who can evaluate whether the reward structure and ask cadence feel right

## Test Protocol

### 1. Output Set
- 2 referral program specs produced by the creator or peer creator's lifecycle team (historical)
- 3 referral program specs produced by `/referral-program` (different offer tiers: mid-ticket / high-ticket / continuity)
- 1 generic-LLM spec (control — ChatGPT prompted with "Design a customer referral program for a coaching business")

All specs anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per spec)
For each spec, evaluator answers:
1. "Did a lifecycle team produce this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you roll this out to your customer base?" yes / no / with revisions
5. "Rate the Reward Structure 1-10" (fits offer tier, matches buyer psychology)
6. "Rate the Triggers 1-10" (timed correctly, paired with right moments in journey)

### 3. Pass Criteria
For `/referral-program` to be blind-test-validated:
- **≥ 2 of 3 Growth Operating Agency specs** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM spec** should be identified as `creator`
- Average "Would you roll out?" score ≥ 60% yes
- Average Reward rating ≥ 7/10
- Average Triggers rating ≥ 7/10

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Cash reward on a high-ticket program (feels transactional to premium buyers; perks > cash)
- Triggers clustered at wrong moments (referral asks pre-first-win convert poorly)
- k-factor target unrealistic (most programs 0.1-0.5; anything > 1 stated without basis is fabricated)
- Communication cadence lacks share-assets (referrer receives an ask but no message template or landing page)
- Tracking wire-up vague (no CRM tag, no referral-link format spec)
- Banned vocabulary leaked through
- Overlap with affiliate program not distinguished (referral = customer-origin, affiliate = commercial partner)

## Known Failure Modes (to watch for)

1. **Reward-pattern mismatch to offer tier** — Cash payout on a $20K mastermind signals transactional instead of relational. Fix: require reward-pattern selection to reference offer price; high-ticket defaults to perks or exclusive access.

2. **Triggers mis-timed** — Referral ask sent pre-first-win produces near-zero conversion. Fix: require post-first-win (Day 7-14 post-milestone) as the primary trigger; NPS-9 and testimonial-capture as secondary.

3. **k-factor fabricated** — Target k = 1.5 stated without basis. Most real programs 0.1-0.5. Fix: require k-factor target to reference historical per-customer invite count + conversion baseline, or explicit note that the target is aspirational with named assumption.

4. **Communication missing assets** — Trigger fires but no actual email copy + share-asset (share link, suggested referrer message, referee landing page). Fix: require each trigger row to attach or hand off to `/email-sequence` for copy.

5. **Overlap with affiliate program** — Spec blurs into commercial-affiliate territory (Tier 1 partners, W-9 collection). Fix: enforce customer-referral scope; if scope expands, recommend `/affiliate-program` instead.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending) — required before the program ships to real customers
- **Ongoing:** Every 10 runs, sample 1 spec for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production external use without 2/3 blind test pass.*
