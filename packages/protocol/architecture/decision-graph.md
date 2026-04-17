# Decision Graph — Structured Decision Tracking

> A directed acyclic graph where every significant decision, option, goal,
> observation, and revisit is a node. Confidence propagates through edges.
> Pivots are atomic four-node transitions. The graph generates narrative
> summaries and pulse health reports on demand.

---

## Overview

Decisions degrade silently. An agent makes a choice, moves on, and three runs
later a colleague makes a contradictory choice — unaware the first was made.
The Decision Graph prevents this by making every decision a first-class, persistent,
queryable node in a shared structure.

More critically: the graph captures WHY decisions were made, not just WHAT was
decided. Goals motivate options. Observations constrain choices. Revisits document
the moment a previous decision was superseded. When confidence in an upstream node
changes, that change cascades through all downstream nodes — no stale rationale,
no orphaned decisions.

The Decision Graph is the team's long-term decision memory. It answers:
"What have we decided, why, how confident are we, and what changed?"

---

## DAG Structure

### Node Types

| Type | What It Represents | Required Fields |
|------|-------------------|----------------|
| `decision` | A choice the team has committed to | `statement`, `confidence`, `decided_by`, `decided_at` |
| `option` | A candidate approach that was considered | `description`, `status` (accepted/rejected/deferred) |
| `goal` | The objective motivating a set of decisions | `statement`, `priority` (1–5) |
| `observation` | A fact or finding that influenced a decision | `content`, `source`, `observed_at` |
| `revisit` | A marker indicating a prior decision was reopened | `reason`, `trigger`, `created_at` |

### Edge Types

| Edge Type | From → To | Semantic |
|-----------|-----------|---------|
| `motivated_by` | `decision` → `goal` | This decision serves this goal |
| `chose` | `decision` → `option` | This option was selected |
| `rejected` | `decision` → `option` | This option was considered and rejected |
| `constrained_by` | `decision` → `observation` | This observation constrained the decision |
| `supersedes` | `decision` → `decision` | The new decision replaces the old one |
| `led_to` | `observation` → `revisit` | This finding triggered a revisit |
| `reopened` | `revisit` → `decision` | This revisit reopened this decision |
| `resulted_in` | `revisit` → `decision` | This revisit produced this new decision |
| `supports` | `observation` → `option` | This observation supports this option |
| `undermines` | `observation` → `option` | This observation argues against this option |

### Visual Topology

```
┌────────────────────────────────────────────────────────┐
│                       GOAL                             │
│  "Ship auth system by March 30 with RS256 JWT"         │
└─────────────────────┬──────────────────────────────────┘
                      │ motivated_by
                      ▼
              ┌───────────────┐
              │   DECISION    │◄──────── constrained_by ──── OBSERVATION
              │  "Use RS256   │                               "HS256 key
              │   algorithm"  │                               rotation is
              │  confidence:  │                               operationally
              │  0.9          │                               complex"
              └───────┬───┬───┘
                      │   │
              chose   │   │  rejected
                      ▼   ▼
              ┌────────┐ ┌────────────┐
              │ OPTION │ │   OPTION   │
              │ RS256  │ │   HS256    │
              │(chosen)│ │ (rejected) │
              └────────┘ └────────────┘
```

---

## Node Schema

### Decision Node

```elixir
defmodule DecisionGraph.Node.Decision do
  @type t :: %__MODULE__{
    id:           String.t(),
    team_id:      String.t(),
    statement:    String.t(),
    rationale:    String.t() | nil,
    confidence:   float(),            # 0.0–1.0
    status:       :active | :superseded | :revisited,
    decided_by:   String.t(),         # agent_id
    decided_at:   DateTime.t(),
    edges_out:    [Edge.t()],
    edges_in:     [Edge.t()]
  }
end
```

### Option Node

```elixir
defmodule DecisionGraph.Node.Option do
  @type t :: %__MODULE__{
    id:           String.t(),
    team_id:      String.t(),
    description:  String.t(),
    pros:         [String.t()],
    cons:         [String.t()],
    status:       :accepted | :rejected | :deferred | :pending,
    proposed_by:  String.t(),
    proposed_at:  DateTime.t()
  }
end
```

### Observation Node

```elixir
defmodule DecisionGraph.Node.Observation do
  @type t :: %__MODULE__{
    id:           String.t(),
    team_id:      String.t(),
    content:      String.t(),
    source:       String.t(),         # agent, tool, human, external
    observed_at:  DateTime.t(),
    confidence:   float()
  }
end
```

### Revisit Node

```elixir
defmodule DecisionGraph.Node.Revisit do
  @type t :: %__MODULE__{
    id:           String.t(),
    team_id:      String.t(),
    reason:       String.t(),
    trigger:      :new_observation | :failed_assumption | :goal_change | :manual,
    triggered_by: String.t(),         # agent_id or "human"
    created_at:   DateTime.t()
  }
end
```

---

## Confidence Cascade

When the confidence of a node changes, the change propagates to all downstream
nodes through a cascade algorithm. This keeps the graph self-consistent —
low-confidence upstream facts are automatically reflected as lower confidence
in the decisions they support.

### Propagation Formula

For each edge `(source, target, edge_type)`, the confidence discount applied is:

```
target.confidence_effective = target.confidence × discount(edge_type) × source.confidence

discount factors by edge type:
  motivated_by:   0.95   (goal confidence weakly discounts decision)
  constrained_by: 0.90   (observation confidence moderately discounts decision)
  chose:          1.00   (chosen option confidence flows directly)
  supports:       0.85   (supporting observation discounted)
  undermines:     0.80   (undermining observation discounts the opposing option)
```

### Cascade Algorithm

```
Confidence update on node N (new_confidence)
  │
  ▼
1. Update N.confidence = new_confidence
   │
   ▼
2. Enqueue all outgoing edges of N: {edge, target_node}
   │
   ▼
3. For each (edge, target) in queue (BFS traversal):
   effective = target.confidence × discount(edge.type) × N.confidence_effective
   │
   ├── effective changes by > 0.01 → update target.confidence_effective
   │   → enqueue target's outgoing edges
   │
   └── effective changes by ≤ 0.01 → no further propagation (convergence)
   │
   ▼
4. Emit :confidence_cascade_complete telemetry
   {root_node: N.id, nodes_updated: count, max_depth: depth}
```

### Cycle Detection

The graph is a DAG by construction. Before any edge is added, a cycle check runs:

```elixir
defmodule DecisionGraph.CycleDetector do
  def would_create_cycle?(graph, source_id, target_id) do
    # DFS from target_id — if source_id is reachable, adding this edge creates a cycle
    reachable_from(graph, target_id) |> MapSet.member?(source_id)
  end
end
```

Rejected edges are logged with `{:error, :would_create_cycle}`. The proposing agent
receives an explanation and must restructure the relationship.

---

## Pivot Chains

A pivot is the atomic sequence of events when a decision is overturned. Pivots are
not destructive — the old decision is preserved with `status: :superseded`. The
full chain is:

```
old_decision ──[led_to via observation]──→ revisit_node
                                                │
                                          resulted_in
                                                │
                                                ▼
                                          new_decision
                                                │
                                          supersedes
                                                │
                                                ▼
                                          old_decision
                                          (status: superseded)
```

### Pivot Transaction

A pivot is an atomic 4-node, 3-edge operation. It either succeeds fully or rolls
back entirely — no partial pivots.

```elixir
defmodule DecisionGraph.Pivot do
  def execute(graph, old_decision_id, observation_content, new_decision_statement, opts) do
    Repo.transaction(fn ->
      # 1. Create observation node
      obs = Node.Observation.create!(%{
        content: observation_content,
        source: opts[:triggered_by],
        confidence: opts[:confidence] || 0.8
      })

      # 2. Create revisit node
      revisit = Node.Revisit.create!(%{
        reason: opts[:reason],
        trigger: opts[:trigger] || :new_observation,
        triggered_by: opts[:triggered_by]
      })

      # 3. Create new decision node
      new_decision = Node.Decision.create!(%{
        statement: new_decision_statement,
        confidence: opts[:new_confidence] || 0.7,
        decided_by: opts[:decided_by]
      })

      # 4. Wire edges
      Edge.create!(obs, revisit, :led_to)
      Edge.create!(revisit, old_decision_id, :reopened)
      Edge.create!(revisit, new_decision, :resulted_in)
      Edge.create!(new_decision, old_decision_id, :supersedes)

      # 5. Mark old decision superseded
      Node.Decision.update_status!(old_decision_id, :superseded)

      # 6. Cascade confidence from new decision
      ConfidenceCascade.propagate(graph, new_decision.id)

      {:ok, %{observation: obs, revisit: revisit, new_decision: new_decision}}
    end)
  end
end
```

### Pivot Audit Trail

Every pivot is logged to the audit table with the full chain:

```
pivot_log
  ├── id
  ├── team_id
  ├── old_decision_id
  ├── observation_id
  ├── revisit_id
  ├── new_decision_id
  ├── triggered_by        (agent_id or "human")
  ├── trigger_reason
  └── executed_at
```

---

## Subtree Merging

When two branches of the graph converge on the same goal, their decision subtrees
can be merged — consolidating redundant reasoning into a single canonical path.

### Merge Conditions

Merge is proposed when:
- Two or more decisions share the same `motivated_by` goal
- Their option sets overlap (Jaccard similarity of option descriptions > 0.7)
- Both have status: `active`

### Merge Protocol

```
Merge proposed: {subtree_A, subtree_B, target_goal}
  │
  ▼
1. Compute merged option set: union of A.options and B.options
   Deduplicate by description similarity (> 0.85 = same option)
   │
   ▼
2. Propose merged decision to team:
   statement: highest-confidence statement between A and B
   confidence: max(A.confidence, B.confidence) × 0.95 (slight discount for merge)
   options: merged set
   │
   ▼
3. Require confirmation from at least one team agent (or leader)
   │
   ├── Confirmed → execute merge transaction
   │     - Mark A and B as :superseded
   │     - Create merged decision node
   │     - Rewire all outgoing edges from A and B to merged node
   │     - Run confidence cascade from merged node
   │
   └── Rejected → leave subtrees separate, log merge_proposal_rejected
```

---

## Narrative Generation

The graph can produce a human-readable narrative describing the team's decision
history. This is used in pulse reports, context keeper writes, and handoff notes.

### Narrative Algorithm

```
DecisionGraph.Narrative.generate(team_id, opts)
  │
  ▼
1. Load all goals (sorted by priority)
   │
   ▼
2. For each goal, traverse the decision subtree:
   - Active decisions (status: active)
   - Their chosen options
   - Key observations that constrained them
   - Any pivots in the chain (revisit nodes)
   │
   ▼
3. Order events chronologically (decided_at, observed_at)
   │
   ▼
4. Render as markdown:

## Decisions for Goal: {goal.statement}

### {decision.statement}
**Decided by**: {agent_name} on {date}
**Confidence**: {confidence × 100}%
**Rationale**: {rationale}

**Options considered**:
- {chosen_option} ← Chosen
- {rejected_option_1} — Rejected: {rejection_reason}
- {rejected_option_2} — Deferred

**Key observations**:
- {observation_1.content} (source: {source})

{if pivots exist}
**Revision history**:
- Reopened on {revisit.created_at}: {revisit.reason}
  → Replaced by: {new_decision.statement}
```

### Pulse Health Report

The graph generates a health report capturing decision system health metrics:

```
DecisionGraph.Pulse.report(team_id)
# → %{
#     total_decisions: 14,
#     active_decisions: 11,
#     superseded_decisions: 3,
#     pivot_count: 2,
#     avg_confidence: 0.78,
#     low_confidence_decisions: [
#       %{id: "...", statement: "...", confidence: 0.45}
#     ],
#     goals_without_decisions: [...],
#     stale_observations: [...],   # observations > 14 days with no linked decision
#     health_score: 0.81           # composite: confidence × coverage × recency
#   }
```

---

## Graph Storage

### Schema

```sql
CREATE TABLE decision_nodes (
  id           TEXT PRIMARY KEY,
  team_id      TEXT NOT NULL,
  node_type    TEXT NOT NULL,  -- decision | option | goal | observation | revisit
  data         JSONB NOT NULL, -- type-specific fields
  status       TEXT,           -- active | superseded | revisited (decisions only)
  confidence   REAL,
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
);

CREATE TABLE decision_edges (
  id           TEXT PRIMARY KEY,
  team_id      TEXT NOT NULL,
  source_id    TEXT NOT NULL REFERENCES decision_nodes(id),
  target_id    TEXT NOT NULL REFERENCES decision_nodes(id),
  edge_type    TEXT NOT NULL,
  created_at   TEXT NOT NULL
);

CREATE INDEX idx_decision_nodes_team ON decision_nodes(team_id);
CREATE INDEX idx_decision_edges_source ON decision_edges(source_id);
CREATE INDEX idx_decision_edges_target ON decision_edges(target_id);
```

---

## Signal Theory Position

The Decision Graph implements **Layer 6 (The Feedback Loop)** of the Optimal System.

```
OS Layer 6 — The Feedback Loop
  ↕
DecisionGraph — confidence cascade on every state change

CIRCULAR CAUSALITY: Every observation that enters the graph potentially
  changes confidence in downstream decisions. Changed confidence propagates
  immediately through the cascade algorithm — closing the loop between
  new information and existing commitments.

FEEDBACK CLOSURE (Wiener): The confidence cascade IS the feedback mechanism.
  When an agent makes a new observation that undermines a prior choice,
  the cascade immediately degrades the confidence of that choice and all
  downstream nodes that depended on it. No stale rationale. No orphaned
  confidence scores.

PIVOT CHAINS are the system's self-correction mechanism. They implement
  Wiener's requirement that feedback actually changes behavior — not just
  records failure. A pivot doesn't just note that a decision was wrong;
  it produces a new decision (corrected behavior) and marks the old one
  superseded (closes the loop on the error).
```

### Governing Principle: Wiener — Feedback Closure

The confidence cascade closes the feedback loop on every decision. When the
confidence in an observation changes, every decision that cited that observation
via `constrained_by` is immediately re-scored. A feedback system that can only
detect errors but cannot propagate the correction is a Wiener violation.
The cascade is the correction mechanism.

### Governing Principle: Beer — Viable Structure

The Decision Graph implements S4 (Intelligence) at the team scope — it is the
team's mechanism for scanning its own decision-making, detecting drift, and
surfacing low-confidence decisions for review. The pulse health report IS the
S4 intelligence output: "Here is the state of our decision-making. These nodes
are fragile. These goals have no decisions yet."

---

## See Also

- [context-mesh.md](context-mesh.md) — Keepers hold decision summaries as context entries
- [peer-protocol.md](peer-protocol.md) — Handoffs include `decisions_made` referencing graph nodes
- [self-healing.md](self-healing.md) — Healing episodes create observation nodes when root causes are identified
- [team-coordination.md](team-coordination.md) — Leader creates decision nodes when decomposing goals
- [memory-architecture.md](memory-architecture.md) — Semantic memory stores extracted facts; decision graph stores structured choices
- [optimal-system-mapping.md](optimal-system-mapping.md) — Full 7-layer OS mapping

---

*Decision Graph v1.0 — DAG-structured decision tracking with confidence cascade, pivot chains, and narrative generation*
