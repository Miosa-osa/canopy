# Pipeline

## Command
/pipeline [--stage <stage>] [--owner <agent>] [--health]

## Purpose
Display current pipeline status with deal progression, forecasting, and health metrics.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| --stage | string | No | Filter by stage: research, outreach, discovery, demo, proposal, negotiate, close |
| --owner | string | No | Filter by owning agent |
| --health | flag | No | Include pipeline health score and recommendations |

## Output
Genre: report
Format: Markdown table + metrics summary

Produces:
1. **Deal Table** -- all active deals with stage, value, MEDDPICC score, days in stage, next action
2. **Forecast Summary** -- commit/upside/best-case tiers with totals
3. **Health Metrics** (if --health): coverage ratio, velocity, conversion rates, stalled deals
4. **Recommended Actions** (if --health): top 3 actions to improve pipeline health

## Agent Activation
- **director** (wave 1): Pipeline analysis, forecasting, health assessment

## Process
```
1. Pull all active deals from pipeline state
2. Calculate stage distribution, total value, coverage ratio
3. Generate three-tier forecast (commit/upside/best case)
4. If --health: run pipeline health checks per director's framework
5. Output formatted report per director's Weekly Pipeline Report template
```

## Examples
```
/pipeline
/pipeline --stage discovery
/pipeline --health
/pipeline --owner closer --health
```
