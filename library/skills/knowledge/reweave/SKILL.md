# /reweave

> Find stale contexts about a topic and suggest updates.

## Usage
```
/reweave "<topic>" [--days <n>]
```

## What It Does
Scans all context files mentioning a topic, checks when they were last updated, compares against recent signals, and identifies stale or contradictory information. Suggests specific updates to bring contexts current.

## Implementation
Runs: `cd engine && mix optimal.reweave "<topic>" [--days <n>]`

Process:
1. Find all files mentioning the topic.
2. Check last-modified dates.
3. Compare stored facts against recent signals.
4. Identify contradictions, outdated info, missing updates.
5. Suggest specific edits with before/after.

Default staleness threshold: 30 days. Override with `--days`.

## Examples
```bash
# Check if Ed Honour contexts are current
/reweave "Ed Honour"

# Check with custom staleness threshold
/reweave "pricing" --days 60

# Reweave a broad topic
/reweave "client onboarding"
```
