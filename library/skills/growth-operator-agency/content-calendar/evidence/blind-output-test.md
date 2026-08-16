# Blind Output Test — /content-calendar

> Per `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. This skill produces a **30-Day Content Calendar**. Classification: **external** — requires **2/3 evaluator pass**. The calendar briefs every downstream writing skill — if the pillar allocation or conversion bridge is wrong, 30 days of downstream content inherits the failure.

## Test Date(s)

_v1.0 initial validation: pending (skill is freshly shipped)_

## Evaluator Roster (to recruit)

1. A content strategist with multi-platform experience (the content OS director / the VSL director / the stories director lineage preferred)
2. A social-ops lead who executes calendars and knows what actually ships vs fantasy plans
3. A past buyer or engaged follower who consumes the creator's content — gauge topic-resonance + Big Enemy fit

## Test Protocol

### 1. Output Set
- 2 historical content calendars produced by the creator's team
- 3 content calendars produced by `/content-calendar` (different creator contexts, different active-channel mixes)
- 1 generic-LLM content calendar (control — no compartments, no ICP integration)

All calendars anonymized. Strip creator names, replace brand names with `[BRAND]`, randomize order.

### 2. Evaluation Questions (per calendar)
For each calendar, evaluator answers:
1. "Did a strategist/team produce this, or an AI system?"
   - `creator` / `system` / `can't tell`
2. "How confident?" 1-5
3. "What tipped you off?" (open text)
4. "Would you execute this calendar?" yes / no / with revisions
5. "Rate the Pillar Ratio enforcement (40/30/20/10 balance) 1-10"
6. "Rate the Per-Post Brief quality (topic + hook seed + skill routing) 1-10"
7. "Does the calendar feel like the creator or generic?" creator / generic / mixed

### 3. Pass Criteria
For `/content-calendar` to be blind-test-validated (external tier 2/3):
- **2/3 Growth Operating Agency calendars** must have ≥ 1 evaluator say `creator` or `can't tell`
- **No generic-LLM calendar** should be identified as `creator`
- Average "Would you execute this?" score ≥ 60% yes
- Average Pillar Ratio rating ≥ 7/10
- Average Per-Post Brief rating ≥ 7/10

### 4. Post-Test Analysis
Patterns to look for on any failures:
- Pillar imbalance (too much How-To, too little Myth-Bust — Big Enemy disappears)
- Over-trend content (> 10% trend)
- Platform cadence violations (daily LinkedIn post — Dec 2025 algo penalty)
- Shorts systematized before 50+ long-form videos exist (the VSL director rule violation)
- Per-post briefs thin (topic only, no hook seed, no skill routing, no voice samples)
- Conversion stage imbalance (too much Awareness, too little Decision)
- Anchor-to-derivative repurpose chain missing
- Banned vocabulary in brief language

## Known Failure Modes (to watch for)

1. **Pillar ratio drift** — Weekly pillar allocation doesn't hold 40/30/20/10; Myth-Bust gets underweighted. Fix: weekly audit in Phase 4 + monthly audit in Phase 7.

2. **Big Enemy disappears** — Positioning Doc's Big Enemy doesn't surface weekly. Fix: Tacit Principle 9 — Big Enemy appears in at least one piece of content every 7 days (usually Myth-Bust).

3. **Shorts before 50 long-form** — Creator in bootstrap mode but calendar systematizes short-form. Fix: Tacit Principle 5 — honor the VSL director's Shorts Rule; long-form first.

4. **Per-post briefs too thin** — Slot lists topic only; no hook seed, no mechanism thread point, no voice samples. Fix: Phase 6 — every slot gets full brief (8 fields) before ship.

5. **Wrong platform cadence** — LinkedIn daily posts planned despite Dec 2025 algo change; TikTok 1/week when framework calls for 3-5/week. Fix: Platform-Specific Cadence table is hard-coded.

6. **No repurpose chain** — YouTube anchor has no derivative Reels/posts/email planned. Fix: Tacit Principle 3 — one anchor per week, repurposed; `/repurpose` routing must be specified.

7. **Channel fantasy** — Calendar plans for LinkedIn + X + YouTube + TikTok + IG simultaneously when creator has 0 active channels marked. Fix: Phase 1 — only plan for compartment 6 active: true channels.

## Production Validation Cadence

- **Baseline test:** At skill v1.0 launch (pending)
- **Ongoing:** Every 10 runs, sample 1 calendar for blind-test review
- **Drift check:** Quarterly full panel re-test
- **Change-triggered:** After any edit to SKILL.md Decision Logic, Tacit Principles, or Process, rerun baseline test
- **Post-execution validation:** After 30 days, review actual-vs-planned pillar ratio + downstream conversion delivered

## Revision Log

### v1.0 — 2026-04-19
- Initial skill shipped
- Blind-test baseline pending — requires evaluator recruitment

---
*Per INV-14 — no skill ships to production external use without 2/3 blind test pass. Cycle 3 planning layer — briefs downstream writing skills.*
