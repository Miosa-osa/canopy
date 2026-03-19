# Ideal Customer Profile Framework

> This document defines who we sell to. Every prospect is scored against this
> framework before outreach begins. Load at boot.

## ICP Definition

### Firmographic Criteria

| Attribute | Ideal Range | Weight |
|-----------|------------|--------|
| Company Size | 50-500 employees | High |
| Annual Revenue | $5M-$100M | High |
| Industry | B2B SaaS, FinTech, HealthTech, MarTech | High |
| Geography | North America, Western Europe | Medium |
| Funding Stage | Series A through Series C | Medium |
| Growth Rate | 20%+ YoY headcount growth | Medium |

### Technographic Criteria

| Attribute | Signal | Weight |
|-----------|--------|--------|
| Cloud-native stack | AWS/GCP/Azure adoption | High |
| Modern dev practices | CI/CD, microservices, containers | High |
| API-first architecture | Public API, integrations | Medium |
| Data infrastructure | Data warehouse, analytics tools | Medium |

### Behavioral Criteria

| Attribute | Signal | Weight |
|-----------|--------|--------|
| Active hiring in our space | Job postings mentioning relevant roles/tools | High |
| Tech blog or conference presence | Engineering blog, conference talks | Medium |
| Open source contributions | GitHub activity, community participation | Low |
| Vendor evaluation signals | G2 searches, review activity | High |

## Scoring Rubric

Score each prospect 0 or 1 on these 10 criteria:

| # | Criterion | 1 Point If... |
|---|-----------|--------------|
| 1 | Company size in range | 50-500 employees |
| 2 | Industry match | One of our target verticals |
| 3 | Revenue in range | $5M-$100M estimated |
| 4 | Tech stack fit | Cloud-native with modern practices |
| 5 | Growth signals | Recent funding, hiring spree, or product launch |
| 6 | Pain signal present | Job postings or reviews mention our problem space |
| 7 | Decision maker accessible | Can identify and reach economic buyer via LinkedIn |
| 8 | No vendor lock-in | Not in multi-year contract with direct competitor |
| 9 | Geography fit | NA or Western Europe timezone coverage |
| 10 | Timing signal | Fiscal year start, initiative announcement, trigger event |

## Score Interpretation

| Score | Label | Action |
|-------|-------|--------|
| 8-10 | Tier 1 -- Ideal | Full 21-day multi-touch sequence, Tier 2 research |
| 6-7 | Tier 2 -- Good Fit | Standard sequence, Tier 1 research |
| 4-5 | Tier 3 -- Marginal | Abbreviated sequence, monitor for signal changes |
| 0-3 | Disqualified | Do not pursue. Log reason for exclusion. |

## Anti-Patterns (Do Not Pursue)

- Companies under 20 employees (no budget, no process)
- Companies over 5,000 employees (enterprise sales cycle, need different motion)
- Government agencies (different procurement, not our strength)
- Companies in active M&A (decisions frozen)
- Companies that just signed a competitor within last 12 months

## ICP Evolution

Review and update this framework quarterly based on:
- Win/loss analysis: who actually closes vs who we thought would
- Expansion revenue: which customers grow fastest after signing
- Churn data: which segments have highest retention
- Market shifts: new verticals showing demand signals
