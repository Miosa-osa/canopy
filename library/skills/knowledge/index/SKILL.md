# /index

> Rebuild the full-text search index across all knowledge base files.

## Usage
```
/index [--full] [--stats]
```

## What It Does
Walks every markdown file in the knowledge base, extracts metadata and content, and rebuilds the SQLite FTS5 search index. Run after major file changes (bulk edits, reorganizations, imports).

## Implementation
Runs: `cd engine && mix optimal.index`

Process:
1. Walk all numbered folders and rhythm/ directory.
2. Parse frontmatter and content from each .md file.
3. Extract entities, topics, and cross-references.
4. Rebuild FTS5 index in SQLite.
5. Report: files indexed, entities found, duration.

With `--stats`: `cd engine && mix optimal.stats` to show index statistics.

## Examples
```bash
# Full reindex
/index

# Reindex and show statistics
/index --stats
```
