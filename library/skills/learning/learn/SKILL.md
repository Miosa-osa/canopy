---
name: learn
description: >
  Research topics via web search, fetch content, and file to inbox with provenance
  metadata. The first step for acquiring external knowledge. Chains into /seed
  and /pipeline for full processing. Supports multiple search engines and content types.
  Triggers on: "learn", "research", "look up", "find out about"
---

# /learn

> Research topics via web search and ingest into the knowledge pipeline.

## Purpose

Acquire external knowledge on a topic. Search the web, evaluate results, fetch the most relevant content, convert it to markdown with provenance metadata, and hand it off to `/seed` for processing pipeline entry. This is how the knowledge base grows from external sources — every piece of acquired knowledge gets full provenance tracking.

## Usage

```bash
# Research a topic
/learn "enterprise AI pricing models 2026"

# Research and auto-process through pipeline
/learn "HIPAA compliance for AI agents" --pipeline

# Research with specific sources
/learn "Monte Carlo tree search" --sources arxiv,wikipedia

# Research with result limit
/learn "competitor analysis SaaS pricing" --max 5

# Research and seed without full pipeline
/learn "Firecracker VM security model" --seed-only

# View learning history
/learn --history
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `<query>` | positional | required | Research query or topic |
| `--max` | int | 5 | Maximum sources to fetch |
| `--sources` | string[] | `all` | Limit to specific sources: `web`, `arxiv`, `wikipedia`, `github`, `news` |
| `--depth` | enum | `standard` | `quick` (titles + snippets), `standard` (fetch + summarize), `deep` (fetch + full pipeline) |
| `--pipeline` | flag | false | Auto-run through `/pipeline` after seeding |
| `--seed-only` | flag | false | Seed but don't run pipeline |
| `--tags` | string[] | auto | Topic tags to apply |
| `--reason` | string | — | Why this research is needed (aids retrieval) |
| `--history` | flag | false | View past research sessions |
| `--output-dir` | path | `inbox/learned/` | Where to write fetched content |

## Workflow

1. **Search** — Query web search APIs with the topic. Retrieve top N results with titles, URLs, snippets.
2. **Evaluate** — Score results by relevance, recency, and source authority. Filter out low-quality sources (content farms, paywalled without access, duplicates).
3. **Fetch** — For each selected result:
   - Fetch full page content
   - Extract main content (strip navigation, ads, sidebars)
   - Convert to clean markdown
   - Preserve images if informational (diagrams, charts)
4. **Annotate** — Add provenance metadata to each fetched item: source URL, author, publication date, fetch date, relevance score, search query that found it.
5. **Seed** — Pass each annotated item to `/seed` for inbox entry. If `--pipeline`, chain directly into `/pipeline`.
6. **Summarize** — Produce a research brief: what was found, key findings across sources, gaps in coverage, suggested follow-up queries.
7. **Log** — Record research session: query, sources checked, sources fetched, total tokens consumed.

## Output

```markdown
## Research Report: "enterprise AI pricing models 2026"

**Sources searched:** 12 | **Fetched:** 5 | **Seeded:** 5
**Total content:** ~14,200 words

### Sources Acquired

| # | Title | Source | Date | Relevance | Status |
|---|-------|--------|------|-----------|--------|
| 1 | Enterprise AI Pricing: 2026 Benchmarks | Bessemer Venture Partners | 2026-02 | 0.94 | seeded |
| 2 | Per-Seat vs. Usage-Based: The AI Pricing Debate | a16z | 2026-01 | 0.89 | seeded |
| 3 | AI SaaS Pricing Survey (n=200) | OpenView Partners | 2025-12 | 0.85 | seeded |
| 4 | How We Price Our AI Product | Anthropic Blog | 2026-03 | 0.78 | seeded |
| 5 | The Death of Per-Seat Pricing | TechCrunch | 2026-02 | 0.72 | seeded |

### Key Findings (cross-source)
1. Per-seat pricing remains dominant for enterprise AI (68% of surveyed companies)
2. Usage-based pricing growing fastest (42% YoY adoption increase)
3. Median enterprise AI price: $1,800-2,500/seat/year
4. Hybrid models (base + usage) emerging as best practice

### Coverage Gaps
- No data found on AI pricing for healthcare-specific verticals
- Limited comparison with open-source alternatives
- Suggested follow-up: `/learn "AI pricing healthcare vertical"`

### Seeded Items
Files written to `inbox/learned/`:
- `2026-03-20-bessemer-ai-pricing.md`
- `2026-03-20-a16z-pricing-debate.md`
- `2026-03-20-openview-pricing-survey.md`
- `2026-03-20-anthropic-pricing.md`
- `2026-03-20-techcrunch-pricing.md`

Next step: `/pipeline inbox/learned/2026-03-20-*.md --batch` to process all.
```

## Dependencies

- Web search capability (search API or web browsing)
- Web fetch capability (HTTP client)
- HTML-to-markdown converter
- `/seed` — Downstream handoff for each acquired source
- `/pipeline` — Optional full processing chain
- File system write access for output directory
