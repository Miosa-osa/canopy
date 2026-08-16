---
name: build-sop
description: Produce a Standard Operating Procedure for a role or process (14 variants — 8 roles: Setter/Closer/SDR/Content-Mgr/Video-Editor/CS/VA/Marketing-Mgr + 6 processes: Sales/Content/Onboarding/Lead-Mgmt/QA/Reporting). the operations director's straight growth operating process methodology. Produces SOP + KPIs + quality gates + escalation rules + training plan.
signal:
  mode: linguistic
  genre: sop
  type: inform
  format: markdown
  structure: w-sop-standard
  receiver: team member executing the role/process
  receiver_capacity: medium
department: scale
agent_affinity: [scale-head, sop-builder]
required_compartments:
  audience_intelligence_system: 30
  offer_architecture: 50
  conversion_sales: 30
  operational_intelligence: 30
upstream_dependency: design-offer
execution_mode: interactive
tier: structured_ai
temperature_gate: warm
required_tools: [file_read, file_write]
required_mcps: [filesystem, notion]
required_integrations:
  project_mgmt: notion-api
  crm: gohighlevel-api
credentials_required: [NOTION_API_KEY, GHL_API_KEY]
evidence_gate:
  - variant_selected
  - full_process_mapped_phase_by_phase
  - kpis_specified
  - quality_gates_declared
  - escalation_rules
  - training_plan
  - signal_score_gte_0_8
keywords:
  - SOP
  - standard operating procedure
  - process doc
  - team SOP
priority: 1
version: 1.0
---

# /build-sop — Standard Operating Procedure Builder

## Role

Produce deterministic SOPs for roles and processes. Lineage: **the operations director** (straight growth operating process), **Scale department Department** (14 SOP variants), Agency Execution OS.

## The 14 Variants

**8 Role SOPs:**
1. Setter — lead qualification + booking
2. Closer — sales call execution
3. SDR / Dialer — outbound + phone triage
4. Content Manager — content production orchestration
5. Video Editor — editing workflow + asset delivery
6. Customer Success — post-purchase onboarding + retention
7. VA / Admin — general operations assistant
8. Marketing Manager — campaign orchestration

**6 Process SOPs:**
1. Sales Process — end-to-end sales cycle
2. Content Production — idea → publish
3. Client Onboarding — sold → activated
4. Lead Management — opt-in → booked → closed tracking
5. Quality Assurance — output review gates
6. Reporting — weekly/monthly metrics cadence

## Output Structure

```
W(sop) =
  1. Role/Process Definition + Outcome
  2. Inputs (what triggers this, what they receive)
  3. Phase-by-Phase Workflow (numbered steps)
  4. Quality Gates (per phase — PASS criteria)
  5. KPIs (metrics that define good performance)
  6. Tools + Systems (what they use)
  7. Escalation Rules (when to escalate + to whom)
  8. Training Plan (how to onboard new person into role)
  9. Continuous Improvement (review cadence)
```

## Decision Logic

### Variant Selection
Per team structure and gap identified. Or `--variant=<role>|<process>`.

### the operations director's 8-Stage Customer Journey (Sales Process SOP)
1. Traffic cost + quality
2. Landing page
3. Application / opt-in
4. TY / confirmation page
5. Setter response time (< 5 min)
6. Pre-call nurture
7. On-call execution
8. Post-purchase experience

### KPI Specification (per role/process)
- **Setter:** response time, show-rate, qualification accuracy, calls booked/day
- **Closer:** close rate, AOV, refund rate, follow-up discipline
- **SDR:** calls/day, connect rate, booked/week
- **Content Mgr:** posts published/week vs plan, engagement delta, production cycle time
- **Video Editor:** turnaround time, revision rounds, output quality score
- **CS:** NPS, retention rate, upsell conversion, first-response time
- **VA:** task completion rate, response SLA
- **Marketing Mgr:** CAC, LTV:CAC, channel ROI, campaign launch velocity

## Tacit Principles

1. **SOPs are written FOR the new hire.** If a new person can't execute from the doc, SOP is incomplete.

2. **Every phase has a DONE criterion.** Ambiguous completion = process drift.

3. **KPIs numeric + time-bound.** "Fast response" fails. "< 5 min response 95% of the time" succeeds.

4. **Escalation rules prevent bottleneck.** Name who escalation goes to + in what timeframe.

5. **Tools are named explicitly.** "Use our CRM" fails. "GoHighLevel, specific pipeline, tag X on stage change."

6. **Training plan required.** SOP + training plan together. New hire should be 80%+ autonomous in 2 weeks.

7. **Review cadence non-optional.** Monthly SOP review catches drift.

8. **Version the SOP.** Changes logged. Last-revision-date at top.

## Process

### Phase 0 — Load
- Offer Doc, company.yaml compartment 11 (tech stack + team structure)
- Existing SOPs (if any) for consistency
- `reference/frameworks/growth-operating-process/README.md` (operations methodology)
- `reference/operators/operations-director.md`

### Phase 1 — Variant Selection
Per team gap or request.

### Phase 2 — Role/Process Definition
What does this role/process do? What outcome does it produce?

### Phase 3 — Inputs + Triggers
What starts the workflow? What inputs arrive?

### Phase 4 — Phase-by-Phase Workflow
Numbered steps. Each step:
- Action (what to do)
- Tool (where to do it)
- Time (target duration)
- Output (what's produced)

### Phase 5 — Quality Gates
Per phase, PASS/FAIL criteria. No phase ships without gate pass.

### Phase 6 — KPIs
Numeric + time-bound. Daily/weekly/monthly.

### Phase 7 — Tools + Systems
Named list + integration points.

### Phase 8 — Escalation Rules
"When [condition] → escalate to [role] within [timeframe]."

### Phase 9 — Training Plan
- Week 1: shadow existing + read SOP
- Week 2: execute with supervision
- Week 3: autonomous + daily review
- Week 4: full independence + KPI tracking

### Phase 10 — Review Cadence
Monthly SOP review. Quarterly deep audit.

## Output Format

```markdown
# SOP — [Role/Process Name]

**Variant:** [role: setter | closer | ...] or [process: sales | content | ...]
**Owner:** [role]
**Last Revision:** [date]
**Version:** 1.0

---

## 1. Definition + Outcome
[What this role/process does, what outcome it produces]

## 2. Inputs + Triggers
[What starts the workflow]

## 3. Phase-by-Phase Workflow
### Phase 1 — [Name]
- Action: [...]
- Tool: [specific tool]
- Time: [target]
- Output: [...]

### Phase 2 — [Name]
[...]

## 4. Quality Gates
| Phase | PASS Criteria | FAIL Action |
|---|---|---|
| 1 | [...] | [...] |

## 5. KPIs
| Metric | Target | Frequency |
|---|---|---|
| Response time | < 5 min 95% | Daily |

## 6. Tools + Systems
[named list]

## 7. Escalation Rules
[When → who → timeframe]

## 8. Training Plan
[Week 1-4 progression]

## 9. Continuous Improvement
- Monthly SOP review: [date]
- Quarterly audit: [date]

---

## Appendix A — Example executions
## Appendix B — Common failure modes + fixes
```

## Important Rules

- **NEVER ship SOP without DONE criteria per phase.**
- **NEVER use ambiguous KPIs** ("fast," "good," "reasonable").
- **ALWAYS name the tool specifically.**
- **ALWAYS include escalation rules.**
- **ALWAYS version the SOP.**

## Verification Checklist

- [ ] Variant selected
- [ ] Phase-by-phase workflow with DONE criteria
- [ ] Quality gates per phase
- [ ] KPIs numeric + time-bound
- [ ] Tools named explicitly
- [ ] Escalation rules
- [ ] 4-week training plan
- [ ] Review cadence
- [ ] Triple-layer S/N ≥ 0.8

## Next Skills

- `/hiring-brief` — hire into this role
- `/retention-check` — if CS SOP, feeds into retention tracking
- `/revenue-report` — if Reporting SOP, feeds revenue tracking

## References

- `reference/frameworks/growth-operating-process/README.md` (the operations director 8-stage journey)
- `reference/operators/operations-director.md`
- Scale department Department canonical

---
*v1.0 — 2026-04-19. Cycle 5 Scale.*
