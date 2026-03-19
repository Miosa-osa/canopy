# /rethink

Evidence synthesis when observations accumulate on a topic.

## What It Does
When cumulative confidence ≥ 1.5 on a topic: gathers all observations + search results →
generates synthesis → outputs structured rethink report with evidence + proposed
context.md updates. Never auto-applies changes.

## Usage
```
/rethink "topic"                # Generate synthesis report
/rethink "duplicates" --auto    # Auto-apply (use with caution)
```

## Options
| Flag | Description | Default |
|------|-------------|---------|
| `--auto` | Auto-apply proposed updates | false |

## Engine Command
```bash
cd engine && mix optimal.rethink "topic"
```

## When to Use
- When `/remember --escalations` shows topics ready for rethink
- When you want to synthesize accumulated evidence
- Monthly review sessions
