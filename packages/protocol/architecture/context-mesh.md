# Context Mesh — Team Context Keeper Protocol

> Per-team GenServers that store overflow context across agent runs. Context Keepers
> are the persistent data substrate for long-running team work — a mesh of named
> processes that hold context no single agent can afford to carry in its own context
> window, retrievable on demand in three modes: keyword, smart, or full.

---

## Overview

Agent context windows are finite. Teams working on large, long-lived goals accumulate
more context than any single agent can hold across run boundaries. The Context Mesh
solves this by distributing context storage across a mesh of per-team GenServer
processes — each team's keeper holding the overflow that sessions cannot.

The key insight: context is not the same as session state. Session state (see
`sessions.md`) captures what a specific agent said during a specific run. Context
is the shared team knowledge that persists regardless of which agent is running —
decisions made, discoveries found, files changed, open questions, token budgets
consumed. The Context Mesh holds that shared layer.

Every team gets one Context Keeper. The keeper is a named process, always alive,
independently addressable. Agents read from it on wake. Agents write to it on
completion. The keeper scores every entry for staleness, auto-archives when entries
cross threshold, and tracks the team's aggregate token budget.

---

## Context Keeper Process Model

### GenServer Identity

Each Context Keeper is identified by its team:

```
ContextMesh.Keeper — named process per team
  registered name: {:via, Registry, {ContextMesh.Registry, team_id}}
  supervision: under ContextMesh.KeeperSupervisor
  restart: :permanent (keepers survive agent crashes)
```

### Process State

```elixir
defmodule ContextMesh.KeeperState do
  @type t :: %__MODULE__{
    team_id:        String.t(),
    entries:        [ContextEntry.t()],
    token_used:     non_neg_integer(),
    token_budget:   non_neg_integer(),
    created_at:     DateTime.t(),
    last_write_at:  DateTime.t() | nil,
    archive_count:  non_neg_integer()
  }
end
```

### Entry Schema

```elixir
defmodule ContextMesh.ContextEntry do
  @type t :: %__MODULE__{
    id:           String.t(),
    team_id:      String.t(),
    author_id:    String.t(),           # agent who wrote it
    content:      String.t(),
    content_type: :text | :json | :markdown,
    tags:         [String.t()],
    embedding:    [float()] | nil,      # populated on smart retrieval demand
    token_count:  non_neg_integer(),
    access_count: non_neg_integer(),
    relevance:    float(),              # 0.0–1.0 domain relevance score
    confidence:   float(),              # 0.0–1.0 author confidence
    created_at:   DateTime.t(),
    last_accessed_at: DateTime.t() | nil,
    archived:     boolean()
  }
end
```

### Lifecycle

```
Team created
  │
  ▼
┌──────────────────────┐
│ KeeperSupervisor     │
│ starts Keeper GenServer│
│ (permanent restart)  │
└──────────┬───────────┘
           │
           ▼ ← running indefinitely
┌──────────────────────┐
│ Keeper process        │
│                       │
│  - receives writes    │
│  - handles queries    │
│  - runs staleness     │
│    scoring (periodic) │
│  - auto-archives      │
│    stale entries      │
└──────────┬───────────┘
           │
           ▼ (team deleted or company shutdown)
┌──────────────────────┐
│ Graceful shutdown:    │
│ flush state to DB,    │
│ terminate             │
└──────────────────────┘
```

---

## Retrieval Modes

Three retrieval modes address different agent needs. The agent declares which mode
it needs at query time.

### Mode 1 — Keyword Retrieval

The cheapest retrieval. Agents supply a list of keywords; the keeper returns all
entries whose tags or content contain any of the keywords. No LLM calls. No
embedding computation.

```elixir
ContextMesh.query(team_id, {:keyword, ["auth", "JWT", "token_refresh"]})
# → [%ContextEntry{...}, ...]
```

**When to use**: Agent knows what it's looking for. Fast wake-time context load.
Low token cost — the agent pays only for entries returned, not retrieval.

**Implementation**:

```
Query arrives with keyword list
  │
  ▼
For each non-archived entry:
  - Check entry.tags ∩ keywords ≠ ∅
  - OR check tsvector(entry.content) @@ tsquery(keywords)
  │
  ▼
Sort by: relevance DESC, last_accessed DESC
Return matches, increment access_count on each
```

### Mode 2 — Smart Retrieval (LLM-Ranked)

The agent supplies a natural language query. The keeper computes embeddings on
demand (if not cached) and performs semantic similarity ranking via cosine distance.
Falls back to keyword if embeddings unavailable.

```elixir
ContextMesh.query(team_id, {:smart, "What authentication decisions did we make?"})
# → [%ContextEntry{...}, ...]  (ranked by semantic similarity)
```

**When to use**: Agent doesn't know the exact terms. Exploratory context recovery.
Higher cost — embedding computation adds latency and token usage.

**Implementation**:

```
Query arrives with natural language string
  │
  ▼
Embed the query string (text-embedding-3-small or equivalent)
  │
  ▼
For each non-archived entry without embedding:
  compute and cache entry.embedding
For each non-archived entry with embedding:
  score = cosine_similarity(query_embedding, entry.embedding)
  │
  ▼
Sort by: score DESC, confidence DESC
Return top-K (default: 10)
Increment access_count on returned entries
```

### Mode 3 — Full Retrieval

Returns ALL non-archived entries, sorted by recency. No filtering, no ranking.
Used for context reconstruction during onboarding or after a long gap.

```elixir
ContextMesh.query(team_id, :full)
# → [%ContextEntry{...}, ...]  (all non-archived, recency-sorted)
```

**When to use**: New agent joining an in-progress team. Post-incident reconstruction.
Highest token cost — agent should budget accordingly before requesting.

**Token cost warning**: Keeper returns a pre-flight estimate:

```elixir
ContextMesh.estimate(team_id, :full)
# → {:ok, %{entry_count: 47, estimated_tokens: 14_200}}
```

Agent may reject and fall back to keyword if budget is insufficient.

---

## 4-Factor Staleness Scoring

Every entry carries a staleness score `s ∈ [0, 100]`. Entries above 75 AND older
than 7 days are auto-archived. Staleness is re-evaluated on a periodic timer
(default: every 6 hours) and on every write to the keeper.

### Staleness Formula

```
s = w₁·age_score + w₂·access_score + w₃·relevance_score + w₄·confidence_score

weights:
  w₁ = 0.35  (time since last access)
  w₂ = 0.25  (inverse access frequency)
  w₃ = 0.25  (domain relevance)
  w₄ = 0.15  (author confidence)
```

### Factor Definitions

| Factor | Score (0–25) | Description |
|--------|-------------|-------------|
| **Age** (`age_score`) | `min(25, floor(hours_since_access / 24) × 2.5)` | Grows 2.5 points per day since last access. Caps at 25 (10 days). |
| **Access frequency** (`access_score`) | `25 - min(25, access_count × 2)` | Low access = high staleness contribution. 0 accesses = 25, 12+ accesses = 0. |
| **Relevance** (`relevance_score`) | `floor((1.0 - relevance) × 25)` | Low domain relevance = high staleness. Relevance 0.0 = 25, relevance 1.0 = 0. |
| **Confidence** (`confidence_score`) | `floor((1.0 - confidence) × 25)` | Low author confidence = high staleness. |

### Example Calculations

| Scenario | age | access | relevance | confidence | Total | Verdict |
|----------|-----|--------|-----------|-----------|-------|---------|
| Fresh, frequently used, high-confidence | 0 | 0 | 0 | 0 | **0** | Active |
| 3 days old, accessed twice, mid-relevance | 7.5 | 21 | 7.5 | 5 | **41** | Active |
| 8 days old, never accessed, low relevance | 20 | 25 | 20 | 15 | **80** | Archive candidate |
| 10 days, 0 access, 0 relevance, 0 confidence | 25 | 25 | 25 | 25 | **100** | Archive immediately |

### Auto-Archival

```
Staleness timer fires (every 6 hours)
  │
  ▼
For each entry:
  compute staleness score
  │
  ├── score < 75 → no action
  │
  ├── score >= 75 AND age_days < 7 → flag as "stale" (warning only)
  │
  └── score >= 75 AND age_days >= 7
        → archive: set entry.archived = true
        → release entry.token_count from token_used
        → increment archive_count
        → log: {entry_id, score, reason: "auto_archived"}
```

Archived entries are not deleted. They move to cold storage and can be retrieved
by explicit ID reference but are excluded from all three query modes by default.

---

## Token Tracking and Budget Allocation

The keeper tracks token consumption for the team's context budget.

### Budget Schema

```yaml
context_mesh:
  token_budget: 100_000        # total tokens this team's keeper may hold
  warning_threshold: 0.80      # alert at 80% utilization
  hard_ceiling: 0.95           # reject writes above 95%
  archival_trigger: 0.90       # force archival pass at 90%
```

### Budget Enforcement

```
Write request arrives (new entry, token_count: N)
  │
  ▼
Check: token_used + N > hard_ceiling × token_budget
  │
  ├── Yes → reject write, return {:error, :budget_exceeded}
  │
  ▼
Check: token_used + N > archival_trigger × token_budget
  │
  ├── Yes → run staleness pass first, then retry write
  │
  ▼
Accept write, increment token_used by N
  │
  ▼
Check: token_used > warning_threshold × token_budget
  └── Yes → emit :context_budget_warning telemetry event
```

### Budget Allocation by Team Role

Teams inherit a base budget from their department's context mesh allocation.
Individual teams may override within their department ceiling:

| Team Type | Default Token Budget | Rationale |
|-----------|---------------------|-----------|
| Research / analysis teams | 150,000 | High context accumulation from source material |
| Engineering teams | 100,000 | Moderate accumulation (code decisions + discoveries) |
| Operations / support teams | 50,000 | Lower churn, tighter budgets |
| Ephemeral task teams | 25,000 | Short-lived, minimal context |

---

## Write Protocol

Agents write to their team's keeper at heartbeat step 8 (after completing work).
The write is best-effort — a write failure does not fail the heartbeat run.

```elixir
# Agent writes context after completing a task
ContextMesh.write(team_id, %{
  author_id: agent_id,
  content: "Implemented JWT refresh via RS256. Key stored in Vault at /secrets/jwt-rs256.",
  content_type: :markdown,
  tags: ["jwt", "auth", "vault", "rs256"],
  relevance: 0.9,
  confidence: 0.95
})
# → {:ok, %ContextEntry{id: "ctx-abc123", ...}}
```

### Write Validation

| Check | Rule | On Failure |
|-------|------|-----------|
| Content length | min 10 chars, max 8,000 tokens | Reject |
| Author exists | author_id must be a known agent | Reject |
| Team exists | team_id must have an active keeper | Reject |
| Budget | token_used + new_tokens ≤ hard_ceiling | Reject |
| Duplicate | same content from same author within 5 min | Deduplicate (return existing) |

---

## Keeper Supervision Tree

```
ContextMesh.Application
  │
  ├── ContextMesh.Registry          (process registry — maps team_id → PID)
  │
  └── ContextMesh.KeeperSupervisor  (DynamicSupervisor)
        │
        ├── Keeper (team: "eng-team-alpha")
        ├── Keeper (team: "research-team-beta")
        ├── Keeper (team: "ops-team-gamma")
        └── ... (one per active team)
```

### Keeper Start/Stop

```elixir
# Start a keeper for a new team
ContextMesh.KeeperSupervisor.start_keeper(team_id, opts)

# Stop a keeper (team archived or deleted)
ContextMesh.KeeperSupervisor.stop_keeper(team_id)

# Restart a crashed keeper (automatic via supervisor)
# On restart: reload state from persistent store (DB/filesystem)
```

### Persistence

Keeper state is checkpointed to a persistent store on every write and on graceful
shutdown. On restart (crash recovery), the keeper rehydrates from the checkpoint:

```
Keeper restarts
  │
  ▼
Load checkpoint from DB:
  SELECT * FROM context_entries WHERE team_id = ? AND archived = false
  │
  ▼
Rebuild in-memory state:
  token_used = sum(token_count) of loaded entries
  entries = loaded entries (sorted by created_at)
  │
  ▼
Resume normal operation
```

---

## Signal Theory Position

The Context Mesh implements **Layer 5 (The Data Layer)** of the Optimal System.

```
OS Layer 5 — The Data Layer
  ↕
ContextMesh.Keeper — per-team persistent substrate

STORAGE:       Keepers ARE the persistent data substrate for running teams.
               The 4-layer memory system (memory-architecture.md) handles
               long-term individual memory. The Context Mesh handles shared,
               in-flight team context — the working data layer for active goals.

PROCESS:       Three retrieval modes implement Shannon's channel principle —
               keyword retrieval minimizes channel cost (no LLM), smart retrieval
               maximizes semantic fidelity (embedding + ranking), full retrieval
               maximizes coverage at maximum channel cost. Agent selects the
               mode that matches its budget and fidelity need.

ARCHIVE:       Auto-archival at staleness threshold implements entropy management.
               Data that has lost informational value (old, unaccessed, low
               confidence) is removed from the active channel to preserve
               signal-to-noise ratio for agents querying the keeper.
```

### Governing Principle: Ashby — Requisite Variety

The keeper's variety must match the signal variety the team encounters. A keeper
that stores only structured JSON cannot hold free-form research notes. A keeper
that stores only recent entries cannot support teams with multi-week work cycles.

The three-mode retrieval system, multi-format content types, and configurable token
budgets give the keeper sufficient variety (Ashby) to serve any team configuration
without violating Shannon's channel capacity.

### Governing Principle: Beer — Viable Structure

Context Keepers are S2 (Coordination) at the team scope. They hold the shared
context that prevents agents from duplicating work, contradicting each other, or
losing decisions across run boundaries. Without the keeper, the team degrades into
a collection of amnesiac agents — a Beer S2 failure.

---

## See Also

- [memory-architecture.md](memory-architecture.md) — 4-layer individual memory system (complement to team context)
- [sessions.md](sessions.md) — Per-agent session state (what this agent did last run)
- [team-coordination.md](team-coordination.md) — Filesystem-based coordination layer the keeper extends
- [heartbeat.md](heartbeat.md) — Step 6 (understand context) reads from keeper; step 8 (update) writes to keeper
- [tiered-loading.md](tiered-loading.md) — L1/L2 loading that context queries feed into
- [optimal-system-mapping.md](optimal-system-mapping.md) — Full 7-layer OS mapping

---

*Context Mesh v1.0 — Per-team context keeper protocol with staleness scoring and budget-aware retrieval*
