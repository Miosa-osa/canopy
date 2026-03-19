# /reflect

> Find entities that co-occur frequently but lack explicit connections.

## Usage
```
/reflect [--min <n>]
```

## What It Does
Scans the knowledge base for entities that appear together in multiple contexts but have no explicit edge in the knowledge graph. These are implicit relationships that may deserve explicit documentation. The `--min` flag sets the co-occurrence threshold.

## Implementation
Runs: `cd engine && mix optimal.reflect [--min <n>]`

Process:
1. Extract all entity mentions across files.
2. Build co-occurrence matrix.
3. Compare against explicit graph edges.
4. Report entity pairs with high co-occurrence but no edge.

## Examples
```bash
# Find unconnected co-occurring entities
/reflect

# Require at least 3 co-occurrences
/reflect --min 3
```
