# Speculative Execution — Anticipatory Work Protocol

> Agents predict likely next tasks and start working before assignment.
> Speculative work runs in isolation — temporary directories, staged files,
> in-memory decisions. If assumptions hold, work is promoted to real state.
> If they don't, work is cleanly discarded. The system bets on high-probability
> signals.

---

## Overview

Agents wait. Between runs, between task assignments, between approval gates —
there are predictable gaps where the next work is highly probable but not yet
formally assigned. Speculative execution captures that idle time.

The principle: if an agent can predict with high confidence what the next task
will be, it can start working on it before that task exists. When the prediction
is confirmed (the expected task arrives), the work is promoted — merged into real
state. When the prediction is wrong, the work is discarded. Net cost: near zero
for correct predictions. Net gain: latency eliminated for the most common next-steps.

Speculative execution is not guessing. It operates on high-probability predictions
backed by explicit assumptions that are tracked and checked. A prediction that is
not checkable is not a valid speculative target.

---

## Speculative Work Model

### Work Unit Schema

```elixir
defmodule SpeculativeExecution.WorkUnit do
  @type t :: %__MODULE__{
    id:                 String.t(),
    agent_id:           String.t(),
    team_id:            String.t(),
    prediction:         Prediction.t(),
    assumptions:        [Assumption.t()],
    isolation:          Isolation.t(),
    state:              :running | :completed | :promoted | :discarded,
    started_at:         DateTime.t(),
    completed_at:       DateTime.t() | nil,
    promoted_at:        DateTime.t() | nil,
    discarded_at:       DateTime.t() | nil,
    discard_reason:     String.t() | nil,
    token_cost:         non_neg_integer()
  }
end
```

### Prediction Schema

```elixir
defmodule SpeculativeExecution.Prediction do
  @type t :: %__MODULE__{
    description:        String.t(),     # "After agent B finishes auth, I will need to update the API schema"
    predicted_task_id:  String.t() | nil, # if a specific task is expected
    predicted_trigger:  atom(),         # :task_completion | :time_based | :dependency_resolved | :pattern
    confidence:         float(),        # 0.0–1.0. Only proceed if >= 0.70
    basis:              String.t()      # why this prediction was made
  }
end
```

### Minimum Confidence Threshold

Speculative work only starts if `prediction.confidence >= 0.70`. Below that
threshold, the probability of wasted work exceeds the potential latency gain.

| Confidence | Interpretation | Action |
|-----------|---------------|--------|
| < 0.70 | Too uncertain | Do not speculate |
| 0.70–0.85 | Probable | Speculate with conservative budget |
| 0.85–0.95 | Likely | Speculate with standard budget |
| > 0.95 | Near-certain | Speculate with full budget |

---

## Assumption Tracking

Every speculative work unit must declare its assumptions explicitly. Assumptions
are the checkable conditions that, if false, invalidate the work.

### Assumption Schema

```elixir
defmodule SpeculativeExecution.Assumption do
  @type t :: %__MODULE__{
    id:           String.t(),
    description:  String.t(),
    check_fn:     String.t(),     # serialized check function reference
    status:       :unchecked | :valid | :invalid,
    checked_at:   DateTime.t() | nil,
    actual_value: any()           # populated when checked
  }
end
```

### Example Assumptions

```elixir
# Assumption: agent B's task completes successfully
%Assumption{
  description: "Task LUN-042 (auth implementation) completes with status: done",
  check_fn: "Tasks.status_is?(\"LUN-042\", :done)",
  status: :unchecked
}

# Assumption: the API schema being extended has not been modified
%Assumption{
  description: "File lib/api/schema.ex has not changed since speculation began",
  check_fn: "Git.file_unchanged?(\"lib/api/schema.ex\", since: work_unit.started_at)",
  status: :unchecked
}

# Assumption: the target feature flag is still enabled
%Assumption{
  description: "Feature flag :new_auth_system is enabled in the target environment",
  check_fn: "FeatureFlags.enabled?(:new_auth_system, env: :production)",
  status: :unchecked
}
```

### Assumption Check Protocol

Assumptions are checked in two phases:

**Phase 1 — Pre-work check** (before starting speculative work):

```
All assumptions checked: can any be immediately invalidated?
  │
  ├── Any assumption immediately invalid → do not start speculation
  │
  └── All assumptions valid or unchecked → proceed
```

**Phase 2 — Pre-promote check** (before promoting work to real state):

```
All assumptions re-checked at promotion time
  │
  ├── Any assumption invalid → discard work (not promote)
  │
  └── All assumptions valid → promote work
```

### Invalidation

When an assumption is invalidated mid-execution (an external change occurs while
speculative work is running), the work unit is immediately discarded:

```
External change detected (file changed, task cancelled, flag flipped)
  │
  ▼
Re-evaluate all assumptions for running work units
  │
  ▼
Work unit W has assumption A that is now invalid
  │
  ▼
Signal W: :assumption_invalidated
  │
  ▼
W transitions to state: :discarded
  discard_reason: "Assumption '{A.description}' invalidated at {time}"
  │
  ▼
Isolation layer cleaned up (temp dirs deleted, staged files removed)
```

---

## Work Product Isolation

Speculative work runs in full isolation. It cannot modify real state until
explicitly promoted.

### Isolation Layer

```elixir
defmodule SpeculativeExecution.Isolation do
  @type t :: %__MODULE__{
    temp_dir:         String.t(),           # e.g., /tmp/speculative/work-{id}/
    staged_files:     [StagedFile.t()],     # files written during speculation
    in_memory:        %{
      messages: [Message.t()],              # task comments, inbox messages
      decisions: [DecisionNode.t()],        # decision graph additions
      context_entries: [ContextEntry.t()]  # context keeper writes
    }
  }
end

defmodule SpeculativeExecution.StagedFile do
  @type t :: %__MODULE__{
    staging_path: String.t(),     # where the file lives during speculation
    target_path:  String.t(),     # where it will be placed on promotion
    operation:    :create | :modify | :delete
  }
end
```

### Temp Directory

Every work unit gets a dedicated temp directory:

```
/tmp/speculative/work-{unit_id}/
├── files/                     # staged file contents
│   ├── lib/api/schema.ex      # mirror of target path structure
│   └── test/api/schema_test.exs
├── metadata.json              # work unit ID, started_at, assumptions
└── diff.patch                 # git diff of all staged changes (generated at completion)
```

The temp directory is the agent's entire writable world during speculation.
All file writes are redirected here via the speculative filesystem shim.

### In-Memory Buffers

During speculation, outbound signals (task comments, decision graph writes,
context keeper writes) are buffered in memory — not sent:

```elixir
# During speculation: intercepted and buffered
Tasks.add_comment(task_id, "Updated schema to include auth token fields")
# → stored in isolation.in_memory.messages, not posted

DecisionGraph.add_decision(team_id, %{statement: "Use snake_case for all new fields"})
# → stored in isolation.in_memory.decisions, not written to graph

ContextMesh.write(team_id, %{content: "Schema extended with auth_token, expires_at"})
# → stored in isolation.in_memory.context_entries, not written to keeper
```

These buffered signals are either flushed to their real destinations on promotion
or dropped on discard.

---

## Promote vs. Discard

### Promotion Protocol

When the predicted trigger fires and all assumptions are valid:

```
Trigger fires: {predicted_trigger matches observed event}
  │
  ▼
Phase 2 assumption check: re-validate all assumptions
  │
  ├── Any invalid → DISCARD (see below)
  │
  └── All valid → PROMOTE
        │
        ▼
        1. Apply staged files to real workspace:
           For each staged_file:
             - :create → copy temp_path to target_path
             - :modify → apply diff.patch to target_path
             - :delete → delete target_path
        │
        ▼
        2. Flush in-memory buffers to real destinations:
           - messages → post to task comment thread
           - decisions → write to decision graph
           - context_entries → write to context keeper
        │
        ▼
        3. Link work unit to promoted task:
           task.speculative_unit_id = work_unit.id
           (for audit trail and cost attribution)
        │
        ▼
        4. Clean up temp directory
        │
        ▼
        5. Update work unit: state: :promoted, promoted_at: now()
        │
        ▼
        6. Log: {unit_id, tokens_spent, latency_saved_estimate}
```

### Discard Protocol

When assumptions are invalidated or the predicted trigger does not fire:

```
Discard condition met:
  assumption invalid OR max_wait_time exceeded OR agent explicitly cancels
  │
  ▼
1. Stop any in-progress agent execution
   │
   ▼
2. Delete temp directory:
   File.rm_rf!("/tmp/speculative/work-#{unit_id}/")
   │
   ▼
3. Drop in-memory buffers:
   isolation.in_memory = %{messages: [], decisions: [], context_entries: []}
   │
   ▼
4. Update work unit: state: :discarded, discarded_at: now(), discard_reason: reason
   │
   ▼
5. Log: {unit_id, tokens_spent, discard_reason}
   (discarded token spend is charged to the team's speculative execution budget)
```

### Discard Budget

Discarded work still costs tokens. A discard budget limits speculative exposure:

```yaml
speculative_execution:
  max_concurrent_units: 3       # per agent
  discard_budget_per_day: 10_000  # tokens that can be wasted on discards
  max_wait_before_discard: 4h   # how long to hold speculative work waiting for trigger
  min_confidence: 0.70
```

When `discard_budget_per_day` is exhausted, no new speculative work starts until
the next day. Past discard rate is tracked and used to adjust future minimum
confidence thresholds:

```
discard_rate = discards_last_7_days / total_speculations_last_7_days
  │
  ├── discard_rate > 0.40 → raise min_confidence by 0.05 (speculation too aggressive)
  │
  └── discard_rate < 0.10 → lower min_confidence by 0.02 (speculation too conservative)
```

---

## Prediction Patterns

Common patterns that agents use to form predictions:

### Pattern: Downstream Dependency

```
When: I am assigned a task that depends on task X
Predict: After X completes, I will be unblocked and need to {next_action}
Assumptions:
  - Task X will complete (not be cancelled)
  - The output of X will be compatible with my expected input format
Confidence: 0.75–0.90 (depends on X's current progress)
```

### Pattern: Sequential Phase

```
When: I am in phase N of a known N-phase workflow
Predict: After this phase completes, phase N+1 will be assigned to me or a peer
Assumptions:
  - No phase is skipped
  - Phase N+1 input is the output of phase N
Confidence: 0.85–0.95 (workflow structure is known)
```

### Pattern: Recurring Task

```
When: A task of type T is assigned every {interval} or after event E
Predict: The next occurrence of T is coming
Assumptions:
  - The recurring pattern continues
  - The context (team, workflow) has not changed significantly
Confidence: 0.75–0.85 (based on historical recurrence rate)
```

### Pattern: Leader Decomposition

```
When: I observe the leader creating a batch of related tasks
Predict: I will be assigned one of the remaining unassigned tasks in this batch
Assumptions:
  - Leader assigns by role/capability match (my role matches unassigned tasks)
  - No other agent with matching capabilities is available
Confidence: 0.70–0.80 (depends on team composition)
```

---

## Speculative Execution Lifecycle Diagram

```
Agent observes trigger condition (dependency nearing completion, phase advancing...)
  │
  ▼
Form prediction: {description, confidence, trigger}
  │
  ├── confidence < 0.70 → skip, do not speculate
  │
  └── confidence >= 0.70 → declare assumptions
         │
         ▼
         Phase 1 assumption check
         │
         ├── any immediately invalid → skip
         │
         └── all valid → start speculative work
               │
               ▼
         ┌─────────────────────────────────┐
         │  ISOLATION ACTIVE               │
         │  temp_dir: /tmp/speculative/... │
         │  in_memory buffers: active      │
         └────────────────┬────────────────┘
                          │ work executing...
                          │
              ┌───────────┴───────────┐
              │                       │
        trigger fires           assumption
              │                 invalidated
              ▼                       │
         Phase 2 check               ▼
              │                   DISCARD
              ├── invalid        (clean delete)
              │      ↓
              │   DISCARD
              │   (clean delete)
              │
              └── valid
                     ↓
                  PROMOTE
                  (apply to real state)
```

---

## Signal Theory Position

The Speculative Execution subsystem implements **Layer 4 (The Interface)** of the
Optimal System.

```
OS Layer 4 — The Interface
  ↕
SpeculativeExecution — anticipatory interface, pre-computing likely next signals

PROGRESSIVE DISCLOSURE IN TIME: Layer 4 defines how the system progressively
  discloses context to agents as they need it (tiered loading: L0 → L1 → L2).
  Speculative execution is progressive disclosure applied to temporal context —
  the system pre-computes the context the agent will need in the next time window,
  before the agent formally needs it. The agent's interface with the future.

SHANNON: Speculative work bets on high-probability signals. Shannon's channel
  theorem implies that if a signal has high predictability (high probability,
  low entropy), encoding it in advance costs less than encoding it on-demand.
  Correct speculation = zero latency for that signal. The min_confidence threshold
  (0.70) is the Shannon break-even: below it, the expected cost of wasted speculation
  exceeds the expected gain from correct prediction.

ISOLATION AS CHANNEL SEPARATION: The temp directory and in-memory buffers are
  channel separation — they prevent speculative signals from contaminating the
  real channel until validity is confirmed. This is the Interface layer's
  responsibility: manage what the system exposes to downstream consumers (real
  state) vs. what it keeps in speculative pre-processing.
```

### Governing Principle: Shannon — Channel Capacity

Speculative work bets on high-probability signals. A correct prediction eliminates
a round-trip latency cost — the channel carries the signal before the receiver
formally requests it. The discard budget tracks the cost of wrong predictions.
The adaptive confidence threshold ensures the system learns: when it speculates
too aggressively (high discard rate), it raises the confidence bar. Shannon
efficiency is maintained through this feedback loop.

### Governing Principle: Beer — Viable Structure

Speculative execution must maintain system viability under speculation. A system
that promotes incorrect speculative work without assumption validation would corrupt
real state — a Beer structure failure. The promotion protocol (Phase 2 check, then
atomic apply) ensures speculation never degrades viability: either it helps (correct
prediction, clean promotion) or it leaves no trace (invalid assumptions, clean discard).

---

## See Also

- [heartbeat.md](heartbeat.md) — Agents start speculative work during idle periods between heartbeat cycles
- [context-mesh.md](context-mesh.md) — Context keeper writes are buffered during speculation, flushed on promotion
- [decision-graph.md](decision-graph.md) — Decision nodes are buffered during speculation, flushed on promotion
- [peer-protocol.md](peer-protocol.md) — Task negotiation can transfer speculative work to a peer
- [sessions.md](sessions.md) — Speculative sessions are isolated from real task sessions until promotion
- [tiered-loading.md](tiered-loading.md) — L1/L2 loading used to pre-load context for predicted tasks
- [optimal-system-mapping.md](optimal-system-mapping.md) — Full 7-layer OS mapping

---

*Speculative Execution v1.0 — Anticipatory work protocol with assumption tracking, isolation, and atomic promote/discard*
