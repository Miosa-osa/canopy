# Close Plan

## Command
/close-plan <deal_name> [--target-date <date>]

## Purpose
Generate a mutual action plan (MAP) with customer-side milestones, internal milestones, risk assessment, and timeline to close.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| deal_name | string | Yes | Name of the deal |
| --target-date | date | No | Target close date (ISO 8601). If omitted, estimates from deal context. |

## Output
Genre: plan
Format: Markdown (Mutual Action Plan template)

Produces:
1. **Mutual Action Plan** -- ordered milestones with owner (us/them/both) and dates
2. **Dependencies** -- what must happen before what
3. **Risk Assessment** -- identified risks with probability and mitigation
4. **Decision Criteria Alignment** -- how each criterion will be addressed and when
5. **Negotiation Boundaries** -- suggested walk-away points and trade levers

## Agent Activation
1. **closer** (wave 1): MAP generation, risk assessment, negotiation strategy
2. **director** (wave 1): Discount authority confirmation, strategic review

## Process
```
1. Pull MEDDPICC scorecard for the deal
2. Verify all 8 letters score >= 2 (prerequisite for close plan)
3. If any letter < 2: return gap warning, recommend /qualify first
4. Map decision process milestones backward from target close date
5. Add internal milestones (proposal, legal review, contract generation)
6. Identify risks from MEDDPICC gaps and deal history
7. Generate negotiation guardrails per discount authority matrix
8. Output complete MAP per closer's template
```

## Examples
```
/close-plan "Acme Corp Enterprise Deal"
/close-plan "Acme Corp" --target-date 2026-06-30
```
