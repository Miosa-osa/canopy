# /search

> Search the knowledge base for signals, contexts, and decisions.

## Usage
```
/search "<query>" [--node <node>] [--type <type>] [--genre <genre>] [--limit <n>]
```

## What It Does
Queries the OptimalOS knowledge base using FTS5 full-text search. Returns L0 abstracts (~100 tokens each) ranked by relevance. Use before answering questions about past context -- search first, don't guess which file to read.

## Implementation
Runs: `cd engine && mix optimal.search "<query>" [flags]`

The engine searches across all indexed markdown files, returning:
- File path (optimal:// URI)
- L0 abstract (compressed summary)
- Relevance score
- Node and genre metadata

## Examples
```bash
# Search for past decisions about pricing
/search "pricing decision"

# Search within a specific node
/search "Ed Honour" --node ai-masters

# Search for signals of a specific genre
/search "revenue" --type signal --genre decision-log

# Limit results
/search "Bennett" --limit 3
```
