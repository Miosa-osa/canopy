---
name: hiring-brief
description: Produce hiring brief for one of 8 roles (Setter / Closer / SDR / Content Manager / Video Editor / Customer Success / VA / Marketing Manager). Scorecard + ideal profile + outreach script + interview questions + 30/60/90-day plan. Revenue-threshold-aware (per the VSL director team model).
signal:
  mode: linguistic
  genre: hiring-brief
  type: inform
  format: markdown
  structure: w-hiring-brief
  receiver: creator + hiring manager + candidates
  receiver_capacity: medium
department: scale
agent_affinity: [scale-head, talent-recruiter]
required_compartments:
  offer_architecture: 50
  operational_intelligence: 30
upstream_dependency: build-sop
execution_mode: interactive
tier: structured_ai
temperature_gate: warm
required_tools: [file_read, file_write]
required_mcps: [filesystem]
required_integrations:
  job_boards: linkedin-jobs-api       # optional
  ats: greenhouse-api                  # optional
  crm: gohighlevel-api
credentials_required: [LINKEDIN_ACCESS_TOKEN, GHL_API_KEY]
evidence_gate:
  - role_selected
  - scorecard_5_plus_competencies
  - ideal_profile_specific
  - outreach_script_provided
  - interview_questions_5_plus_rounds
  - 30_60_90_plan_present
  - revenue_threshold_aligned
  - signal_score_gte_0_8
keywords:
  - hiring brief
  - hire setter
  - hire closer
  - hire VA
  - scorecard
priority: 1
version: 1.0
---

# /hiring-brief — 8-Role Hiring Brief Generator

## Role

Produce hiring briefs aligned to the VSL director's Revenue-Threshold Team Model. Lineage: **the VSL director** (solo → 3-8 → 10-20 → 20-40 A-players + 3-Strike System), **the growth engineer** (closer-recruitment playbook — headline + VSL + Typeform + 90s selfie + formal interview with role plays + EEOC compliance), **the acquisition economist** (A-player hiring in a lead-generation canon), **Scale department Team Builder**.

## The Revenue-Threshold Team Model (15-step VSL methodology)

| Revenue | Team | Key hires |
|---|---|---|
| $0-$30K MRR | Solo + 1 VA | VA (admin/scheduling) |
| $30K-$100K MRR | +2-3 | 1 Setter, 1 Video Editor, VA |
| $100K-$500K MRR | 3-8 | 2 Setters, 1 Closer, 1 Content Mgr, 1 Editor, VA, optional Marketing Mgr |
| $500K-$1M MRR | 10-20 | 4-6 Setters, 2-3 Closers, 1 SDR, 1 Content Mgr, 1-2 Editors, 1 CS, 1 Marketing Mgr |
| $1M+ MRR | 20-40 A-players | Full team + Ops Manager + Finance |

**the VSL director rule:** don't over-hire. Each role has a revenue threshold. Don't under-hire at scale.

## The 8 Role Variants

| # | Role | When to hire |
|---|---|---|
| 1 | **Setter** | When creator spending > 20% time on booking calls |
| 2 | **Closer** | When booking > 30 calls/week |
| 3 | **SDR / Dialer** | When outbound volume > Setter capacity |
| 4 | **Content Manager** | When content production > 10hr/week creator time |
| 5 | **Video Editor** | When Content Mgr exists + editing is bottleneck |
| 6 | **Customer Success** | When >20 active clients |
| 7 | **VA / Admin** | Day 1 — first hire always |
| 8 | **Marketing Manager** | When ad spend > $20K/mo or mixed channel complexity |

## Output Structure

```
W(hiring-brief) =
  1. Role Definition + Revenue Threshold Check
  2. Scorecard (5-8 competencies with measurable criteria)
  3. Ideal Profile (background / skills / culture fit)
  4. Compensation Structure (base + commission + bonus)
  5. Outreach Script (LinkedIn / job board copy)
  6. Screening Flow (the growth engineer 5-stage: Headline + VSL + Typeform + 90-sec selfie + Formal Interview)
  7. Interview Questions (5+ rounds of questions)
  8. Role Plays (scenario-based evaluation)
  9. 30/60/90-Day Plan (success milestones)
  10. Compliance + Legal Notes (EEOC, contractor vs employee, state-specific)
```

## Decision Logic

### Scorecard Competencies (role-specific)
**Setter:**
1. Response speed (< 5 min target)
2. Qualification accuracy (>80% booked calls qualify on-call)
3. Show-rate (>70% for booked qualified)
4. CRM discipline (clean data, tagged correctly)
5. Communication (DM tone, reply quality)

**Closer:**
1. Close rate (25%+ for qualified shows)
2. AOV consistency
3. Follow-up discipline (3-7 touches post no-close)
4. Objection handling depth
5. Discovery quality
6. Refund prevention (<5% refund rate)

**Content Manager:**
1. Production velocity (weekly post plan executed 95%+)
2. Engagement delta vs baseline
3. Repurposing ratio (1 anchor → 10+ derivatives)
4. Brand voice consistency
5. Platform analytics literacy

[per-role scorecards declared in output]

### Compensation Per Role (market-aligned)

| Role | Base | Commission | OTE |
|---|---|---|---|
| Setter | $3K-$4K/mo | 10% of closed deals from bookings | $60-$120K |
| Closer | $3K-$5K/mo | 15-20% of closed deals | $120-$300K |
| SDR | $3K-$5K/mo + $25-$50/show | N/A on closes (hand off to closer) | $60-$100K |
| Content Mgr | $4K-$8K/mo | bonuses on performance | $50-$120K |
| Video Editor | $2K-$4K/mo or per-video | N/A | $30-$60K |
| CS | $4K-$6K/mo | retention bonuses | $50-$90K |
| VA | $1K-$3K/mo | N/A | $15-$40K |
| Marketing Mgr | $5K-$10K/mo | campaign ROI bonuses | $80-$180K |

Adjust by geography (Philippines / India / US / EU).

### the growth engineer 5-Stage Screening
1. **Headline + VSL** (ad/post with video)
2. **Typeform application** (qualification + DQ criteria)
3. **90-second selfie video task** (tests commitment + personality + clarity)
4. **Formal Interview with Role Plays** (scenario-based evaluation)
5. **Paid Trial Week** (real work + observation)

### The 3-Strike System (15-step VSL methodology)
New hire gets 3 strikes:
- Strike 1: Private correction + documented
- Strike 2: Public (team) correction + documented
- Strike 3: Termination

Keeps standards without emotion-driven firing.

### EEOC Compliance (US hires)
- No protected-class questions
- Standard application criteria
- Equal opportunity statement in brief
- Document interview scores objectively

## Tacit Principles

1. **Hire for the role you have, not the role you want.** Don't hire a $200K Marketing Mgr at $50K MRR.

2. **VAs first.** Always. Frees creator time fastest per dollar.

3. **Setter before Closer.** Bookings must exist before closes to book.

4. **Specific > generic.** "3 years coaching sales closer experience at $3-10K AOV" > "sales experience."

5. **Commission-heavy for revenue roles.** Setter + Closer + SDR should feel revenue through pay.

6. **Paid trial > unpaid test.** Pay for a week of real work. Unpaid scares A-players away.

7. **Role play during interview reveals real skill.** Resumes lie. Role plays don't.

8. **30/60/90 plan non-optional.** New hire knows success targets. Manager knows evaluation gates.

9. **Document everything.** 3-Strike system requires paper trail.

10. **Don't hire to solve your own chaos.** Fix SOP first, then hire into the defined role.

## Process

### Phase 0 — Load
- company.yaml Compartment 11 (team structure, tech stack)
- Existing SOPs for the role
- `reference/operators/vsl-director.md` (Revenue-Threshold model + A-player hiring)
- `reference/operators/growth-engineer.md` (5-stage screening)

### Phase 1 — Revenue Threshold Check
Cross-check creator's revenue vs role's threshold. If mismatched, flag.

### Phase 2 — Role Definition
What they do, what outcomes, what they report on.

### Phase 3 — Scorecard
5-8 competencies with measurable criteria.

### Phase 4 — Ideal Profile
Background + skills + culture fit. Specific > generic.

### Phase 5 — Compensation
Base + commission + bonus + geography adjustment.

### Phase 6 — Outreach Script
LinkedIn / job board post copy. Hook + role + compensation + CTA.

### Phase 7 — Screening Flow (the growth engineer 5-stage)
- Headline + VSL brief
- Typeform questions
- 90-sec selfie prompt
- Formal interview questions + role plays
- Paid trial spec

### Phase 8 — Interview Questions
5+ rounds of questions per stage.

### Phase 9 — Role Plays
3-5 scenario-based tests for the specific role.

### Phase 10 — 30/60/90-Day Plan
Week-by-week milestones + KPIs.

### Phase 11 — Compliance
EEOC + contractor/employee + state-specific.

## Output Format

```markdown
# Hiring Brief — [Role] — [Creator Brand]

**Role:** [Setter | Closer | SDR | Content Mgr | Video Editor | CS | VA | Marketing Mgr]
**Revenue Threshold Check:** [PASS — at $X MRR, this role is appropriate]
**OTE:** $[N]-$[N]
**Version:** 1.0

---

## 1. Role Definition + Outcome
[what, outcome, who they report to]

## 2. Scorecard (5-8 competencies)
| Competency | Measurable Criteria | Weight |
|---|---|---|
| [Response speed] | < 5 min 95% | 20% |
[...]

## 3. Ideal Profile
- Background: [specific]
- Skills: [list]
- Culture fit: [3-5 traits]
- Deal-breakers: [3-5]

## 4. Compensation
- Base: $[N]/mo
- Commission: [formula]
- Bonus: [triggers]
- OTE: $[N]-[N]
- Geography: [adjustment notes]

## 5. Outreach Script
### LinkedIn Post / Job Board Copy
[hook + role + pay + CTA]

### Direct Outreach DM
[personalized template]

## 6. Screening Flow (the growth engineer 5-stage)

### Stage 1 — Headline + VSL
[ad brief + 60-90s VSL script]

### Stage 2 — Typeform Application
[qualification questions + DQ criteria]

### Stage 3 — 90-Second Selfie Video
[prompt: "Record a 90-second video answering X"]

### Stage 4 — Formal Interview
[5+ questions per round + role plays]

### Stage 5 — Paid Trial Week
[scope + compensation + observation criteria]

## 7. Role Plays (3-5 scenarios)
### Scenario 1 — [Name]
Setup: [...]
Evaluation criteria: [...]

[repeat]

## 8. 30/60/90-Day Plan

### Days 1-30 (Onboarding)
Week 1: shadow + read SOP
Week 2: supervised execution
Weeks 3-4: autonomous w/ daily review

### Days 31-60 (Ramp)
[milestones]

### Days 61-90 (Full Contribution)
[KPI targets]

## 9. Compliance
- EEOC: [equal opportunity statement]
- Contractor vs Employee: [1099 or W-2]
- State-specific: [notes if US]
- Background check: [yes/no]

## 10. 3-Strike System
- Strike 1: private + documented
- Strike 2: team + documented
- Strike 3: termination

---

## Appendix A — Interview scoring rubric
## Appendix B — Role play evaluation sheet
## Appendix C — Onboarding checklist
```

## Important Rules

- **NEVER hire without revenue threshold check** (over-hiring kills margin).
- **NEVER unpaid trial** for real work.
- **ALWAYS use 5-stage the growth engineer screening** for commercial roles.
- **ALWAYS document interview scores** (3-strike requires paper trail).
- **ALWAYS include 30/60/90 plan.**
- **ALWAYS EEOC-comply** for US hires.

## Verification Checklist

- [ ] Role selected + revenue threshold cross-checked
- [ ] Scorecard 5-8 competencies with measurable criteria
- [ ] Ideal profile specific
- [ ] Compensation structured (base + commission + bonus)
- [ ] Outreach script
- [ ] 5-stage screening flow
- [ ] 5+ interview questions
- [ ] 3-5 role plays
- [ ] 30/60/90 plan
- [ ] Compliance
- [ ] Triple-layer S/N ≥ 0.8

## Next Skills

- `/build-sop` — SOP for the role being hired (if not yet exists)
- `/retention-check` — if CS hire, feeds retention tracking
- `/revenue-report` — team hires impact P&L

## References

- `reference/operators/vsl-director.md` (Revenue-Threshold Team Model + A-player hiring)
- `reference/operators/growth-engineer.md` (closer-recruitment playbook — 5-stage screening)
- `reference/operators/acquisition-economist.md` (a lead-generation canon — hiring standards)

---
*v1.0 — 2026-04-19. Cycle 5 Scale.*
