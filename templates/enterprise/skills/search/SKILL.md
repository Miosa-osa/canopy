# /search

> Search the operation's knowledge base. Available to all agents.

## Usage
```
/search <query> [--node <node>] [--type <signal|document|note>] [--limit <n>]
```

## What It Does
Full-text search across reference files, domain knowledge, and stored signals.
Returns L0 abstracts ranked by relevance.

## Implementation
1. **Parse query** — Extract keywords and entities.
2. **Search** — Full-text across all knowledge sources.
3. **Rank** — Relevance scoring (keyword + recency + frequency).
4. **Return** — L0 abstracts for top N results.

## Examples
```bash
/search "pricing strategy"
/search "deployment architecture" --type document
/search "client feedback" --limit 10
```
