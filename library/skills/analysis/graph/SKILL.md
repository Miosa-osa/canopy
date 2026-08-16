---
name: graph
description: >
  9 graph analysis operations for knowledge networks: triangles (synthesis opportunities),
  bridges (critical connectors), clusters (isolated subgraphs), hubs (high-degree nodes),
  siblings (unconnected items sharing topics), forward/backward traversal, orphans, and
  staleness scan. The analytical lens on your knowledge structure.
  Triggers on: "graph", "connections", "network analysis", "knowledge map"
---

# /graph

> 9 graph analysis operations for knowledge networks.

## Purpose

Analyze the structure of your knowledge graph to find hidden patterns, risks, and opportunities. The knowledge graph is built from entities (people, projects, concepts) and their relationships (references, co-occurrence, topical overlap). Graph analysis reveals what's invisible when looking at individual files: isolated clusters, critical bridges, synthesis opportunities, and structural weaknesses.

## Usage

```bash
# Overview stats
/graph

# Find synthesis opportunities (A→B, A→C, but no B→C)
/graph triangles

# Find critical connectors (remove them and clusters break apart)
/graph bridges

# Find isolated subgraphs
/graph clusters

# Find most-connected entities
/graph hubs

# Find items sharing topics but not linked
/graph siblings --topic "pricing"

# Forward traversal from an entity
/graph forward "Ed Honour" --depth 3

# Backward traversal (what points to this?)
/graph backward "pricing-decision-2026-03" --depth 2

# Find orphaned nodes (no connections)
/graph orphans

# Find stale edges (connections to outdated content)
/graph staleness --days 60
```

## Arguments

| Subcommand | Description |
|------------|-------------|
| (default) | Overview: node count, edge count, density, top hubs |
| `triangles` | Open triangles — synthesis opportunities |
| `bridges` | Bridge nodes — critical connectors |
| `clusters` | Connected components — isolated subgraphs |
| `hubs` | Highest-degree nodes (>2 standard deviations) |
| `siblings` | Items sharing topics but not directly linked |
| `forward <entity>` | Forward traversal from entity |
| `backward <entity>` | Backward traversal to entity |
| `orphans` | Nodes with zero connections |
| `staleness` | Edges pointing to stale content |

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--depth` | int | 2 | Traversal depth for forward/backward |
| `--topic` | string | — | Filter siblings by topic |
| `--days` | int | 90 | Staleness threshold |
| `--min-degree` | int | auto | Minimum degree for hubs (default: mean + 2σ) |
| `--scope` | string | `all` | Limit analysis: `all`, `node:<name>`, glob |
| `--format` | enum | `terminal` | `terminal`, `json`, `dot` (Graphviz), `markdown` |
| `--limit` | int | 20 | Maximum results per operation |

## Workflow

1. **Load graph** — Read entity index and relationship edges from the knowledge store.
2. **Execute operation** — Run the requested analysis algorithm.
3. **Score results** — Rank findings by actionability (synthesis opportunities by potential value, bridges by criticality, etc.).
4. **Render** — Format results in the requested output mode.

## Output

### Triangles (synthesis opportunities)
```markdown
## Open Triangles — 7 Synthesis Opportunities

| # | A | B | C (missing link) | Potential |
|---|---|---|-------------------|-----------|
| 1 | Ed Honour | pricing-strategy | MIOSA-business-model | Ed's pricing input hasn't reached MIOSA model. HIGH. |
| 2 | Bennett | ClinicIQ-deal | revenue-tracking | Deal closed but not reflected in revenue. MEDIUM. |
| 3 | Pedram | compute-engine | licensing-model | Technical decisions disconnected from licensing. HIGH. |

**Action:** Run `/reflect` on these pairs to generate explicit connections.
```

### Clusters
```markdown
## Knowledge Clusters — 4 Components

| Cluster | Nodes | Key Entities | Connected to Main? |
|---------|-------|--------------|--------------------|
| Main | 142 | Roberto, MIOSA, pricing, Ed | — (is main) |
| Island A | 8 | ContentOS, Tejas, podcast | weakly (1 edge via Bennett) |
| Island B | 3 | Tom, consortium, political | disconnected |
| Island C | 2 | George, hiring-plan | disconnected |

**Risk:** Islands B and C have no connection to the main graph. Content may be forgotten.
```

### Hubs
```markdown
## Hub Entities (degree > 2σ)

| Entity | Degree | Type | Top Connections |
|--------|--------|------|-----------------|
| Roberto | 47 | person | every node |
| pricing | 23 | concept | ai-masters, miosa, revenue, accelerants |
| Ed Honour | 18 | person | ai-masters, pricing, revenue |
| Bennett | 15 | person | accelerants, content, cliniciq |
```

## Dependencies

- Knowledge graph index (entity + edge store)
- Entity extraction (for building the graph)
- `/reflect` — Downstream action for synthesis opportunities
- `/health` — Related diagnostic capability
