# /assemble

Build a tiered context bundle for a topic.

## What It Does
Searches for relevant contexts, loads L0+L1+L2 with token counts, assembles into
a coherent context bundle optimized for the AI's context window.

## Usage
```
/assemble "AI Masters pricing"
/assemble "platform architecture" --limit 10
```

## Options
| Flag | Description | Default |
|------|-------------|---------|
| `--limit` | Max contexts to include | 10 |

## Engine Command
```bash
cd engine && mix optimal.assemble "topic"
```

## When to Use
- Before answering questions about past context
- Before a call (load person + topic context)
- At BUILD mode start (load project context)
- When you need comprehensive background on a decision
