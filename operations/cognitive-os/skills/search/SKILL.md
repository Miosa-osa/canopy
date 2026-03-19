# /search

Hybrid search across the OptimalOS knowledge base.

## What It Does
FTS5 BM25 + vector similarity (Ollama) + RRF fusion (α=0.6) + temporal decay +
S/N ratio boost + knowledge graph boost. Returns tiered results with scores.

## Usage
```
/search "AI Masters pricing"
/search "Ed Honour" --node ai-masters
/search "revenue" --type signal --genre decision-log
/search "pricing decision" --limit 20
```

## Options
| Flag | Description | Default |
|------|-------------|---------|
| `--type` | Filter: signal, resource, memory, skill | All |
| `--node` | Filter by node ID | All |
| `--genre` | Filter by genre | All |
| `--limit` | Max results | 10 |
| `--min-score` | Drop results below this score | 0.0 |

## Engine Command
```bash
cd engine && mix optimal.search "query" --limit 5
cd engine && mix optimal.search "Ed Honour" --node ai-masters
```

## Tiered Loading Strategy
Results come back as L0 abstracts (~100 tokens each). To go deeper:
```bash
cd engine && mix optimal.read "optimal://..." --tier l1   # 2K overview
cd engine && mix optimal.read "optimal://..." --tier full  # Everything
```
