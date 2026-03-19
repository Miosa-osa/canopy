---
name: reweave
description: >
  Backward pass over existing knowledge when new information arrives. Finds older
  content that should be updated, corrected, or enriched in light of new data.
  Detects staleness, generates update suggestions, and optionally applies them.
  Triggers on: "reweave", "update stale", "backward pass", "refresh context"
---

# /reweave

> Find and update older content affected by new information.

## Purpose

When new knowledge enters the system, older content may become stale, contradicted, or incomplete. Reweave performs a backward pass: given new information, it scans existing content for items that reference the same topics, entities, or decisions — and flags what needs updating. This prevents knowledge decay and keeps the system coherent.

## Usage

```bash
# Reweave after new information about a topic
/reweave "Ed confirmed pricing at $2K/seat"

# Reweave based on a recently added file
/reweave --trigger path/to/new-signal.md

# Reweave a specific topic across all nodes
/reweave --topic "pricing" --scope all

# Reweave with staleness threshold
/reweave --topic "team roster" --days 30

# Dry run — show what would change without applying
/reweave "new CTO hired" --dry-run

# Apply suggested updates automatically
/reweave "Bennett closed ClinicIQ" --apply
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `<info>` | positional | — | New information that triggers the backward pass |
| `--trigger` | path | — | File that contains the new information |
| `--topic` | string | auto | Topic to scan for staleness (auto-extracted from input) |
| `--scope` | string | `all` | `all`, `node:<name>`, or glob pattern |
| `--days` | int | 90 | Flag content older than N days as potentially stale |
| `--dry-run` | flag | true | Show suggestions without applying changes |
| `--apply` | flag | false | Apply suggested updates (with confirmation per change) |
| `--severity` | enum | `all` | Filter: `critical` (contradictions), `stale` (outdated), `incomplete` (missing new data) |
| `--output` | path | stdout | Write report to file |

## Workflow

1. **Parse trigger** — Extract entities, topics, claims, and dates from the new information.
2. **Scan** — Search the knowledge base for all items that reference the same entities or topics.
3. **Compare** — For each candidate item, compare its claims against the new information. Detect: contradictions (old says X, new says not-X), staleness (old references outdated state), gaps (old is missing information now available).
4. **Score severity** — `critical` = direct contradiction, `stale` = outdated but not wrong, `incomplete` = could be enriched.
5. **Generate suggestions** — For each affected item, produce a specific update suggestion: what to change, why, and the exact edit.
6. **Review gate** — In `--dry-run` mode (default), present suggestions for human review. In `--apply` mode, confirm each change before writing.
7. **Apply** — Write approved changes. Log each update with timestamp and trigger reference.
8. **Report** — Emit summary: items scanned, items affected, changes made, items still needing manual review.

## Output

```markdown
## Reweave Report

**Trigger:** "Ed confirmed enterprise pricing at $2K/seat effective April 1"
**Scanned:** 47 items across 6 nodes
**Affected:** 4 items

### Critical (Contradictions)
1. **money-revenue/context.md § Pricing Tiers**
   - **Current:** "Enterprise tier: $1,500/seat (proposed)"
   - **Update:** "Enterprise tier: $2,000/seat (confirmed by Ed, effective 2026-04-01)"
   - **Status:** ⏳ pending approval

### Stale
2. **ai-masters/context.md § Revenue Model**
   - **Current:** "Pricing TBD — awaiting Ed's input"
   - **Update:** "Enterprise: $2K/seat (confirmed 2026-03-20). Free tier conversion targeting 5%."
   - **Status:** ⏳ pending approval

### Incomplete
3. **miosa/context.md § Business Model**
   - **Current:** No enterprise pricing section
   - **Suggestion:** Add enterprise pricing reference with cross-link to ai-masters
   - **Status:** ⏳ pending approval

### No Action Needed
- 43 items scanned, no staleness detected
```

## Dependencies

- `/reduce` — New information should ideally be reduced first
- `/reflect` — Uses connection graph to find affected items
- Knowledge base search index
- File write access for `--apply` mode
