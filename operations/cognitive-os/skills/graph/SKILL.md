# /graph

Analyze the knowledge graph for synthesis opportunities.

## What It Does
- **stats**: Entity count, edge count, edge type breakdown, top connected entities
- **triangles**: A→B and A→C edges where B→C is missing = synthesis opportunity
- **clusters**: BFS connected components = isolated knowledge silos
- **hubs**: Entities with degree > 2σ above mean = most connected nodes

## Usage
```
/graph                          # Show graph stats
/graph triangles                # Find synthesis opportunities
/graph triangles --limit 10     # Limit results
/graph clusters                 # Find isolated components
/graph hubs                     # Find hub nodes
```

## Engine Command
```bash
cd engine && mix optimal.graph
cd engine && mix optimal.graph triangles --limit 10
cd engine && mix optimal.graph clusters
cd engine && mix optimal.graph hubs
```

## When to Use
- Friday review (check for synthesis opportunities)
- After ingesting new signals (look for new connections)
- When looking for blind spots in knowledge
