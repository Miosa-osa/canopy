# OSA Operations — Architecture Layer

> The control plane specifications for OSA Operations. These define HOW the system
> executes — heartbeat protocol, adapter contracts, governance, budgets, task routing,
> session management, workspaces, marketplace distribution, and Signal Theory integration.
>
> These are **specifications**, not code. Any runtime (OSA, Claude Code, Cursor, OpenClaw)
> can implement them. The source of truth is the OSA Operations control plane model, enhanced
> with Signal Theory.

---

## Table of Contents

| # | File | What It Defines |
|---|------|----------------|
| 1 | [heartbeat.md](heartbeat.md) | Agent wake/execute protocol — triggers, concurrency, locks, deferred queues, orphan detection |
| 2 | [adapters.md](adapters.md) | Runtime adapter interface — invoke/status/cancel contract, supported adapters, context delivery, session codec |
| 3 | [governance.md](governance.md) | Human oversight — board powers, approval gates, escalation protocol, cross-team rules, audit logging |
| 4 | [budgets.md](budgets.md) | Cost control — budget hierarchy, enforcement tiers, cost tracking, billing codes, delegation model |
| 5 | [tasks.md](tasks.md) | Task system — hierarchy, lifecycle, atomic checkout, inter-agent communication, inbox model |
| 6 | [sessions.md](sessions.md) | Session persistence — serialize/deserialize, compaction, per-task sessions, migration |
| 7 | [workspaces.md](workspaces.md) | Workspace management — resolution priority, project workspaces, execution isolation, cleanup |
| 8 | [marketplace.md](marketplace.md) | Distribution — bundle format, export modes, import flow, versioning, pricing |
| 9 | [signal-integration.md](signal-integration.md) | Signal Theory integration — S/N gates, genre alignment, tiered loading, knowledge graph, learning loop |
| 10 | [basement.md](basement.md) | Foundation resource/type system — resource types, memory types, skill types, category taxonomy |
| 11 | [tiered-loading.md](tiered-loading.md) | L0/L1/L2 context management — token budgets, cache strategy, loading triggers, relevance scoring |
| 12 | [proactive-agents.md](proactive-agents.md) | Self-activating agent patterns — heartbeat, event, condition, schedule triggers |
| 13 | [memory-architecture.md](memory-architecture.md) | 4-layer memory system — working, episodic, semantic, procedural memory |
| 14 | [spec-layer.md](spec-layer.md) | Executable markdown specs — PROCEDURES.md (action/query bindings), WORKFLOW.md (FSM definitions), MODULES.md (DAG topology) |
| 15 | [pipelines.md](pipelines.md) | Event stream processing — producers, filters, consumers, real-time pipeline composition |
| 16 | [verification.md](verification.md) | Self-validating workspaces — spec contracts, drift detection, verification strength levels, ADRs |
| 17 | [processing-pipeline.md](processing-pipeline.md) | 6R knowledge pipeline — Record, Reduce, Reflect, Reweave, Verify, Rethink with fresh context per phase |
| 18 | [three-space-model.md](three-space-model.md) | Self/Knowledge/Ops separation — identity vs. growing graph vs. ephemeral scaffolding |
| 19 | [team-coordination.md](team-coordination.md) | Multi-agent coordination — leader-worker hierarchy, filesystem messaging, git worktree isolation, team templates |

---

## How These Relate

```
                    ┌─────────────┐
                    │  GOVERNANCE │  Human oversight layer
                    │  (board)    │  Approval gates, escalation, audit
                    └──────┬──────┘
                           │ controls
                    ┌──────▼──────┐
                    │   BUDGETS   │  Cost enforcement
                    │  (company → │  Per agent, task, project
                    │   agent)    │
                    └──────┬──────┘
                           │ gates
                    ┌──────▼──────┐
                    │  HEARTBEAT  │  Wake → Execute → Persist cycle
                    │  (protocol) │  The core execution loop
                    └──┬───┬───┬──┘
                       │   │   │
            ┌──────────┘   │   └──────────┐
            ▼              ▼              ▼
     ┌───────────┐  ┌───────────┐  ┌───────────┐
     │  ADAPTERS │  │  SESSIONS │  │ WORKSPACES│
     │ (runtime) │  │ (state)   │  │ (where)   │
     └───────────┘  └───────────┘  └───────────┘
            │              │              │
            └──────┬───────┘              │
                   ▼                      │
            ┌───────────┐                 │
            │   TASKS   │◄────────────────┘
            │ (work +   │  Tasks drive workspace selection
            │  comms)   │  and session scoping
            └───────────┘
                   │
            ┌──────▼──────┐
            │   SIGNAL    │  Quality layer over all outputs
            │ INTEGRATION │  S/N gates, genre alignment,
            │             │  knowledge graph, learning
            └─────────────┘
                   │
            ┌──────▼──────┐
            │ MARKETPLACE │  Distribution of the whole stack
            │ (bundles)   │  Export, version, price, deploy
            └─────────────┘

   KNOWLEDGE LAYER                    COORDINATION LAYER

   ┌─────────────┐                   ┌───────────────┐
   │  PROCESSING │  6R pipeline:     │     TEAM      │  Leader-worker,
   │  PIPELINE   │  Record→Reduce→   │ COORDINATION  │  filesystem inbox,
   │  (6R)       │  Reflect→Reweave  │               │  git worktree
   └──────┬──────┘  →Verify→Rethink  └───────────────┘  isolation
          │
   ┌──────▼──────┐
   │ THREE-SPACE │  self/ = identity
   │    MODEL    │  knowledge/ = growing graph
   │             │  ops/ = ephemeral scaffolding
   └─────────────┘
```

## Source Material

These specs cover three domains:

1. **Control Plane** — Company orchestration, agents, heartbeat, tasks, budgets, adapters, governance
2. **Agent Definitions** — YAML frontmatter + markdown body, signal encoding, org chart
3. **Signal Theory** — Quality gates, tiered loading, knowledge graph, learning loop

The `protocol/operations-spec.md` in this repo is the unified spec. The architecture files
here are the decomposed, implementation-ready specifications for each subsystem.

## Relationship to operations-spec.md

`operations-spec.md` defines WHAT an Operation IS (the portable bundle format).
The `architecture/` files define HOW the system RUNS (the control plane behavior).

| operations-spec.md | architecture/ |
|--------------------|--------------|
| Company YAML schema | How budgets enforce at runtime |
| Agent frontmatter format | How agents wake up and execute |
| Workflow YAML schema | How tasks route and track |
| Session state schema | How sessions persist across runs |
| Adapter capability matrix | Full adapter interface contract |
| Governance rules | Board powers + approval gates + escalation |
| Marketplace bundle format | Export modes + import flow + pricing |

---

*Architecture Layer v2.0 — OSA Operations control plane specifications*
