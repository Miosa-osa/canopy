# /search

> Search the operation's knowledge base for existing information.

## Usage

```
/search <query> [--node <node>] [--type <signal|document|note>] [--limit <n>]
```

## What It Does

Full-text search across all reference files, domain knowledge, and stored signals.
Returns results ranked by relevance with L0 abstracts. Use before creating new
content to avoid duplication.

## Implementation

1. **Parse query** — Extract keywords and entities.
2. **Search** — Full-text search across reference/ and any stored knowledge.
3. **Rank** — Order by relevance (keyword match + recency + frequency).
4. **Return** — L0 abstracts for top results. Load L1 on request.

## Parameters

| Param | Default | Description |
|-------|---------|-------------|
| `--node` | all | Restrict search to a specific node |
| `--type` | all | Filter by resource type |
| `--limit` | 5 | Maximum results to return |

## Examples

```bash
# Broad search
/search "pricing strategy"

# Scoped search
/search "client feedback" --type signal --limit 10

# Search specific node
/search "architecture decision" --node product
```
