# /ingest

Ingest a signal into the OptimalOS knowledge base.

## What It Does
Auto-classifies S=(M,G,T,F,W), routes to node(s), writes signal file, indexes in
SQLite FTS5, extracts entities, builds graph edges, records in episodic memory.
Rejects signals with S/N < 0.3.

## Usage
```
/ingest "Ed called about pricing, wants $2K per seat"
/ingest "Sales team closed the enterprise deal" --genre note
/ingest --file path/to/notes.md --genre transcript --title "Team Sync"
```

## Options
| Flag | Description | Default |
|------|-------------|---------|
| `--genre` | Force genre (note, transcript, decision-log, etc.) | Auto-detect |
| `--title` | Override auto-generated title | From content |
| `--file` | Ingest from file instead of inline text | — |
| `--node` | Force routing to specific node | Auto-route |

## Engine Command
```bash
cd engine && mix optimal.ingest "content" --genre note
cd engine && mix optimal.ingest --file path.md --genre transcript --title "Title"
```

## Post-Ingest
The engine automatically handles indexing and cross-referencing. You still need to:
- Update context.md for persistent facts (engine handles temporal signals)
- Cross-reference financial data to 11-money-revenue context.md
- Log decisions in relevant context.md under "Key Decisions"
