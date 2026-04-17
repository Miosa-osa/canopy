# Architecture Reference (Historical)

> **Note:** These 30 documents are **reference material** — the OSA Operations
> architecture as documented in `canopy-legacy/architecture/`. They are **not**
> the Workspace Protocol proper (see the parent [`../README.md`](../README.md)).
>
> They define control-plane concerns (heartbeat, adapters, governance, budgets,
> session management, marketplace distribution, signal integration) and are
> useful context when making architectural decisions in Canopy v2.

**Port commit (source):** `7977035b1139e265b8af82f4ee29f1d88bb9ae25`
**Port date:** 2026-04-17

## Contents

| # | File | What It Defines |
|---|------|----------------|
| 1 | [heartbeat.md](heartbeat.md) | Agent wake/execute protocol — triggers, concurrency, locks, deferred queues. |
| 2 | [adapters.md](adapters.md) | Runtime adapter interface — invoke/status/cancel contract, session codec. |
| 3 | [governance.md](governance.md) | Human oversight — board powers, approval gates, escalation, audit logging. |
| 4 | [budgets.md](budgets.md) | Cost control — budget hierarchy, enforcement tiers, cost tracking. |
| 5 | [tasks.md](tasks.md) | Task system — hierarchy, lifecycle, atomic checkout, inbox model. |
| 6 | [sessions.md](sessions.md) | Session persistence — serialize/deserialize, compaction, migration. |
| 7 | [workspaces.md](workspaces.md) | Workspace management — resolution priority, execution isolation. |
| 8 | [marketplace.md](marketplace.md) | Distribution — bundle format, export/import, versioning, pricing. |
| 9 | [signal-integration.md](signal-integration.md) | Signal Theory integration — S/N gates, genre alignment, tiered loading. |
| 10 | [basement.md](basement.md) | Foundation resource/type system — resources, memory, skills, taxonomy. |
| 11 | [tiered-loading.md](tiered-loading.md) | L0/L1/L2 context management — token budgets, cache, relevance scoring. |
| 12 | [proactive-agents.md](proactive-agents.md) | Self-activating agent patterns — heartbeat/event/condition/schedule triggers. |
| 13 | [memory-architecture.md](memory-architecture.md) | 4-layer memory — working, episodic, semantic, procedural. |
| 14 | [spec-layer.md](spec-layer.md) | Executable specs — PROCEDURES.md, WORKFLOW.md, MODULES.md. |
| 15 | [pipelines.md](pipelines.md) | Event stream processing — producers, filters, consumers. |
| 16 | [verification.md](verification.md) | Self-validating workspaces — spec contracts, drift detection, ADRs. |
| 17 | [processing-pipeline.md](processing-pipeline.md) | 6R knowledge pipeline — Record/Reduce/Reflect/Reweave/Verify/Rethink. |
| 18 | [three-space-model.md](three-space-model.md) | Self/Knowledge/Ops separation. |
| 19 | [team-coordination.md](team-coordination.md) | Multi-agent coordination — leader-worker, worktree isolation, templates. |
| 20 | [optimal-system-mapping.md](optimal-system-mapping.md) | Canopy → 7-layer Optimal System architecture mapping. |
| 21 | [context-mesh.md](context-mesh.md) | Per-team context keeper GenServers — overflow storage, staleness scoring. |
| 22 | [decision-graph.md](decision-graph.md) | DAG-structured decision tracking — 5 node types, 10 edge types, pivots. |
| 23 | [self-healing.md](self-healing.md) | Autonomous error recovery — 8 categories, ephemeral healing agents. |
| 24 | [conversations.md](conversations.md) | Structured multi-agent dialogue — 4 types, 3 turn strategies, debate. |
| 25 | [cross-workspace-signals.md](cross-workspace-signals.md) | Signal routing between workspaces. |
| 26 | [engine-layer.md](engine-layer.md) | Engine layer architecture. |
| 27 | [engine-reference.md](engine-reference.md) | Engine reference — implementation contract. |
| 28 | [peer-protocol.md](peer-protocol.md) | Peer-to-peer workspace protocol. |
| 29 | [progressive-disclosure.md](progressive-disclosure.md) | Progressive disclosure patterns. |
| 30 | [project-layer.md](project-layer.md) | Project layer architecture. |
| 31 | [speculative-execution.md](speculative-execution.md) | Speculative agent execution. |
| 32 | [system-model.md](system-model.md) | System model overview. |

Total: 31 files ported (excluding this README).
