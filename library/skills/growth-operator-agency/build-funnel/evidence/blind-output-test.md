# Blind Output Test — /build-funnel

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **Funnel a longevity-protocol**. Classification: **external** — requires **2/3 evaluator pass** before paid traffic launches against the funnel.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. A funnel architect with multi-archetype experience (the growth engineer / the operations director / the backend economist / the paid media director lineage preferred)
2. A paid-acquisition operator who has run 3:1+ LTV:CAC at $500K+/mo on similar offers
3. A sales-ops lead who can audit dependency chain + tracking plan for operational completeness

## Test Protocol

### 1. Output Set
- 2 historical Funnel Blueprints produced by the creator's team or a hired strategist
- 3 Funnel Blueprints produced by `/build-funnel` (different archetypes across different creator contexts)
- 1 generic-LLM funnel blueprint (control — no compartments, no offer doc integration)

All blueprints anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per blueprint)
For each blueprint, evaluator answers:
1. "Did a strategist/team produce this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you launch paid traffic against this funnel?" yes / no / with revisions
5. "Rate the Archetype Selection reasoning (Section 1) 1-10"
6. "Rate the Dependency Chain completeness (Section 6) 1-10"
7. "Would the economics cross-check survive real traffic?" PASS / FAIL

### 3. Pass Criteria
For `/build-funnel` to be blind-test-validated (external tier 2/3):
- **2/3 Growth Operating Agency blueprints** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM blueprint** should be identified as `creator`
- Average "Would you launch?" score ≥ 60% yes for Growth Operating Agency blueprints
- Average Archetype reasoning rating ≥ 7/10
- Average Dependency Chain rating ≥ 7/10
- Economics cross-check PASS on 2/3 blueprints

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Archetype mismatched to offer price / team capability / distribution mix
- Missing stages (no confirmation page for call funnel → show-rate leak predicted)
- Tracking plan vague (no UTM taxonomy, no event list, no attribution window)
- Dependency chain incomplete (VSL listed but no landing page, or vice versa)
- Economics cross-check hand-waved (CAC not channel-specific)
- Missing the operations director 8-stage audit plan (no leak-detection mechanism)
- No the paid media director show-rate stack for call funnels
- Banned vocabulary leaked through

## Known Failure Modes (to watch for)

1. **Wrong archetype for the offer** — Application funnel on a $497 product (over-friction) or VSL funnel on a $50K DFY offer (under-qualification). Fix: Decision Tree is hard-coded to offer price + team capability; document reasoning in Appendix A.

2. **Missing confirmation page / SMS cadence** — Call funnel launched without the paid media director show-rate stack → 40% show-rate instead of 70%+. Fix: Archetype 3/4/7 (call funnels) must include confirmation page + 4-touch SMS cadence.

3. **Tracking plan vague** — "We'll use Meta pixel" without UTM taxonomy or event list. Fix: Phase 5 requires full UTM / event table / pixel setup / attribution window specification.

4. **Economics cross-check mismatch** — Funnel CAC estimate doesn't match Offer Doc LTV:CAC gate. Fix: Phase 7 hard gate — pull Offer Doc numbers + validate against channel mix.

5. **Dependency chain gaps** — VSL listed but landing page not; email automation but no tracking. Fix: Phase 6 — enumerate every asset with owner + status before launch.

6. **Challenge funnel launched without community** — Archetype 6 selected but Skool/Circle/FB not active. Fix: Tacit Principle 5 — require live community infrastructure before Challenge archetype ships.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending) — test at least 2 archetypes (VSL + Application minimum)
- **Ongoing:** Every 10 runs, sample 1 blueprint for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test
- **Post-launch validation:** Weekly the operations director 8-stage audit on live funnels (separate from blind-test)

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production external use without 2/3 blind test pass. Funnel blueprint is the connective tissue — broken blueprint = leaky bucket across every other asset.*
