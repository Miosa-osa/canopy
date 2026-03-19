# /report

> Generate structured reports from operation data and knowledge.

## Usage

```
/report <topic> [--format <brief|detailed|executive>] [--period <week|month|quarter>]
```

## What It Does

Compiles a structured report by searching the knowledge base, aggregating data
points, and formatting for the target audience. The Lead agent owns report
generation and ensures proper genre encoding.

## Implementation

1. **Gather** — Search knowledge base for relevant data and signals.
2. **Aggregate** — Group findings by theme or timeline.
3. **Analyze** — Identify trends, risks, and recommendations.
4. **Format** — Apply the report template matching `--format`.
5. **Deliver** — Output the formatted report.

## Formats

| Format | Audience | Length | Focus |
|--------|----------|--------|-------|
| `brief` | Executives, clients | 200 words | Key points + action |
| `detailed` | Team leads, managers | 500-1000 words | Full analysis |
| `executive` | C-suite, board | 100 words | Decisions needed |

## Examples

```bash
# Weekly brief for client
/report "project status" --format brief --period week

# Detailed monthly analysis
/report "performance metrics" --format detailed --period month

# Executive summary
/report "Q1 results" --format executive --period quarter
```
