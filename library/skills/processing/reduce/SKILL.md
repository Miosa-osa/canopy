---
name: reduce
description: >
  Extract atomic insights from raw source material. Takes articles, transcripts,
  meeting notes, or any unstructured input and produces structured claims with
  provenance metadata. The foundational extraction step of the 6R processing pipeline.
  Triggers on: "extract", "reduce", "distill", "summarize source"
---

# /reduce

> Extract insights from source material into atomic, reusable claims.

## Purpose

Transform raw input (articles, transcripts, notes, documents) into structured atomic claims — each with provenance, confidence, and topic tags. This is the core extraction step: it turns noise into signal. Every claim stands alone and can be recombined later.

## Usage

```bash
# Reduce a file
/reduce path/to/transcript.md

# Reduce inline text
/reduce --text "Ed called about pricing. He wants $2K per seat for enterprise..."

# Reduce with explicit source metadata
/reduce path/to/article.md --source "HBR" --date 2026-03-15

# Reduce with depth control
/reduce path/to/paper.pdf --depth deep

# Reduce multiple files
/reduce path/to/*.md --batch
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `<input>` | positional | required | File path, glob pattern, or `--text` for inline |
| `--text` | string | — | Inline text to reduce (alternative to file input) |
| `--source` | string | auto-detect | Source attribution (author, publication, URL) |
| `--date` | date | today | Date of the source material |
| `--depth` | enum | `standard` | `quick` (key points only), `standard` (claims + context), `deep` (claims + evidence + counterpoints) |
| `--format` | enum | `atomic` | `atomic` (one claim per block), `outline` (hierarchical), `table` (comparison grid) |
| `--max-claims` | int | 50 | Maximum number of claims to extract |
| `--tags` | string[] | auto | Topic tags to apply (auto-detected if omitted) |
| `--batch` | flag | false | Process multiple files, one output per input |
| `--output` | path | stdout | Write to file instead of stdout |

## Workflow

1. **Ingest** — Read source material. Detect format (markdown, PDF, plain text, transcript). Extract metadata (title, author, date) if present.
2. **Segment** — Break source into logical sections. Identify speakers in transcripts. Detect topic shifts.
3. **Extract** — Pull atomic claims from each segment. Each claim is a single, falsifiable statement or actionable insight. No compound claims.
4. **Classify** — Tag each claim: `fact`, `opinion`, `decision`, `action-item`, `question`, `insight`. Assign confidence (0.0–1.0).
5. **Deduplicate** — Merge claims that say the same thing in different words. Keep the clearest phrasing.
6. **Enrich** — Add topic tags, link to related entities (people, projects, orgs). Note provenance (source + location in source).
7. **Structure** — Emit claims in the requested format with YAML frontmatter.

## Output

Each reduced file produces structured output:

```yaml
---
type: reduction
source: "path/to/original.md"
source_title: "Q1 Strategy Call with Ed"
source_date: 2026-03-15
reduced_at: 2026-03-20T14:30:00Z
claim_count: 12
topics: [pricing, enterprise, ai-masters]
---

## Claims

### 1. Enterprise pricing target is $2K/seat
- **type:** decision
- **confidence:** 0.9
- **speaker:** Ed Honour
- **context:** Discussed during pricing review segment
- **tags:** [pricing, enterprise, ai-masters]

### 2. Current conversion rate from free tier is 3.2%
- **type:** fact
- **confidence:** 0.7
- **speaker:** Roberto
- **context:** Referenced but not sourced — verify against analytics
- **tags:** [metrics, conversion, funnel]
```

## Dependencies

- `/seed` — Often receives input from seed (but can run standalone)
- `/reflect` — Output feeds into reflect for connection discovery
- File system read access to source material
- PDF parsing capability for `.pdf` inputs
