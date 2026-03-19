# Battlecard

## Command
/battlecard <competitor_name> [--refresh]

## Purpose
Generate or update a competitive battlecard with positioning, strengths/weaknesses, pricing intelligence, landmine questions, and objection responses.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| competitor_name | string | Yes | Competitor to analyze |
| --refresh | flag | No | Force refresh even if battlecard exists and is recent |

## Output
Genre: battlecard
Format: Markdown (Competitive Battlecard template)

Produces:
1. **Competitive Profile** -- positioning, reality, market presence
2. **Strengths/Weaknesses** -- verified with sources and ratings
3. **Pricing Intelligence** -- model, range, source, confidence
4. **Win/Loss Scenarios** -- when they win vs when we win
5. **Landmine Questions** -- questions to plant in discovery that expose their weaknesses
6. **Objection Responses** -- what to say when prospect brings them up

## Agent Activation
1. **researcher** (wave 1): Competitive intelligence gathering and verification
2. **copywriter** (wave 2): Objection response copy and positioning language

## Process
```
1. Check if existing battlecard exists and is < 30 days old (skip research if current)
2. If --refresh or stale: researcher gathers fresh competitive intel
3. Verify all claims against independent sources
4. Rate every data point with source reliability (A-E)
5. Copywriter crafts objection responses and landmine question phrasing
6. Output complete battlecard per researcher's template
```

## Examples
```
/battlecard "Competitor X"
/battlecard "Competitor X" --refresh
```
