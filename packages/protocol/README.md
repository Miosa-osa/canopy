# @canopyai/protocol — Workspace Protocol Specs

Formal specifications ported from `canopy-legacy/protocol/`. These define the
workspace structure, agent format, signal encoding, and executable spec layers
that Canopy v2 conforms to. Markdown-only, format-stable — no rewrite.

**Port commit (source):** `7977035b1139e265b8af82f4ee29f1d88bb9ae25`
**Port date:** 2026-04-17

## Top-Level Specs

| File | One-line Summary |
|------|------------------|
| [agent-format.md](agent-format.md) | YAML frontmatter + 7 Markdown body sections that define an agent persona. |
| [operations-spec.md](operations-spec.md) | OSA Operations v1.0 — the complete specification of a deployable workspace. |
| [pipelines.md](pipelines.md) | Event stream processing — producers, filters, consumers for signal ingestion. |
| [project-format.md](project-format.md) | Project manifest — bounded, goal-oriented initiative within an Operation. |
| [signal-theory.md](signal-theory.md) | S=(M,G,T,F,W) universal signal encoding reference. |
| [spec-layer.md](spec-layer.md) | Executable markdown — PROCEDURES.md, WORKFLOW.md, MODULES.md formats. |
| [task-format.md](task-format.md) | Portable task manifest — atomic unit of work across adapters. |
| [verification.md](verification.md) | Spec contracts, verification strength tiers, drift detection. |
| [workspace-protocol.md](workspace-protocol.md) | The canonical `SYSTEM.md + agents/ + skills/ + reference/` standard. |

## Legacy (deprecated v2)

Company/Division/Department/Team org hierarchy specs moved to [`legacy/`](legacy/)
because Canopy v2 dropped the 5-layer org model in favor of flatter Workspaces.
See `legacy/README.md` for the deprecation rationale and v2 equivalents.

## Architecture Reference (Subfolder)

See [`architecture/`](architecture/) — 30 historical/reference architecture docs
(heartbeat, adapters, governance, budgets, tasks, sessions, workspaces,
marketplace, signal-integration, tiered-loading, memory-architecture, etc.).

These describe the OSA Operations control plane and are **reference material**
for architectural decisions in Canopy v2 — not the workspace protocol proper.

## Port Log

See [PORT-LOG.md](PORT-LOG.md) for counts, rejections, and provenance.
