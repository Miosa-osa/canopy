---
name: health
description: >
  Workspace health diagnostics. Runs targeted checks against the knowledge base:
  orphaned content, stale signals, missing cross-references, index drift, duplicate
  detection, broken references, embedding coverage, and quality distribution.
  Color-coded severity output.
  Triggers on: "health", "diagnose", "check health", "knowledge base status"
---

# /health

> Workspace health diagnostics — find what's broken, stale, or missing.

## Purpose

Run diagnostic checks against the workspace knowledge base to identify structural problems before they compound. Unlike `/audit` (which is broad and multi-domain), `/health` is laser-focused on knowledge base integrity: are files properly linked, is content fresh, are indexes in sync, are there orphans or duplicates? Think of it as `fsck` for your knowledge base.

## Usage

```bash
# Full health check
/health

# Check specific diagnostic
/health --check orphans

# Check a specific node
/health --scope node:ai-masters

# Run only quick checks (skip expensive ones)
/health --quick

# Output as JSON (for CI integration)
/health --format json

# Show only errors and warnings
/health --severity warn
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--check` | string[] | `all` | Specific checks: `orphans`, `stale`, `cross-refs`, `index-drift`, `duplicates`, `broken-refs`, `embeddings`, `quality`, `frontmatter`, `naming` |
| `--scope` | string | `all` | `all`, `node:<name>`, `recent` (last 7 days) |
| `--quick` | flag | false | Skip expensive checks (duplicates, embeddings, quality) |
| `--severity` | enum | `all` | Filter: `error`, `warn`, `info` |
| `--format` | enum | `terminal` | `terminal` (color-coded), `json`, `markdown` |
| `--fix` | flag | false | Auto-fix trivially fixable issues |
| `--output` | path | stdout | Write report to file |

## Workflow

1. **Collect** — Enumerate all files in scope. Load index state.
2. **Run checks** — Execute each diagnostic:

| Check | What It Detects | Severity |
|-------|----------------|----------|
| `orphans` | Files not referenced by any other file or index | warn |
| `stale` | Content not updated in >90 days with active topics | warn |
| `cross-refs` | Missing cross-references (e.g., financial data not in money-revenue) | error |
| `index-drift` | Files on disk that don't match the search index | error |
| `duplicates` | Files with >80% content overlap | warn |
| `broken-refs` | Internal links pointing to non-existent files or sections | error |
| `embeddings` | Files without vector embeddings (if embedding store exists) | info |
| `quality` | Files below quality threshold (short, no structure, no metadata) | warn |
| `frontmatter` | Missing or malformed YAML frontmatter | warn |
| `naming` | Files not following naming conventions | info |

3. **Score** — Calculate overall health score: (total checks - weighted failures) / total checks * 100.
4. **Render** — Color-coded terminal output: red for errors, yellow for warnings, blue for info, green for passing.

## Output

```
╔══════════════════════════════════════════════╗
║       WORKSPACE HEALTH — Score: 78/100       ║
╠══════════════════════════════════════════════╣

  ✗ ERRORS (3)
    ├── cross-refs: money-revenue missing ClinicIQ deal data (from 06-agency-accelerants)
    ├── index-drift: 4 new files not in search index (run /index to fix)
    └── broken-refs: 03-lunivate/context.md links to ../pricing.md (deleted)

  ⚠ WARNINGS (7)
    ├── orphans: 09-new-stuff/signals/ has 3 unrouted files
    ├── stale: 05-os-architect/context.md last updated 102 days ago
    ├── stale: 07-accelerants-community/signal.md last updated 94 days ago
    ├── duplicates: 2 signal files have 87% overlap (ed-pricing-*)
    ├── quality: 04-ai-masters/signals/draft.md has no structure (43 words, no headers)
    ├── frontmatter: 6 signal files missing required date field
    └── frontmatter: 2 context files missing required type field

  ℹ INFO (4)
    ├── embeddings: 12 files without vector embeddings
    ├── naming: 3 files use spaces instead of hyphens
    ├── naming: 1 file uses uppercase extension (.MD)
    └── 127 files passed all checks

  RECOMMENDATIONS
    1. Run `mix optimal.index` to fix index drift (3 min)
    2. Route 09-new-stuff orphans to proper nodes (10 min)
    3. Update stale context files: os-architect, accelerants-community (20 min)
    4. Merge duplicate ed-pricing signal files (5 min)
```

## Dependencies

- Knowledge base file system access
- Search index (for drift detection)
- YAML parser (for frontmatter checks)
- Content hashing (for duplicate detection)
- Vector store (for embedding coverage check, optional)
