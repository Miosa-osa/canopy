---
name: verify
description: >
  Quality gate for knowledge base content. Validates structural compliance (YAML
  frontmatter, required fields, link integrity), checks that L0 abstracts accurately
  represent full content, and runs schema conformance. Non-blocking — reports warnings.
  Triggers on: "verify", "validate", "check quality", "lint knowledge"
---

# /verify

> Quality gate — validate content structure, link integrity, and abstract fidelity.

## Purpose

Ensure every piece of content in the knowledge base meets structural and semantic quality standards. Catches broken links, missing frontmatter, schema violations, and abstract drift (where an L0 summary no longer matches its full content). Runs as a non-blocking gate — reports issues without preventing work.

## Usage

```bash
# Verify a single file
/verify path/to/context.md

# Verify an entire node
/verify --scope node:ai-masters

# Verify the full knowledge base
/verify --scope all

# Verify with sampling (faster for large bases)
/verify --scope all --sample 20

# Verify only structural checks (skip semantic)
/verify --checks structural

# Verify only abstract fidelity
/verify --checks fidelity --sample 10
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `<path>` | positional | — | Specific file or directory to verify |
| `--scope` | string | `all` | `all`, `node:<name>`, `recent` (last 7 days) |
| `--sample` | int | — | Random sample size (for large knowledge bases) |
| `--checks` | enum[] | `all` | Comma-separated: `structural`, `fidelity`, `links`, `schema`, `duplicates` |
| `--severity` | enum | `all` | Filter output: `error`, `warning`, `info` |
| `--fix` | flag | false | Auto-fix trivially fixable issues (missing dates, formatting) |
| `--output` | enum | `terminal` | `terminal`, `json`, `markdown` |

## Workflow

1. **Collect** — Gather target files based on scope. Apply sampling if `--sample` specified.
2. **Structural checks** — For each file:
   - YAML frontmatter present and parseable
   - Required fields exist (type, title, date at minimum)
   - Markdown structure valid (no broken headers, unclosed code blocks)
   - File naming convention followed
3. **Schema checks** — Validate against type-specific schemas:
   - `context.md` files have required sections
   - `signal.md` files have date, priority, status
   - Claims have confidence, type, tags
4. **Link checks** — For each internal reference:
   - Target file exists
   - Target section exists (for `#anchor` links)
   - No circular references beyond depth 3
5. **Fidelity checks** — For files with L0 abstracts:
   - Read full content and L0 abstract
   - Score semantic alignment (0.0–1.0)
   - Flag if alignment < 0.7 (abstract has drifted from content)
6. **Duplicate detection** — Find files with >80% content overlap. Flag for merge review.
7. **Report** — Emit findings grouped by severity, with file paths and specific line numbers.

## Output

```markdown
## Verification Report

**Scope:** all | **Files checked:** 142 | **Sample:** full scan
**Passed:** 128 | **Warnings:** 11 | **Errors:** 3

### Errors (must fix)
1. **ai-masters/signals/2026-03-10-ed-call.md** — Missing YAML frontmatter
2. **money-revenue/context.md** — Broken link: `../06-agency-accelerants/pricing.md` (file not found)
3. **team/context.md § Abdul** — Schema violation: missing `role` field

### Warnings (should fix)
4. **miosa/context.md** — L0 abstract fidelity: 0.52 (content has diverged significantly)
5. **roberto/context.md** — Last updated 94 days ago (staleness threshold: 90 days)
6. **content-creators/signals/podcast-plan.md** — Duplicate content overlap (87%) with `content-creators/signals/mosaic-plan.md`

### Info
- 7 files have no L0 abstract (not required but recommended)
- 4 files use deprecated `status` field format

### Summary
| Check | Pass | Warn | Error |
|-------|------|------|-------|
| Structural | 139 | 2 | 1 |
| Schema | 140 | 1 | 1 |
| Links | 141 | 0 | 1 |
| Fidelity | 18/20 | 2 | 0 |
| Duplicates | 136 | 6 | 0 |
```

## Dependencies

- Knowledge base file system access
- YAML parser
- Schema definitions for each content type
- L0 abstract index (for fidelity checks)
- Semantic similarity scoring (for fidelity and duplicate detection)
