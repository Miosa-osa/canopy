# /reflect

Scan for entity co-occurrences not captured as graph edges.

## What It Does
Scans entities that co-occur in contexts but have no edge between them. Suggests
missing relationships. With Ollama: classifies relationship type (works_with,
reports_to, related_to, depends_on). Without: reports co-occurrence count.

## Usage
```
/reflect                        # Scan with default limit
/reflect --limit 20             # More results
```

## Options
| Flag | Description | Default |
|------|-------------|---------|
| `--limit` | Max suggestions | 10 |

## Engine Command
```bash
cd engine && mix optimal.reflect
cd engine && mix optimal.reflect --limit 20
```

## When to Use
- After batch ingestion (find new relationships)
- When knowledge graph feels sparse
- As part of weekly maintenance
