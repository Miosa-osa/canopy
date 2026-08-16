# /rethink

> Synthesize accumulated observations into actionable insights when evidence is sufficient.

## Usage
```
/rethink "<topic>" [--force]
```

## What It Does
Takes a topic with accumulated observations (from `/remember`) and synthesizes them into a coherent insight, pattern, or process improvement. Only activates when confidence >= 1.5 (enough evidence). Use `--force` to override the threshold.

## Implementation
Runs: `cd engine && mix optimal.rethink "<topic>" [--force]`

Process:
1. Load all observations tagged with the topic.
2. Check confidence threshold (>= 1.5).
3. Cluster observations by sub-theme.
4. Synthesize into actionable insight.
5. Store synthesis result.
6. Archive processed observations.

## Examples
```bash
# Synthesize observations about a topic
/rethink "process"

# Override confidence threshold
/rethink "people" --force

# Check what topics are ready for synthesis first
/remember --escalations
```
