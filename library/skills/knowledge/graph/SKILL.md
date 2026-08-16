# /graph

> Analyze the knowledge graph -- find connections, clusters, hubs, and synthesis opportunities.

## Usage
```
/graph [subcommand] [--min <n>]
```

## What It Does
Explores the knowledge graph to find hidden connections between entities, isolated knowledge islands, and synthesis opportunities. The `triangles` subcommand is particularly useful -- it finds cases where A connects to B and A connects to C, but B and C have no direct link (a synthesis opportunity).

## Implementation
- Overview: `cd engine && mix optimal.graph`
- Triangles (synthesis opps): `cd engine && mix optimal.graph triangles`
- Clusters (isolated islands): `cd engine && mix optimal.graph clusters`
- Hubs (most-connected): `cd engine && mix optimal.graph hubs`
- Co-occurrence without edges: `cd engine && mix optimal.reflect [--min 3]`

## Examples
```bash
# Graph overview with stats
/graph

# Find synthesis opportunities (A->B, A->C exist but B->C missing)
/graph triangles

# Find isolated knowledge islands
/graph clusters

# Find most-connected entities (>2 sigma degree)
/graph hubs
```
