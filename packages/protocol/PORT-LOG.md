# Canopy Legacy Port Log

**Port timestamp (UTC):** 2026-04-17T21:52:36Z
**Source repo:** `canopy-legacy/`
**Source commit:** `7977035b1139e265b8af82f4ee29f1d88bb9ae25`
**Target repo:** `canopy/` (v2)
**Operator:** senior engineer, Week 1 Day 1 handoff

## Scope

Three legacy asset trees were ported, verbatim, with YAML-frontmatter validation
as a precondition for copy. Files with a malformed `---\n...\n---\n` block were
rejected and are logged here. Files with no frontmatter block were allowed for
protocol/architecture (spec markdown), required for agents.

## Counts Ported — By Destination

| Destination | Ported | Considered | Rejected |
|-------------|-------:|-----------:|---------:|
| `canopy/packages/protocol/` (top-level) | 14 | 14 | 0 |
| `canopy/packages/protocol/architecture/` | 31 | 31 | 0 |
| `canopy/backend/priv/agents/` | 336 | 337 | 1 |
| **Total** | **381** | **382** | **1** |

## Agent Library — Per-Category Distribution

| Category | Count |
|----------|------:|
| academic | 5 |
| creative-content | 33 |
| design | 8 |
| engineering | 23 |
| executive | 1 |
| game-development | 20 |
| growth | 41 |
| marketing | 27 |
| operations | 30 |
| paid-media | 16 |
| product | 5 |
| project-management | 6 |
| revenue | 22 |
| sales | 10 |
| spatial-computing | 6 |
| specialized | 26 |
| support | 7 |
| technology | 42 |
| testing | 8 |
| **Total** | **336** |

## Rejected Files

Files that were **not** copied because their YAML frontmatter failed to parse.
These remain untouched in `canopy-legacy/` (source is read-only) and must be
hand-fixed before a future re-port.

| Source Path | Reason |
|-------------|--------|
| `library/agents/specialized/zk-steward.md` | `yaml parse error: mapping values are not allowed here` — unquoted colon inside the `description:` field ("Default perspective: Luhmann; …"). Fix: quote the description value or escape the inner colons. |

## Validation Method

Python 3 + PyYAML 6.0.3. Frontmatter extracted with regex `^---\n(.+?)\n---\n`
(DOTALL), then `yaml.safe_load`. No content modification — pure validate-then-copy.

- **Agents**: frontmatter REQUIRED. Missing → rejected.
- **Protocol / Architecture**: frontmatter OPTIONAL (most specs are pure prose).
  A malformed block, when present, is still rejected.

Driver script: `/tmp/port_canopy.py` (ephemeral, not checked in).
Intermediate results JSON: `/tmp/port_canopy_result.json` (ephemeral).

## Exit Criteria Verification

```
find canopy/packages/protocol -maxdepth 1 -name "*.md" | wc -l   # 14 (>= 14)
find canopy/packages/protocol/architecture -name "*.md" | wc -l  # 31 (>= 20)
find canopy/backend/priv/agents -name "*.md" | wc -l             # 336 (>= 300)
```

All three exit criteria met. YAML frontmatter validates across 100% of ported files.

## Notes for Next Port Pass

1. Fix `zk-steward.md` upstream (quote description value) and re-run the port
   to pull that agent into `priv/agents/specialized/`.
2. The legacy `protocol/README.md` and `architecture/README.md` were *replaced*
   in the port target with v2-specific READMEs; the legacy content is preserved
   in `canopy-legacy/` if needed.
3. No files in `canopy/backend/lib/`, `canopy/backend/test/`, or any Svelte/Rust
   directories were touched (respecting parallel-agent ownership boundaries).
