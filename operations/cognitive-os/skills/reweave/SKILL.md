# /reweave

Backward-pass analysis to find stale contexts and suggest updates.

## What It Does
Given a topic: searches related contexts → traverses entity graph → scores staleness →
generates update suggestions. With Ollama: specific diff suggestions. Without: staleness
flags with newer context titles.

## Usage
```
/reweave "Ed Honour"
/reweave "AI Masters pricing" --max-results 20
/reweave "platform architecture" --staleness-days 14
```

## Options
| Flag | Description | Default |
|------|-------------|---------|
| `--max-results` | Max contexts to analyze | 10 |
| `--staleness-days` | Threshold for "stale" | 30 |

## Engine Command
```bash
cd engine && mix optimal.reweave "topic"
cd engine && mix optimal.reweave "Ed Honour" --max-results 20
```

## When to Use
- Friday review (check key topics for drift)
- Before important meetings (ensure context is current)
- After major decisions (propagate updates to related contexts)
