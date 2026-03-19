---
name: pipeline
description: >
  End-to-end processing pipeline that chains the full 6R sequence: seed, reduce,
  reflect, reweave, verify. Runs per-item or in batch mode. Three depth levels
  control thoroughness vs. speed. The orchestrator for all processing skills.
  Triggers on: "pipeline", "process", "full pipeline", "6R"
---

# /pipeline

> End-to-end processing — seed through verify in one command.

## Purpose

Chain the full processing sequence in a single invocation: seed (initialize) → reduce (extract) → reflect (connect) → reweave (update old content) → verify (quality gate). Handles orchestration, error recovery, and progress tracking. Use this when you want the full treatment rather than running individual steps.

## Usage

```bash
# Process a single file through the full pipeline
/pipeline path/to/article.md

# Process with explicit depth
/pipeline path/to/transcript.md --depth deep

# Process multiple files in batch
/pipeline path/to/inbox/*.md --batch

# Quick single-pass processing (no subagents)
/pipeline path/to/notes.md --depth quick

# Process from URL
/pipeline --url "https://example.com/article" --depth standard

# Resume a failed pipeline run
/pipeline --resume run-2026-03-20-143000

# Skip specific stages
/pipeline path/to/file.md --skip reweave,verify
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `<input>` | positional | required | File path, glob, or `--url` for web content |
| `--url` | string | — | URL to fetch and process |
| `--depth` | enum | `standard` | Processing thoroughness (see Depth Levels below) |
| `--batch` | flag | false | Process multiple inputs as separate pipeline runs |
| `--skip` | string[] | — | Comma-separated stages to skip: `seed`, `reduce`, `reflect`, `reweave`, `verify` |
| `--stop-after` | string | — | Stop after this stage (e.g., `reduce` to just extract) |
| `--resume` | string | — | Resume a previous pipeline run by ID |
| `--parallel` | int | 1 | Number of parallel items in batch mode |
| `--output-dir` | path | `./processed/` | Directory for pipeline output |
| `--dry-run` | flag | false | Show what would happen without executing |

## Depth Levels

| Depth | Seed | Reduce | Reflect | Reweave | Verify | Time | Token Cost |
|-------|------|--------|---------|---------|--------|------|------------|
| `quick` | inline | key points only | skip | skip | structural only | ~30s | ~2K |
| `standard` | full metadata | claims + context | direct connections | dry-run suggestions | full checks | ~3min | ~15K |
| `deep` | full + provenance | claims + evidence + counterpoints | 2-hop traversal + synthesis | apply with approval | full + fidelity | ~10min | ~50K |

## Workflow

1. **Initialize** — Create pipeline run directory with unique ID. Log start time, input, and parameters.
2. **Seed** (`/seed`) — Ingest source material. Create inbox item with provenance metadata. Output: seeded item with metadata.
3. **Reduce** (`/reduce`) — Extract atomic claims from seeded content. Output: structured claims file.
4. **Reflect** (`/reflect`) — Find connections between new claims and existing knowledge. Output: connection map.
5. **Reweave** (`/reweave`) — Backward pass over existing content. Flag items that need updating. At `deep` depth, apply with human approval. Output: update report.
6. **Verify** (`/verify`) — Quality gate on all new and modified content. Output: verification report.
7. **Report** — Emit pipeline summary: items processed, claims extracted, connections found, updates suggested, quality score.
8. **Cleanup** — Archive pipeline run metadata for resume capability.

## Output

```markdown
## Pipeline Report — run-2026-03-20-143000

**Input:** ai-masters/signals/2026-03-20-ed-strategy-call.md
**Depth:** standard
**Duration:** 2m 34s
**Token cost:** ~12,400 tokens

### Stage Results

| Stage | Status | Output |
|-------|--------|--------|
| Seed | done | 1 item, 2,340 words, source: voice transcript |
| Reduce | done | 14 claims extracted (9 facts, 3 decisions, 2 action items) |
| Reflect | done | 7 connections found, 2 synthesis opportunities |
| Reweave | done | 3 items flagged for update (1 critical, 2 stale) |
| Verify | done | 14/14 claims pass structural, 1 fidelity warning |

### Key Outputs
- Claims file: `processed/run-2026-03-20-143000/claims.md`
- Connection map: `processed/run-2026-03-20-143000/connections.md`
- Reweave report: `processed/run-2026-03-20-143000/reweave.md`
- Verification: `processed/run-2026-03-20-143000/verify.md`

### Action Items Extracted
1. Roberto: Send revised pricing doc to Ed by Friday
2. Ed: Confirm enterprise pilot with Acme Corp
3. Roberto: Update money-revenue/context.md with new pricing
```

## Dependencies

- `/seed` — Stage 1
- `/reduce` — Stage 2
- `/reflect` — Stage 3
- `/reweave` — Stage 4
- `/verify` — Stage 5
- File system write access for output directory
- Subagent spawning capability (for `deep` depth)
