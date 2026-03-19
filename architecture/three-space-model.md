# Three-Space Model — Self / Knowledge / Ops

> The workspace is divided into three **conceptually distinct spaces** with different
> lifecycles, growth rates, and purge policies: Self (who the agent is), Knowledge
> (what the agent knows), and Ops (what the agent is doing right now).
> Conflating any two spaces produces one of six documented failure modes.

---

## Overview

Every agent workspace accumulates three kinds of state. Without explicit separation,
they bleed into each other — operational scaffolding pollutes the knowledge graph,
identity fragments drift into session files, and insights get purged with expired
queue items.

The three-space model draws hard boundaries. Each space has its own directory, its
own lifecycle, and its own rules for what enters and what leaves. Content flows in
one direction: ops can promote into knowledge, but knowledge never demotes into ops.

---

## The Three Spaces

```
┌─────────────────────────────────────────────────────────────┐
│                        WORKSPACE                             │
│                                                              │
│  ┌──────────────┐  ┌──────────────────┐  ┌──────────────┐  │
│  │              │  │                  │  │              │  │
│  │    self/     │  │     notes/       │  │    ops/      │  │
│  │              │  │   (knowledge)    │  │              │  │
│  │  WHO I AM    │  │   WHAT I KNOW    │  │  WHAT I'M    │  │
│  │              │  │                  │  │  DOING NOW   │  │
│  │  Permanent   │  │   Permanent      │  │  Temporal    │  │
│  │  Slow growth │  │   Steady growth  │  │  Flowing     │  │
│  │              │  │                  │  │              │  │
│  └──────────────┘  └──────────────────┘  └──────────────┘  │
│                                                              │
│         ◄── NO reverse flow ──    ── promote ──►            │
│                                   (ops → knowledge)          │
└─────────────────────────────────────────────────────────────┘
```

### Space Definitions

| Space | Directory | Contains | Lifecycle | Growth Rate |
|-------|-----------|----------|-----------|-------------|
| **Self** | `self/` | Agent identity, role definition, system prompt, methodology, preferences, working patterns | Permanent. Survives all resets. | Slow — changes on identity-level events only |
| **Knowledge** | `notes/` | The knowledge graph. Notes, contexts, signals, extracted claims, linked entities, decision logs | Permanent. Grows monotonically. Pruned only by explicit archive. | Steady — grows with every processed signal |
| **Ops** | `ops/` | Queue files, session state, health checks, task tracking, observations buffer, conflict resolution, inbox | Temporal. Can be purged without knowledge loss. | Flowing — high write/delete churn |

---

## Self Space

The self space answers: **who is this agent, and how does it work?**

```
self/
├── identity.md          # Name, role, capabilities, constraints
├── system-prompt.md     # The system prompt template (parameterized)
├── methodology.md       # How this agent processes information
├── preferences.md       # Learned preferences (output style, depth, genre defaults)
├── heuristics.md        # Evolved rules from /rethink cycles
└── working-context.md   # What the agent is currently focused on (updated per session)
```

### Self Space Rules

| Rule | Rationale |
|------|-----------|
| **Only /rethink and human edits modify self/** | Identity must not drift from incidental processing. Changes require deliberate synthesis or explicit instruction. |
| **working-context.md is the exception** | This file updates per-session to track current focus. It is the bridge between self and ops. |
| **Never store task state in self/** | Task progress is operational, not identity. It belongs in ops/. |
| **Version self/ changes** | Every modification to identity.md, methodology.md, or heuristics.md should note the date and trigger. |

---

## Knowledge Space

The knowledge space answers: **what does this agent know?**

```
notes/
├── {date}-{slug}.md           # Individual knowledge notes (pipeline output)
├── contexts/
│   ├── {entity}-context.md    # Persistent fact files per entity/topic
│   └── ...
├── signals/
│   ├── {date}-{slug}.md       # Temporal signals (weekly status, events)
│   └── ...
├── decisions/
│   ├── {date}-{slug}.md       # Decision logs with rationale
│   └── ...
└── index.json                 # Knowledge graph index (entities, links, clusters)
```

### Knowledge Space Rules

| Rule | Rationale |
|------|-----------|
| **Notes are append-mostly** | New information creates new notes or extends existing ones. Deletion is rare and deliberate (archive, not destroy). |
| **Reweave updates existing notes** | Backward propagation modifies knowledge notes — this is the only routine write path for existing notes. |
| **Links are bidirectional** | If note A references note B, note B's frontmatter includes a backlink to A. Orphan links are a health check failure. |
| **Never store queue state in notes/** | Processing status, task files, and observation buffers are operational. They live in ops/. |

---

## Ops Space

The ops space answers: **what is the agent doing right now?**

```
ops/
├── queue.json                 # Pipeline task queue (ordered, priority-sorted)
├── inbox/                     # Unprocessed raw inputs awaiting /seed
│   └── {timestamp}-{slug}.md
├── tasks/                     # Per-note pipeline task files (inter-phase state)
│   └── {note-id}.json
├── sessions/                  # Session state files (conversation continuity)
│   └── {session-id}.json
├── observations/              # Buffered observations awaiting /rethink threshold
│   └── {category}.jsonl
├── conflicts/                 # Reweave conflicts awaiting human resolution
│   └── {note-id}.md
├── health/                    # Health check results, verification scores
│   └── latest.json
└── logs/                      # Processing logs, error traces
    └── {date}.log
```

### Ops Space Rules

| Rule | Rationale |
|------|-----------|
| **Ops can be purged without knowledge loss** | If you delete everything in ops/, the agent loses its queue and session state but retains all knowledge and identity. This is the litmus test. |
| **Observations promote to self/ via /rethink** | Observations accumulate in ops/observations/. When threshold is met, /rethink synthesizes them into self/heuristics.md. The observations are then archived. |
| **Conflicts are temporary** | Conflict files exist until resolved. Resolution either updates the knowledge note or discards the conflicting information. |
| **Session files expire** | Sessions older than a configurable threshold (default: 7 days) can be safely purged. |

---

## The 6 Failure Modes of Conflation

When boundaries between spaces blur, specific failure modes emerge. Each is named
by the direction of the leak: `{source}-into-{destination}`.

```
                    self/
                   ╱     ╲
          ④ ──── ╱       ╲ ──── ②
        self     ╱         ╲     self
        into    ╱           ╲    into
        ops    ╱             ╲   notes
              ╱               ╲
        ops/ ◄───── ① ③ ─────► notes/
              ops-into-notes (①)
              notes-into-ops (③)
              ⑤ ops-into-self
              ⑥ notes-into-self
```

### Failure Mode Details

| # | Failure | Direction | Symptom | Example | Fix |
|---|---------|-----------|---------|---------|-----|
| **1** | Search pollution | ops → notes | Queue items and task files appear in knowledge searches. Noise drowns signal. | `search("pricing")` returns 15 task tracking files alongside 3 actual pricing notes | Exclude `ops/` from knowledge search index. Separate search scopes. |
| **2** | Schema confusion | self → notes | Agent identity fragments (methodology rules, preferences) stored as knowledge notes. The agent "knows about itself" instead of "being itself." | `methodology-v3.md` in notes/ alongside actual knowledge. Search returns agent internals. | Self-referential content lives in self/ only. Knowledge is about the domain, not the agent. |
| **3** | Insight loss on purge | notes → ops | Genuine insights stored in operational files (observations, session state). When ops is purged, knowledge is lost. | Key pattern discovered during session, stored only in session file. Session expires. Pattern gone. | Promote insights to notes/ before ops purge. /rethink is the promotion mechanism. |
| **4** | Identity drift | self → ops | Identity-level information (role, methodology) stored in session or task files. Agent identity changes based on which session loads. | Agent behaves differently depending on session restore, because its "personality" was stored in session state. | Identity loads from self/ at wake. Session carries task state, not identity. |
| **5** | Identity bloat | ops → self | Operational telemetry, health metrics, and processing logs promoted to self/. Agent's identity file becomes a dashboard. | self/identity.md is 500 lines, mostly processing stats and log summaries. | Only /rethink-synthesized heuristics enter self/. Raw operational data stays in ops/. |
| **6** | Second graph | notes → self | Knowledge duplicated in self/ as "the agent's understanding." Two competing representations of the same information. | self/domain-knowledge.md duplicates what's already in notes/contexts/. They drift apart. | Self/ contains how the agent processes, not what it has processed. Point to notes/, don't copy. |

---

## Content Promotion

Content flows in one direction: **ops → knowledge**. Never the reverse.

```
ops/inbox/{raw}.md ──/seed──► notes/{structured}.md
                                    (Record phase)

ops/observations/{cat}.jsonl ──/rethink──► self/heuristics.md
                                           (Rethink phase)

ops/conflicts/{id}.md ──resolve──► notes/{id}.md updated
                                    (Human decision)
```

### Promotion Rules

| From | To | Mechanism | Reversible? |
|------|-----|-----------|-------------|
| ops/inbox/ | notes/ | /seed (Record phase) | No. Raw input is consumed. |
| ops/observations/ | self/heuristics.md | /rethink (synthesis) | No. Observations archived after synthesis. |
| ops/conflicts/ | notes/ | Human resolution | No. Conflict file deleted after resolution. |
| ops/tasks/ | nowhere | Task files are never promoted. They track process, not knowledge. | N/A |
| ops/sessions/ | nowhere | Session state is never promoted. It is resumption context, not knowledge. | N/A |

### Anti-Patterns

| Anti-Pattern | Why It Fails |
|-------------|-------------|
| Copying notes into ops/ for "processing" | Creates stale copies. Edits diverge. Single source of truth violated. |
| Storing "important" ops data in notes/ | Pollutes knowledge graph with operational telemetry. |
| Syncing self/ with notes/ | Creates the "second graph" failure mode. Self/ references notes/, never duplicates. |

---

## Mapping to Workspace Protocol

The three-space model maps onto existing workspace structures.

| Space | Workspace Protocol Mapping | OptimalOS Mapping |
|-------|---------------------------|-------------------|
| **Self** | `SYSTEM.md` + `agents/` definitions + `skills/` | `CLAUDE.md` + `agents/` + `skills/` |
| **Knowledge** | `reference/` + `signals/` + numbered folders | Numbered folders (`01-roberto/` through `12-os-accelerator/`) |
| **Ops** | `engine/` state + `tasks/` + `rhythm/` working files | `engine/` + `tasks/` + `rhythm/today.md` |

### Boundary Enforcement in Practice

```
SELF (loads at session start, rarely written):
  SYSTEM.md ──── "who am I and how do I work"
  agents/*.md ── agent definitions
  CLAUDE.md ──── operating instructions

KNOWLEDGE (searched on demand, written by pipeline):
  01-roberto/context.md ──── persistent facts
  04-ai-masters/signals/ ── temporal knowledge
  notes/**/*.md ─────────── processed knowledge graph

OPS (active during session, purged periodically):
  engine/state/ ─────── index, cache, search state
  tasks/todo.md ─────── active task tracking
  rhythm/today.md ───── daily working file
  ops/queue.json ────── pipeline queue
```

---

## Purge Safety Test

The definitive test for correct space separation:

```
1. Delete everything in ops/
2. Agent should:
   ✓ Still know who it is (self/ intact)
   ✓ Still have all knowledge (notes/ intact)
   ✓ Lose its queue, session state, and processing progress
   ✓ Be able to rebuild ops/ from scratch on next boot

3. Delete everything in self/
4. Agent should:
   ✓ Still have all knowledge (notes/ intact)
   ✓ Lose its identity, methodology, and heuristics
   ✓ Need re-initialization (new system prompt, new identity)
   ✓ Knowledge is still searchable and valid

5. Delete everything in notes/
6. Agent should:
   ✓ Still know who it is (self/ intact)
   ✓ Still have operational state (ops/ intact)
   ✓ Have zero domain knowledge
   ✓ Pipeline still functions (processes new inputs from scratch)
```

If any purge test fails — if deleting ops/ loses knowledge, or deleting notes/
changes agent identity — the spaces are conflated.

---

## Related Docs

- [processing-pipeline.md](processing-pipeline.md) — The pipeline that moves content through and between spaces
- [workspaces.md](workspaces.md) — Workspace resolution and directory structure
- [memory-architecture.md](memory-architecture.md) — How memory tiers map to the three spaces
- [sessions.md](sessions.md) — Session state lifecycle (ops space)
- [heartbeat.md](heartbeat.md) — Agent identity retrieval at wake (self space)

---

*Three-Space Model v1.0 — Separation of identity, knowledge, and operations*
