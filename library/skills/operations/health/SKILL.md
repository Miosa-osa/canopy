# /health

> Run 10 diagnostic checks on the knowledge base -- find orphans, drift, duplicates.

## Usage
```
/health [--fix]
```

## What It Does
Runs a comprehensive health check on the knowledge base. Detects orphaned files, stale contexts, duplicate entries, broken cross-references, missing indexes, and structural issues. Reports findings with severity levels.

## Implementation
Runs: `cd engine && mix optimal.health`

Diagnostic checks:
1. **Orphaned files** -- files not referenced by any context or signal.
2. **Stale contexts** -- context.md files not updated in 30+ days.
3. **Duplicate entries** -- same information stored in multiple places.
4. **Broken cross-references** -- links pointing to nonexistent files.
5. **Missing indexes** -- files that exist but aren't in the search index.
6. **Empty nodes** -- folders with no meaningful content.
7. **Inconsistent metadata** -- frontmatter that doesn't match content.
8. **Drift detection** -- L0 abstracts that no longer match full content.
9. **Missing context.md** -- nodes without their required context file.
10. **Signal routing errors** -- signals filed in the wrong node.

## Examples
```bash
# Run full health check
/health

# Run health check and auto-fix what's possible
/health --fix
```
