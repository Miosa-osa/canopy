# Blind Output Test — /build-sop

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **Standard Operating Procedure (SOP)**. Classification: **internal** — requires **1/3 evaluator pass**.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. A team member who currently executes the role/process being SOP'd (the person who would read and follow this doc day-to-day)
2. A seasoned Ops Manager from a peer creator's team (has seen 20+ SOPs across businesses)
3. A recently onboarded hire (< 90 days tenure) who can test whether the SOP is actually executable by a new person

## Test Protocol

### 1. Output Set
- 2 SOPs produced by the creator or their ops lead (historical, for any of the 14 variants)
- 3 SOPs produced by `/build-sop` (different variants: e.g., Setter + Content Mgr + CS)
- 1 generic-LLM SOP (control — ChatGPT prompted with "Write an SOP for a Setter role")

All SOPs anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per SOP)
For each SOP, evaluator answers:
1. "Did a creator/ops team produce this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Could a new hire execute from this doc alone?" yes / no / with revisions
5. "Rate the Phase-by-Phase Workflow 1-10" (are DONE criteria clear?)
6. "Rate the KPIs 1-10" (are they numeric + time-bound?)

### 3. Pass Criteria
For `/build-sop` to be blind-test-validated:
- **≥ 1 of 3 Growth Operating Agency SOPs** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM SOP** should be identified as `creator`
- Average "Could a new hire execute?" score ≥ 50% yes
- Average Phase-by-Phase rating ≥ 7/10
- Average KPI rating ≥ 7/10 (numeric + time-bound check)

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Ambiguous DONE criteria per phase (vague "when ready" vs specific "when X is in CRM with tag Y")
- Non-numeric KPIs leaked through ("fast response" vs "< 5 min 95%")
- Tools referenced generically ("our CRM" vs "GoHighLevel, Pipeline A, stage 3")
- Missing escalation rules or timeframes
- Training plan skipped or hand-waved
- Banned vocabulary leaked through

## Known Failure Modes (to watch for)

1. **Ambiguous DONE criteria** — If phases end with "when done" instead of a checkable condition, SOP is not executable by a new hire. Fix: require every phase to declare a verifiable PASS signal (artifact exists, tag applied, count met).

2. **KPIs not numeric + time-bound** — "Good close rate" fails the operations director discipline. Fix: enforce format `[metric] [comparator] [number] [timeframe]` with rejection if any slot empty.

3. **Tools named generically** — "Use our CRM" fails. Fix: require tool name + specific pipeline/board/tag + link if possible.

4. **Missing escalation timeframe** — "Escalate if issue" fails. Fix: require `[condition] → [role] within [timeframe]`.

5. **Training plan hand-waved** — Week 1-4 progression skipped or vague. Fix: require week-by-week milestone + supervisor touchpoint cadence.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending)
- **Ongoing:** Every 20 runs, sample 1 SOP for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production internal use without 1/3 blind test pass.*
