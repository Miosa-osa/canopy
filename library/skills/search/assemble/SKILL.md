# /assemble

> Build a tiered context bundle for a topic with token-aware loading.

## Usage
```
/assemble "<topic>" [--depth <l0|l1|full>]
```

## What It Does
Assembles a multi-tier context bundle for a given topic. Searches across all nodes, collects relevant files, and loads them at appropriate tiers (L0 = 100 tokens, L1 = 2K tokens, L2 = full). Returns a structured bundle with token counts so you know exactly what you're loading.

## Implementation
Runs: `cd engine && mix optimal.assemble "<topic>"`

Process:
1. Search all nodes for topic relevance.
2. Rank results by relevance score.
3. Load L0 abstracts for all matches.
4. Load L1 summaries for top matches.
5. Load full content only for highest-relevance hits.
6. Return structured bundle with token counts per tier.

## Examples
```bash
# Assemble context for a meeting topic
/assemble "AI Masters pricing"

# Assemble context before a call
/assemble "enterprise deal status"

# Quick L0-only scan
/assemble "team bandwidth" --depth l0
```
