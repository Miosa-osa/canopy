# Blind Output Test — /retention-check

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **Retention / Client Health Report**. Classification: **internal** — requires **1/3 evaluator pass**.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. A CS team member who currently manages the client roster (knows individual clients, their trajectories, and real health signals)
2. A fractional CS/Ops leader in the creator's network (has built retention systems at 3+ coaching/agency businesses)
3. A churn-analyst or lifecycle strategist with experience scoring health rubrics across portfolios

## Test Protocol

### 1. Output Set
- 2 retention reports produced by the creator's CS team (historical QBRs or weekly health reviews)
- 3 retention reports produced by `/retention-check` (different roster sizes / periods)
- 1 generic-LLM report (control — ChatGPT prompted with "Write a client retention report with health scores")

All reports anonymized. Strip client names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per report)
For each report, evaluator answers:
1. "Did a CS team produce this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you act on the Critical / At-Risk interventions listed?" yes / no / with revisions
5. "Rate the Health Score Rubric 1-10" (dimensions weighted sensibly, signals real)
6. "Rate the Intervention Playbook 1-10" (actions specific, owners named, deadlines realistic)

### 3. Pass Criteria
For `/retention-check` to be blind-test-validated:
- **≥ 1 of 3 Growth Operating Agency reports** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM report** should be identified as `creator`
- Average "Would you act on interventions?" score ≥ 50% yes
- Average Rubric rating ≥ 7/10
- Average Intervention rating ≥ 7/10

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Health scores feel arbitrary (no traceable signal source)
- Intervention actions generic ("check in with them" vs specific "creator call within 48h re: mechanism plateau")
- Thriving clients not flagged for `/case-study` capture
- Churn risk classification boundaries not explained
- Missing 30/60/90-day trending
- Banned vocabulary leaked through

## Known Failure Modes (to watch for)

1. **Scoring from vibes** — Skill assigns scores without citing a signal per dimension (login count, NPS reply, payment record). Fix: require every dimension score to reference its signal source in a footnote.

2. **Intervention actions generic** — "Check in" instead of "Creator personal call re: [specific blocker] within 48h." Fix: require action + owner + deadline + root-cause hypothesis for every Critical/At-Risk client.

3. **Thriving clients not captured** — Report ends with "Thriving: N clients" without routing each to `/case-study`. Fix: require Thriving block to name each client + case-study readiness + testimonial status.

4. **Trending missing** — Single-period snapshot with no 30/60/90 comparison. Fix: require trending block showing score movement; flag any dimension declining across 3+ clients.

5. **Banned vocabulary** — "Boost engagement" or similar leaked through. Fix: run BANNED-VOCABULARY filter before ship.

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
