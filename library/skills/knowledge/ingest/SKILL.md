# /ingest

> Classify, route, and store incoming signals into the knowledge base.

## Usage
```
/ingest "<text>" [--genre <genre>] [--title <title>]
/ingest --file <path> [--genre <genre>] [--title <title>]
```

## What It Does
Takes raw input (text or file), classifies it along 5 Signal dimensions (Mode, Genre, Type, Format, Structure), routes it to the correct node(s), writes signal files, indexes in SQLite with FTS5, records in episodic memory, and feeds SICA learning patterns. Rejects signals with S/N < 0.3.

## Implementation
Runs: `cd engine && mix optimal.ingest "<text>" [flags]`

The engine automatically:
1. Classifies S=(M,G,T,F,W) dimensions.
2. Routes to primary node + cross-references.
3. Writes signal files to disk.
4. Indexes in SQLite with FTS5 search.
5. Records in episodic memory.
6. Rejects low-quality signals (S/N < 0.3).

After ingestion, you still need to:
- Update context.md for persistent facts.
- Cross-reference financial data to 11-money-revenue.

## Examples
```bash
# Ingest a call summary
/ingest "Ed called about pricing, wants $2K per seat"

# Ingest with explicit genre
/ingest "Sales team closed the enterprise deal" --genre note

# Ingest from a file
/ingest --file notes/team-sync.md --genre transcript --title "Team Sync"
```
