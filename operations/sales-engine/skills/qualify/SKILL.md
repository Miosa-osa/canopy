# Qualify

## Command
/qualify <deal_name>

## Purpose
Run MEDDPICC scoring on a deal with gap analysis and prescribed next actions.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| deal_name | string | Yes | Name of the deal to qualify |

## Output
Genre: scorecard
Format: Markdown (MEDDPICC Scorecard template)

Produces:
1. **MEDDPICC Scorecard** -- 0-3 score per letter with evidence and gaps
2. **Overall Score** -- percentage with strong/moderate/weak assessment
3. **Critical Gap** -- the #1 gap that will kill the deal if unaddressed
4. **Prescribed Actions** -- ordered list of actions to improve qualification
5. **Stage Recommendation** -- should this deal advance, hold, or retreat?

## Agent Activation
- **closer** (wave 1): MEDDPICC scoring and gap analysis

## Process
```
1. Pull deal context: all known information, meeting notes, prospect data
2. Score each MEDDPICC letter 0-3:
   0 = Unknown (no data)
   1 = Identified (mentioned but unverified)
   2 = Validated (confirmed in conversation)
   3 = Confirmed with evidence (documented, multi-sourced)
3. Calculate overall percentage: (sum / 24) * 100
4. Identify weakest letter as critical gap
5. Generate prescribed actions targeting the top 2-3 gaps
6. Recommend stage action: advance (>= 60%), hold (40-59%), retreat (< 40%)
```

## Examples
```
/qualify "Acme Corp Enterprise Deal"
/qualify "Stripe Platform Integration"
```
