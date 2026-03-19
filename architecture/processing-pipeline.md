# Processing Pipeline — The 6R Knowledge Pipeline

> The pipeline is a **6-phase processing chain** that transforms raw input into verified,
> interconnected knowledge: Record, Reduce, Reflect, Reweave, Verify, Rethink.
> Each phase spawns a fresh subagent so context degradation never compounds across phases.
> A task queue drives orchestration. Per-note task files are the inter-phase communication layer.

---

## Overview

Knowledge processing is lossy. Context windows degrade. Attention drifts. If you run
all six phases in a single session, phase 6 operates on a degraded representation of
the work from phase 1. The pipeline solves this by giving each phase its own fresh
context — a subagent with a clean window, a focused prompt, and a single job.

The pipeline is not a monolith. Each phase is an independent skill that can be invoked
manually, queued for later, or chained automatically. The orchestrator (`/pipeline`)
sequences them. The queue (`ops/queue.json`) persists them. Per-note task files
carry state between phases.

---

## The 6 Phases

```
INPUT (raw signal, note, transcript, observation)
  │
  ▼
┌──────────────────────┐
│ 1. RECORD            │──── Capture raw input into structured note
│    /seed             │     Assign metadata, create note file
└──────────┬───────────┘     Output: notes/{id}.md (raw, unprocessed)
           ▼
┌──────────────────────┐
│ 2. REDUCE            │──── Extract signal from noise
│    /reduce           │     Claims, entities, decisions, action items
└──────────┬───────────┘     Output: note gains structured frontmatter
           ▼
┌──────────────────────┐
│ 3. REFLECT           │──── Connect to existing knowledge
│    /reflect          │     Find related notes, surface contradictions
└──────────┬───────────┘     Output: bidirectional links added
           ▼
┌──────────────────────┐
│ 4. REWEAVE           │──── Backward-update existing knowledge
│    /reweave          │     Propagate new info to stale contexts
└──────────┬───────────┘     Output: existing notes updated
           ▼
┌──────────────────────┐
│ 5. VERIFY            │──── Quality gate
│    /verify           │     Check consistency, completeness, accuracy
└──────────┬───────────┘     Output: verification score + issues list
           ▼
┌──────────────────────┐
│ 6. RETHINK           │──── Evolve the system itself
│    /rethink          │     Synthesize patterns, update methodology
└──────────────────────┘     Output: methodology updates, new heuristics
```

### Phase Details

| Phase | Input | Output | Failure Mode |
|-------|-------|--------|-------------|
| **1. Record** | Raw text, file, transcript | Structured note with metadata (title, date, source, tags) | Malformed input → write to inbox with `needs_review` flag |
| **2. Reduce** | Structured note | Extracted claims, entities, decisions, action items appended as frontmatter | Empty extraction → flag as `low_signal`, skip remaining phases |
| **3. Reflect** | Reduced note + knowledge graph | Bidirectional links, contradiction alerts, cluster assignment | No connections found → note remains isolated (valid for novel topics) |
| **4. Reweave** | Reflect output + stale contexts | Updated existing notes with new information back-propagated | Conflict detected → create `ops/conflicts/{id}.md` for human review |
| **5. Verify** | All changes from phases 1-4 | Verification score (0-1), issues list, consistency report | Score < 0.5 → block promotion, route to human review |
| **6. Rethink** | Accumulated observations + methodology | Updated methodology docs, new heuristics, retired patterns | Insufficient evidence → defer (observation count threshold not met) |

---

## Fresh Context Per Phase

Each phase spawns a dedicated subagent. This is not optional — it is the core
architectural decision.

```
Orchestrator (thin — only tracks queue state)
  │
  ├── spawn → Record Agent    (fresh 200K context)
  │            └── writes notes/{id}.md + ops/tasks/{id}.json
  │
  ├── spawn → Reduce Agent    (fresh 200K context)
  │            └── reads notes/{id}.md, writes extracted frontmatter
  │
  ├── spawn → Reflect Agent   (fresh 200K context)
  │            └── reads note + scans knowledge graph, writes links
  │
  ├── spawn → Reweave Agent   (fresh 200K context)
  │            └── reads note + stale contexts, updates existing notes
  │
  ├── spawn → Verify Agent    (fresh 200K context)
  │            └── reads all changes, writes verification report
  │
  └── spawn → Rethink Agent   (fresh 200K context)
               └── reads observations, updates methodology
```

Why this matters: a 200K-context agent at phase 6 with a clean window produces
higher-quality synthesis than a 1M-context agent at token 800K with degraded
attention over 5 prior phases of accumulated state.

---

## Inter-Phase Communication

Phases communicate through **per-note task files** — JSON files in `ops/tasks/`
that carry processing state across agent boundaries.

### Task File Schema

```json
{
  "id": "note-2026-03-20-ed-call",
  "noteRef": "notes/2026-03-20-ed-call.md",
  "status": "reflecting",
  "depth": "deep",
  "chainMode": "automatic",
  "phases": {
    "record":  { "status": "done", "completedAt": "2026-03-20T15:30:00Z" },
    "reduce":  { "status": "done", "completedAt": "2026-03-20T15:31:12Z", "claimCount": 4 },
    "reflect": { "status": "running", "startedAt": "2026-03-20T15:31:45Z" },
    "reweave": { "status": "pending" },
    "verify":  { "status": "pending" },
    "rethink": { "status": "skipped", "reason": "observation_count < 10" }
  },
  "errors": [],
  "createdAt": "2026-03-20T15:30:00Z"
}
```

Each phase reads the task file, does its work, updates the file, and exits.
The orchestrator polls task files to determine what to spawn next.

---

## Task Queue

The global queue lives at `ops/queue.json`. It is an ordered list of pending
pipeline operations.

```json
{
  "queue": [
    { "taskId": "note-2026-03-20-ed-call", "nextPhase": "reflect", "priority": 2 },
    { "taskId": "note-2026-03-19-bennett-update", "nextPhase": "reweave", "priority": 1 },
    { "taskId": "maintenance:rethink:process", "type": "maintenance", "priority": 3 }
  ],
  "lastProcessed": "2026-03-20T15:31:12Z"
}
```

Priority is lowest-number-first. Maintenance tasks always have priority >= 3
(content processing takes precedence over system evolution).

---

## Processing Depths

Not every note needs six subagents. Three depths control resource allocation.

| Depth | Phases | Context Strategy | When to Use |
|-------|--------|-----------------|-------------|
| **Deep** | All 6, each a subagent | Fresh context per phase | High-value signals: decisions, strategy, financial |
| **Standard** | All 6, sequential in session | Single session, phase boundaries logged | Normal signals: meeting notes, status updates |
| **Quick** | Record + Reduce only, single pass | Compressed single agent | Low-value signals: FYI updates, acknowledgments |

Depth is determined at Record time based on signal classification:

```
Signal S/N >= 0.7  →  Deep
Signal S/N >= 0.4  →  Standard
Signal S/N >= 0.3  →  Quick
Signal S/N <  0.3  →  Rejected (not recorded)
```

### Depth Escalation

A Standard-depth note can escalate to Deep if:
- Reduce phase extracts 5+ claims (high information density)
- Reflect phase finds 3+ contradictions with existing knowledge
- Manual override via `/pipeline --depth deep`

---

## Chaining Modes

How phases connect to each other after completion.

| Mode | Behavior | Trigger |
|------|----------|---------|
| **Manual** | Phase completes, stops. Human invokes next phase explicitly. | `/reduce note-id`, then later `/reflect note-id` |
| **Suggested** | Phase completes, adds next phase to `ops/queue.json`. Human reviews queue and approves. | Default for Standard depth |
| **Automatic** | Phase completes, orchestrator immediately spawns next phase. No human in the loop. | Default for Deep depth, or `/pipeline --chain auto` |

```
Manual:     Record ──stop──> (human) ──> Reduce ──stop──> (human) ──> ...
Suggested:  Record ──queue──> [Reduce in queue] ──(human approves)──> Reduce ──queue──> ...
Automatic:  Record ──spawn──> Reduce ──spawn──> Reflect ──spawn──> Reweave ──spawn──> ...
```

---

## Maintenance Triggers

Rethink and Reweave can also fire as **maintenance operations** independent of any
specific note, triggered by conditions in the knowledge base.

| Condition | Threshold | Action |
|-----------|-----------|--------|
| Observation accumulation | `observation_count >= 10` for a category | Queue `/rethink {category}` |
| Inbox staleness | Note in `ops/inbox/` older than 3 days | Queue `/reduce` + alert |
| Methodology drift | Methodology file unchanged > 30 days | Queue `/rethink methodology` |
| Verification decay | Average verify score drops below 0.6 | Queue `/verify --sample 20` |
| Reweave staleness | Topic referenced in 5+ new notes without backward update | Queue `/reweave {topic}` |

Maintenance tasks are added to `ops/queue.json` with `type: "maintenance"` and
priority 3+. They run during idle periods or when explicitly triggered.

### Condition Check Schedule

```
On every Record:    Check inbox staleness, observation accumulation
On every Reflect:   Check reweave staleness for connected topics
Daily (if idle):    Check methodology drift, verification decay
On /health:         Check all conditions, report status
```

---

## Skills Reference

Each phase maps to an invocable skill.

| Skill | Phase | Arguments | Description |
|-------|-------|-----------|-------------|
| `/seed` | Record | `"raw text"` or `--file path` | Capture input, create note, assign metadata |
| `/reduce` | Reduce | `note-id` or `--all pending` | Extract claims, entities, decisions from note |
| `/reflect` | Reflect | `note-id` | Connect note to knowledge graph, find related notes |
| `/reweave` | Reweave | `note-id` or `topic` | Back-propagate new info to stale existing notes |
| `/verify` | Verify | `note-id` or `--sample N` | Quality gate: check consistency, score output |
| `/rethink` | Rethink | `category` or `--force` | Synthesize observations into methodology updates |
| `/pipeline` | Orchestrator | `"raw text"` `--depth` `--chain` | Run full pipeline with specified depth and chaining |

### Pipeline Invocation Examples

```bash
# Full automatic deep pipeline
/pipeline "Ed called about pricing, wants $2K per seat" --depth deep --chain auto

# Manual step-by-step
/seed "Bennett closed the ClinicIQ deal"
/reduce note-2026-03-20-bennett-deal
/reflect note-2026-03-20-bennett-deal

# Process all queued items
/pipeline --drain

# Maintenance pass
/rethink process --force
/verify --sample 20
```

---

## Invariant Rules

| Rule | Rationale |
|------|-----------|
| **Never skip Record** | Every piece of knowledge must have a traceable origin note. No phantom knowledge. |
| **Reduce before Reflect** | You cannot connect what you haven't extracted. Reflection on raw text produces shallow links. |
| **Reweave is backward-only** | Reweave updates existing notes with new information. It never modifies the source note. Forward flow is Reflect's job. |
| **Verify gates promotion** | A note with verify score < 0.5 cannot be treated as trusted knowledge. It stays flagged until fixed. |
| **Rethink requires evidence** | Minimum observation count threshold must be met. Premature synthesis produces fragile heuristics. |
| **Task files are the source of truth** | If a phase's work isn't recorded in the task file, it didn't happen. No in-memory-only state. |

---

## Error Recovery

| Failure | Recovery |
|---------|----------|
| Subagent crashes mid-phase | Task file shows phase as `running` with no `completedAt`. Orchestrator detects stale runs (>10 min), marks as `failed`, re-queues phase. |
| Reduce produces empty extraction | Note flagged `low_signal`. Pipeline halts for this note. Can be retried with `/reduce --force`. |
| Reweave creates conflict | Conflict file created in `ops/conflicts/`. Both versions preserved. Human resolves. |
| Queue corruption | Queue rebuilt from task files: any task with a non-terminal `nextPhase` is re-queued. |
| Verify score below threshold | Note flagged, excluded from knowledge graph queries until remediated. |

---

## Related Docs

- [heartbeat.md](heartbeat.md) — Agent execution cycle that runs each phase
- [sessions.md](sessions.md) — How subagent context is managed per phase
- [three-space-model.md](three-space-model.md) — Where pipeline artifacts live (notes/ vs ops/)
- [tasks.md](tasks.md) — Task system that pipeline task files extend
- [memory-architecture.md](memory-architecture.md) — How processed knowledge integrates with memory tiers

---

*Processing Pipeline v1.0 — The 6R knowledge chain with fresh-context subagent isolation*
