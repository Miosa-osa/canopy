---
name: compose
description: Generate structured documents from composition templates. Combines reference templates with live data to produce reviewable output artifacts. Triggered by compose, document, generate report, create brief, write proposal.
---

# /compose — Generate Document from Template

## Purpose

Produces structured output artifacts by combining a composition template (ROM) with
live workspace data. The template defines the skeleton. The agent fills it with
current context. The output lands in `output/` for human review.

## Usage

```
/compose <template-name> [--for <receiver>] [--data <source>] [--status draft|review]
```

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| `template-name` | Yes | — | Name of template in `reference/compositions/` |
| `--for` | No | — | Intended receiver (adjusts genre encoding) |
| `--data` | No | auto | Data source: `auto` scans relevant `data/` + `output/` |
| `--status` | No | `draft` | Initial status of the output file |
| `--output` | No | auto | Override output directory (default: `output/{genre}/`) |

## Workflow

1. **Load template** — Read `reference/compositions/{template-name}.md`
2. **Resolve receiver** — If `--for` specified, look up receiver's genre preference
   (from SYSTEM.md people table or company.yaml org chart)
3. **Gather data** — Scan `data/`, recent `output/`, and engine (if available) for
   relevant context. Use search if engine exists, otherwise scan by keyword.
4. **Generate** — Fill template skeleton with gathered data. Follow genre rules.
   Apply Signal Theory encoding: resolve all 5 dimensions S=(M,G,T,F,W).
5. **Write output** — Save to `output/{genre}/{date}-{title}.md` with frontmatter:
   ```yaml
   ---
   genre: {from template}
   type: {speech act}
   status: {draft|review}
   created_by: {agent name}
   created_at: {date}
   for: {receiver if specified}
   template: {template-name}
   ---
   ```
6. **Report** — Show output path, word count, data sources used.

## Examples

```bash
# Generate a quarterly review from template
/compose quarterly-review

# Write a proposal for a specific client
/compose client-brief --for "ACME Corp" --status review

# Create a weekly signal report using specific data
/compose weekly-signal --data "data/pipeline.json"

# Generate meeting prep doc
/compose meeting-prep --for "Ed Honour"
```

## Composition Template Format

Templates in `reference/compositions/` follow this structure:

```markdown
---
genre: proposal
default_output: output/proposals/
sections:
  - objective
  - key_messages
  - supporting_data
  - call_to_action
data_sources:
  - data/pipeline.json
  - output/analyses/
---

# {title}

## Objective
{Agent fills: one sentence, what outcome}

## Key Messages
{Agent fills: 3-5 bullets from gathered data}

## Supporting Data
{Agent fills: relevant metrics, quotes, evidence}

## Call to Action
{Agent fills: single unambiguous ask + deadline}
```

## Output

- File written to `output/{genre}/{date}-{title}.md`
- Frontmatter with full metadata for OSA command center
- Status set to `draft` (user reviews and promotes to `approved`)

## Dependencies

- `reference/compositions/` must contain the named template
- `data/` and/or `output/` for context gathering
- Engine search (optional, for richer data gathering)
- People/receiver table in SYSTEM.md or company.yaml (optional, for genre matching)
