# Prospect

## Command
/prospect <company_name> [--tier 1|2|3]

## Purpose
Research a target company, score against ICP, and generate an outreach plan.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| company_name | string | Yes | Company to research |
| --tier | integer | No | Research depth: 1 (quick), 2 (full), 3 (deep). Default: 2 |

## Output
Genre: research-brief + outreach-plan
Format: Markdown

Produces:
1. **Company Research Brief** -- per researcher's template at specified tier
2. **ICP Score** -- 10-point scoring with evidence per criterion
3. **Outreach Plan** -- recommended sequence, angle, first-touch draft email

## Agent Activation
1. **researcher** (wave 1): Company research at specified tier
2. **prospector** (wave 2): ICP scoring + outreach plan based on research
3. **copywriter** (wave 2): Draft first-touch email based on research brief

## Process
```
1. Researcher builds company profile at requested tier
2. Prospector scores against ICP framework (reference/icp.md)
3. If ICP score >= 7: full outreach plan + copywriter drafts first email
4. If ICP score 5-6: abbreviated plan, flag for director review
5. If ICP score < 5: no outreach. Report findings only.
```

## Examples
```
/prospect "Acme Corp"
/prospect "Acme Corp" --tier 3
/prospect "Stripe" --tier 1
```
