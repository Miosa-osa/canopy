---
name: seed
description: >
  Initialize sources into the processing pipeline. Takes URLs, files, or raw text
  and creates inbox items with full provenance metadata. The entry point for all
  external knowledge — nothing enters the system without being seeded first.
  Triggers on: "seed", "add source", "ingest url", "new input"
---

# /seed

> Initialize sources into the processing pipeline with provenance metadata.

## Purpose

The entry point for all external knowledge. Takes raw inputs — URLs, files, pasted text, clipboard — and creates structured inbox items with provenance tracking (where it came from, when, who authored it, why it was added). Nothing enters the knowledge system without being seeded first. This ensures every piece of knowledge has a traceable origin.

## Usage

```bash
# Seed a local file
/seed path/to/article.md

# Seed a URL (fetches and converts)
/seed --url "https://example.com/blog-post"

# Seed inline text
/seed --text "Ed mentioned that enterprise pricing should be $2K/seat"

# Seed with explicit metadata
/seed path/to/notes.md --source "Team sync call" --author "Roberto" --reason "Pricing decision"

# Seed multiple files
/seed path/to/inbox/*.md --batch

# Seed from clipboard
/seed --clipboard
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `<input>` | positional | — | File path or glob pattern |
| `--url` | string | — | URL to fetch, convert to markdown, and seed |
| `--text` | string | — | Inline text to seed |
| `--clipboard` | flag | false | Read from system clipboard |
| `--source` | string | auto-detect | Source name (publication, meeting, person) |
| `--author` | string | unknown | Author of the source material |
| `--date` | date | today | Date of the source material |
| `--reason` | string | — | Why this is being added (aids future retrieval) |
| `--tags` | string[] | auto | Initial topic tags |
| `--priority` | enum | `normal` | `high`, `normal`, `low` — affects processing order |
| `--batch` | flag | false | Process multiple inputs as separate seed items |
| `--output-dir` | path | `inbox/` | Where to write seeded items |

## Workflow

1. **Acquire** — Read input from file, URL, text, or clipboard. For URLs: fetch page, extract main content (strip nav/ads/chrome), convert to markdown.
2. **Detect format** — Identify source type: article, transcript, code, data, mixed. Set MIME type.
3. **Extract metadata** — Pull available metadata: title, author, date, word count, language. For URLs: extract Open Graph tags, publication name, canonical URL.
4. **Generate provenance** — Create provenance record: source URI, acquisition timestamp, acquisition method, hash of content (for dedup), reason for adding.
5. **Deduplicate** — Hash content and check against existing seeds. If duplicate found, warn and link to existing item instead of creating new.
6. **Write** — Create inbox item as markdown file with YAML frontmatter containing all metadata. Place in output directory.
7. **Acknowledge** — Return confirmation with item ID, metadata summary, and next suggested action (usually `/reduce`).

## Output

```yaml
---
id: seed-2026-03-20-143000-a1b2c3
type: seed
status: inbox
source: "https://example.com/ai-pricing-strategies"
source_title: "Enterprise AI Pricing in 2026"
source_author: "Jane Smith"
source_date: 2026-03-18
acquired_at: 2026-03-20T14:30:00Z
acquired_via: url_fetch
content_hash: sha256:a1b2c3d4...
word_count: 2847
language: en
tags: [pricing, enterprise, AI, SaaS]
reason: "Research for AI Masters pricing decision"
priority: normal
---

# Enterprise AI Pricing in 2026

[Full converted content here...]
```

## Dependencies

- Web fetch capability (for `--url` mode)
- HTML-to-markdown converter (for URL processing)
- Clipboard access (for `--clipboard` mode)
- File system write access to inbox directory
- Content hashing for deduplication
