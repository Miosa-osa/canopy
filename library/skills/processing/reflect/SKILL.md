---
name: reflect
description: >
  Discover connections between existing knowledge items. Scans the knowledge base
  for related concepts, updates topic maps, and surfaces synthesis opportunities
  using graph traversal. The connective tissue step of the 6R pipeline.
  Triggers on: "reflect", "connect", "find related", "topic map"
---

# /reflect

> Discover connections between existing knowledge items.

## Purpose

Scan the knowledge base for conceptual relationships that aren't explicitly linked. Find items that share topics, reference the same entities, or address the same problem from different angles. Produces a connection map and flags synthesis opportunities — places where combining two ideas would produce a third.

## Usage

```bash
# Reflect on a specific topic
/reflect "pricing strategy"

# Reflect on a recently added item
/reflect --item path/to/new-claim.md

# Reflect across the entire knowledge base
/reflect --scope all

# Reflect within a specific node/domain
/reflect --scope node:ai-masters

# Reflect with minimum connection strength
/reflect "enterprise sales" --min-strength 0.6
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `<topic>` | positional | — | Topic or query to find connections for |
| `--item` | path | — | Specific item to find connections for |
| `--scope` | string | `all` | `all`, `node:<name>`, `recent` (last 7 days), or glob pattern |
| `--min-strength` | float | 0.3 | Minimum connection strength to report (0.0–1.0) |
| `--max-results` | int | 20 | Maximum connections to return |
| `--depth` | int | 2 | Graph traversal depth (1 = direct, 2 = two hops, 3 = three hops) |
| `--type` | enum | `all` | Filter: `topical`, `entity`, `temporal`, `causal`, `contradictory` |
| `--update-graph` | flag | false | Write discovered connections to the knowledge graph |
| `--output` | path | stdout | Write results to file |

## Workflow

1. **Anchor** — Identify the focal point: a topic query, a specific item, or the full knowledge base.
2. **Expand** — Retrieve all items within scope that share topics, entities, or temporal proximity with the anchor.
3. **Score** — Compute connection strength based on: shared entities (0.4 weight), shared topics (0.3), temporal proximity (0.1), semantic similarity (0.2).
4. **Traverse** — Walk the graph outward from the anchor up to `--depth` hops. Each hop attenuates strength by 0.5.
5. **Classify** — Label each connection: `topical` (shared subject), `entity` (shared person/org), `temporal` (same timeframe), `causal` (one references the other), `contradictory` (opposing claims).
6. **Synthesize** — Identify synthesis opportunities: pairs of items that, if combined, would produce a novel insight. Flag these with a `synthesis_opportunity` marker.
7. **Emit** — Return connection map sorted by strength. Optionally update the knowledge graph with discovered edges.

## Output

```markdown
## Connections for: "pricing strategy"

### Direct Connections (depth 1)
| Item | Strength | Type | Shared |
|------|----------|------|--------|
| ai-masters/signals/ed-pricing-call.md | 0.92 | entity+topical | Ed, pricing, $2K |
| money-revenue/context.md § Pricing | 0.85 | topical | pricing tiers, enterprise |
| miosa/context.md § Business Model | 0.71 | topical | per-seat, SaaS |

### Second-Hop Connections (depth 2)
| Item | Via | Strength | Type |
|------|-----|----------|------|
| agency-accelerants/context.md § Pricing | money-revenue | 0.54 | topical |

### Synthesis Opportunities
1. **ed-pricing-call + miosa-business-model** — Ed's $2K/seat target hasn't been reconciled with MIOSA's freemium model. These two items address pricing from different angles but reach different conclusions. Synthesize into a unified pricing framework.

### Topic Map Update
- Added edge: ai-masters/pricing ↔ miosa/business-model (strength: 0.71)
- Added edge: ed-pricing-call ↔ money-revenue/pricing (strength: 0.85)
```

## Dependencies

- `/reduce` — Works best when knowledge has been reduced to atomic claims
- `/graph` — Uses graph traversal for multi-hop connections
- Knowledge base index (search capability)
- Entity extraction for shared-entity detection
