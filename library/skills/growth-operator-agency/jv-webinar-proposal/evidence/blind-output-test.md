# Blind Output Test — /jv-webinar-proposal

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **JV Webinar Proposal** (direct outreach to a potential partner). Classification: **external** — requires **2/3 evaluator pass** before sending to any real JV prospect. Unique to this skill: **evaluators must include real JV partners the creator has worked with** — no peer substitute will catch the nuance of "would I actually respond to this from a stranger."

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. **A past JV partner the creator has actually co-hosted a webinar with** (mandatory — they've received similar outreach from many sources; their gut reaction on "would I reply to this cold-ish proposal" is the real test. No substitute. If the creator has no past JV partners, the skill cannot be production-validated until one has been run.)
2. **A second JV partner or adjacent-tier creator in the same space** (someone who receives multiple JV proposals/month and has declined most — their "this is template" detector is calibrated by rejecting the other 20 this quarter)
3. **The creator themselves** (calibration on whether the opener personalization is accurate + the rev split + economics math is realistic for their actual business)

## Test Protocol

### 1. Output Set
- 2 historical JV proposals the creator has actually sent (with known outcomes — one accepted, one declined, if available)
- 3 proposals produced by `/jv-webinar-proposal` (different partner targets — e.g., one adjacent-tier peer, one larger audience, one niche-aligned)
- 1 generic-LLM proposal (control — template-feel outreach with fake personalization)

All outputs anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order. Evaluators (especially evaluator #1 — the real past JV partner) see full proposals — opener through CTA.

### 2. Evaluation Questions (per proposal)
For each proposal, evaluator answers:
1. "Did a real creator write this to me personally, or is it AI / template?"
   - `real-creator` / `template-or-ai` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text — especially note: did the opener feel researched or generic?)
4. "Would you respond to this?" yes / no / maybe
5. "Rate the personalized opener 1-10"
6. "Rate the economics math (is it realistic?) 1-10"
7. "Rate the ask (is it low-friction enough?) 1-10"

### 3. Pass Criteria
For `/jv-webinar-proposal` to be blind-test-validated:
- **≥ 2 of 3 Growth Operating Agency proposals** must have ≥ 1 evaluator say `real-creator` or `can't tell`
- **No generic-LLM proposal** should be identified as `real-creator`
- Average "Would you respond?" ≥ 60% yes for Growth Operating Agency proposals
- Average personalized-opener rating ≥ 7/10 (THE make-or-break metric for JV)
- Average economics-math rating ≥ 7/10
- Average ask rating ≥ 7/10
- **Critical:** Evaluator #1 (past JV partner) must NOT flag Growth Operating Agency proposals as template — their calibration is the hardest and most predictive

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Opener fake-personal ("I love your work" without a specific reference)
- Opener references partner's old work (WebFetch pulled stale content)
- Rev split ambiguous or missing
- Economics math fantasy numbers (partner audience × 50% attendance → laughable)
- Ask is commitment-heavy (expecting "yes to webinar" instead of "call to discuss")
- Multiple CTAs stacked
- Banned vocabulary (synergy / leverage / thought leader)
- No social proof of past JV success (when creator has any)

## Known Failure Modes (to watch for)

1. **Template-feel opener** — Skill produces "I love your content" without specific reference to a recent post, episode, or tweet. Past JV partner evaluator spots this in 3 seconds. Fix: Phase 1 Partner Research must WebFetch partner's last 30 days of content + proposal must cite a specific piece with specific detail.

2. **Stale reference** — Skill references partner's work from 2 years ago. Signals no real research. Fix: Phase 1 requires recency filter — reference must be from last 60 days.

3. **Rev split ambiguous** — Proposal says "let's figure out the split on a call." Too vague. Most partners won't reply. Fix: Phase 2 requires explicit rev split proposal (typically 50/50); reject if blank.

4. **Fantasy economics** — 50% attendance rate when industry norm is 25-40%, 10% close rate when this offer historically closes at 3%. Math looks rigorous but is wrong. Fix: Phase 3 requires historical-baseline citation from creator's own funnel data + partner audience size (verified not guessed).

5. **Commitment-heavy ask** — "Will you co-host a webinar with me?" instead of "20-min call to discuss." Too big for first touch. Fix: Phase 2 enforces low-friction CTA — Cal.com link to 20-min discovery call only.

6. **Stacked CTAs** — "Reply to this email OR book a call OR DM me on LinkedIn." Dilutes action. Fix: single-CTA validator.

7. **No social proof of past JVs (when creator has any)** — If creator has run JVs before with results, proposal omits them. Credibility loss. Fix: Phase 2 checks for past-JV case studies in `company.yaml` partnerships compartment; include if any exist.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending — requires past JV partner recruitment; skill CANNOT ship to production-use until evaluator #1 participates)
- **Ongoing:** Every 10 proposals sent, sample 1 for blind-test review with a fresh past-JV-partner evaluator
- **Drift check:** Quarterly full panel re-test
- **Low-response-rate-triggered:** If < 30% response rate across 10+ sent proposals, rerun blind test before next batch
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment (past JV partner evaluator is the critical recruit)

---
*Per INV-14 — no skill ships to production external use without 2/3 blind test pass. JV proposals specifically require a past-JV-partner evaluator — peer substitutes don't match the calibration of someone who has actually received and rejected template outreach.*
