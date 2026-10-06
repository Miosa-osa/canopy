# Blind Output Test — /case-study

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **Case Study**. The case study is a **sacred format** — it is public-facing, carries the creator's public credibility, and every buyer reads it before converting. Requires **3/3 evaluator pass** before the skill is considered blind-test-validated.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. A past client of the creator who has lived an authentic version of the outcome being described (knows whether the story reads true and isomorphic to their own journey)
2. A peer creator in the same niche whose audience has seen 50+ case studies (can spot generic-LLM phrasing and missing specificity)
3. A conversion copywriter / testimonial-video producer who has edited 100+ real case studies (knows the tells of fabricated vs raw-interview-sourced stories)

## Test Protocol

### 1. Output Set
- 2 case studies produced by the creator or their conversion copywriter (historical, ideally ones that converted well)
- 3 case studies produced by `/case-study` (different clients, different outcome archetypes)
- 1 generic-LLM case study (control — ChatGPT prompted with client name + outcome, no Growth Operating Agency context)

All case studies anonymized. Strip client names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per case study)
For each case study, evaluator answers:
1. "Did a creator/copywriter produce this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you publish this as-is to paid traffic?" yes / no / with revisions
5. "Rate the Before-State (4-layer pain) 1-10" (does it sound like a real person's actual words?)
6. "Rate the Implementation + Journey 1-10" (is the mechanism traceable and believable?)

### 3. Pass Criteria
For `/case-study` to be blind-test-validated:
- **≥ 3 of 3 Growth Operating Agency case studies** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM case study** should be identified as `creator` (if so, re-calibrate test; skill is not yet ready)
- Average "Would you publish as-is?" score ≥ 70% yes for Growth Operating Agency case studies
- Average Before-State rating ≥ 7/10
- Average Implementation + Journey rating ≥ 7/10

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Before-state reads generic (missing verbatim client quotes from raw interview)
- Outcome numbers feel round/fabricated (no cohort context, no timeframe precision)
- Implementation steps generic (not tied to the specific mechanism the offer teaches)
- Advice-to-past-self hollow (philosophical vs specific action)
- Bridge-to-prospect missing (no mapping from this client's starting situation to ICP)
- Banned vocabulary leaked through
- Non-isomorphic fit slipped through (client's starting situation unlike ICP)

## Known Failure Modes (to watch for)

1. **Non-isomorphic client selected** — Hero case study uses a billionaire-resourced client on a $50K-MRR-creator's sales page. Prospects feel the gap. Fix: enforce Phase 3 Isomorphic Fit Verification as a hard gate; if fit fails, route to aggregate testimonial only.

2. **Raw interview skipped** — Skill fabricates quotes without a real recorded interview. Reads generic and carries FTC risk. Fix: require an interview-transcript attachment or a verifiable testimonial source before section 2 (Before State) writes.

3. **Outcome numbers unsourced** — "Doubled revenue in 90 days" without a source. Fix: require every outcome number to reference its source artifact (Stripe statement, CRM export, client screenshot) and date.

4. **Mechanism thread broken** — Client's implementation does not map to the offer's actual mechanism sub-steps. Breaks the prospect's ability to see their own path. Fix: require Phase 4 to name the exact mechanism sub-steps from the Offer Doc.

5. **FTC + client approval skipped** — Publishes without FTC disclaimer or written client approval. Legal and trust risk. Fix: require Phase 6 approval file attached before output writes to `output/`.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending) — required before any case study goes to paid traffic
- **Ongoing:** Every 5 runs, sample 1 case study for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production sacred-format use without 3/3 blind test pass.*
