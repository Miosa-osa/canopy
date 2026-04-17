# Peer Protocol — Agent-to-Agent Coordination

> Structured handoffs, peer review gates, task negotiation, cross-team discovery,
> and region-level file locking. Agents coordinate as peers — not just through
> their shared leader — with formal protocols that prevent conflicts, close
> information gaps, and enable lateral collaboration without governance overhead.

---

## Overview

The leader-worker hierarchy (see `team-coordination.md`) handles vertical
coordination: leader decomposes, workers execute, results flow upward. Peer
Protocol handles horizontal coordination: agent-to-agent handoffs when work
passes between specialists, review requests that block task completion until
a peer accepts, negotiated task transfers, and file locking that prevents
two agents from editing the same region simultaneously.

The design tension: horizontal coordination is faster than routing everything
through a leader, but direct peer-to-peer interaction creates coordination risk
(conflicts, duplicate work, information asymmetry). Peer Protocol resolves this
by making every peer interaction a formal, tracked protocol exchange — not
an informal API call.

---

## Structured Handoffs

A handoff is a formal context transfer from one agent to another. It carries
everything the receiving agent needs to continue work without reading the task's
full history.

### Handoff Schema

```elixir
defmodule PeerProtocol.Handoff do
  @type t :: %__MODULE__{
    id:               String.t(),
    from_agent_id:    String.t(),
    to_agent_id:      String.t(),
    task_id:          String.t(),
    actions_taken:    [String.t()],     # what was done (ordered list)
    discoveries:      [String.t()],     # non-obvious findings worth knowing
    files_changed:    [FileChange.t()], # files modified, created, or deleted
    decisions_made:   [DecisionRef.t()], # references to decision graph nodes
    open_questions:   [OpenQuestion.t()], # unresolved items needing attention
    context_refs:     [String.t()],     # context keeper entry IDs worth loading
    created_at:       DateTime.t(),
    acknowledged_at:  DateTime.t() | nil
  }
end

defmodule PeerProtocol.FileChange do
  @type t :: %__MODULE__{
    path:        String.t(),
    change_type: :created | :modified | :deleted | :renamed,
    summary:     String.t(),            # what changed and why
    old_path:    String.t() | nil       # for :renamed
  }
end

defmodule PeerProtocol.DecisionRef do
  @type t :: %__MODULE__{
    node_id:    String.t(),             # decision graph node ID
    statement:  String.t(),             # decision summary (denormalized for quick read)
    confidence: float()
  }
end

defmodule PeerProtocol.OpenQuestion do
  @type t :: %__MODULE__{
    question:   String.t(),
    priority:   :blocking | :high | :medium | :low,
    context:    String.t() | nil        # background for answering it
  }
end
```

### Handoff Protocol

```
Sending agent completes its phase of work
  │
  ▼
Compose handoff:
  actions_taken:  what did I do? (concrete steps, not goals)
  discoveries:    what did I learn that's not obvious from the code?
  files_changed:  exactly which files, what changed, why
  decisions_made: which decisions did I make? (with graph node refs)
  open_questions: what do I NOT know that the next agent should answer?
  │
  ▼
POST handoff to recipient's inbox
  (atomic write: .tmp-handoff-{id}.json → handoff-{id}.json)
  │
  ▼
Create handoff task comment: "Handoff sent to {agent_name}. See handoff-{id}."
  │
  ▼
Receiving agent wakes on next heartbeat
  │
  ▼
Load handoff at step 6 (Understand Context):
  1. Read handoff file
  2. Query context keeper for context_refs
  3. Check decision graph for decisions_made nodes
  4. Build working context from handoff + keeper + graph
  │
  ▼
Acknowledge handoff:
  POST {handoff_id, acknowledged_at: now()} to sender's inbox
  (sender records acknowledgment for audit trail)
```

### Handoff Validation

Before a handoff is accepted, the receiving agent validates it:

| Check | Rule | On Failure |
|-------|------|-----------|
| Completeness | `actions_taken` must be non-empty | Reject, request re-send |
| File refs | All `files_changed.path` values must exist | Warn, proceed (file may have been deleted) |
| Decision refs | All `decisions_made.node_id` values must resolve in graph | Warn, proceed (graph may lag) |
| Blocking questions | Open questions with `priority: blocking` | Flag to receiving agent immediately |

---

## Peer Review Gates

A peer review gate blocks task completion until a designated peer agent accepts
the work. This is distinct from leadership review (which goes through the task
comment channel) — peer review is a lateral quality check.

### Gate States

```
REVIEW REQUESTED
  │
  ├──────────────────────────┐
  ▼                          ▼
APPROVED               REJECTED / REQUEST_CHANGES
(unblocks task)         (requester must address)
```

### Review Request Schema

```elixir
defmodule PeerProtocol.ReviewRequest do
  @type t :: %__MODULE__{
    id:             String.t(),
    requester_id:   String.t(),
    reviewer_id:    String.t(),
    task_id:        String.t(),
    artifacts:      [String.t()],       # file paths or context keeper entry IDs
    context:        String.t(),         # what to review and what to look for
    review_type:    :code | :design | :security | :general,
    status:         :pending | :approved | :rejected | :changes_requested,
    decision:       String.t() | nil,   # reviewer's verdict explanation
    requested_at:   DateTime.t(),
    responded_at:   DateTime.t() | nil
  }
end
```

### Gate Protocol

```
Requester creates review request
  │
  ▼
Write ReviewRequest to reviewer's inbox
  │
  ▼
Task status: blocked_on_review (task cannot complete until gate clears)
  │
  ▼
Reviewer wakes, finds review in inbox
  │
  ▼
Reviewer reads artifacts, forms decision
  │
  ├── APPROVED
  │     → Update ReviewRequest.status: approved
  │     → Post approval comment to task
  │     → Task becomes unblocked
  │
  ├── REJECTED
  │     → Update ReviewRequest.status: rejected
  │     → Provide specific rejection reasons in decision field
  │     → Task status: blocked_on_review (requester must address)
  │     → Requester receives wake signal with rejection context
  │
  └── CHANGES_REQUESTED
        → Update ReviewRequest.status: changes_requested
        → Provide specific changes in decision field
        → Requester makes changes, re-requests review (new ReviewRequest)
```

### Review Constraints

| Rule | Rationale |
|------|-----------|
| A reviewer cannot review their own work | Prevents self-approval |
| Review gates are single-agent | One reviewer per gate. Multiple gates if needed. |
| A rejected gate does not auto-retry | Requester must explicitly re-request after addressing feedback |
| Review gate timeout: 24 hours | If reviewer does not respond, escalate to team leader |

---

## Task Negotiation

Agents can propose task transfers, scope changes, or delegation to peers without
routing through their leader. Negotiation is a formal protocol with an explicit
acceptance/rejection step.

### Negotiation Proposal Schema

```elixir
defmodule PeerProtocol.Negotiation do
  @type t :: %__MODULE__{
    id:              String.t(),
    proposer_id:     String.t(),
    recipient_id:    String.t(),
    task_id:         String.t(),
    proposal_type:   :transfer | :scope_reduction | :scope_expansion | :collaboration,
    rationale:       String.t(),
    terms:           map(),             # type-specific terms
    status:          :pending | :accepted | :rejected | :counter_proposed,
    counter:         Negotiation.t() | nil,
    expires_at:      DateTime.t(),
    resolved_at:     DateTime.t() | nil
  }
end
```

### Negotiation Flow

```
Proposer identifies need for peer negotiation
(e.g., "I can't finish this task — it needs expertise agent B has")
  │
  ▼
Create NegotiationProposal:
  proposal_type: :transfer
  rationale: "Requires database migration expertise outside my capability set"
  terms: {task_id, context_handoff: true, proposed_assignee: "db-specialist"}
  expires_at: now() + 30 minutes    ← auto-accept default window
  │
  ▼
Write proposal to recipient's inbox
  │
  ▼
Recipient evaluates proposal
  │
  ├── ACCEPT (within 30 minutes)
  │     → Task transferred: task.assignee = recipient
  │     → Proposer unassigned, recipient wakes
  │
  ├── REJECT
  │     → Proposal closed, proposer must route to leader
  │
  ├── COUNTER_PROPOSE
  │     → Recipient modifies terms and sends counter
  │     → Original proposer evaluates counter (same 30-minute window)
  │
  └── NO RESPONSE (30-minute timeout expires)
        → Auto-accept if proposal_type: :transfer and rationale is documented
        → Escalate to team leader for other types
```

### Auto-Accept Conditions

A negotiation auto-accepts (without explicit acknowledgment) when:
- `proposal_type: :transfer`
- Proposer has documented a substantive `rationale`
- Recipient has not responded within 30 minutes
- The recipient's current task load is below their concurrency limit

Auto-accept is intentionally permissive for transfers — the 30-second window
prevents blockers from waiting on slow heartbeat cycles.

---

## Cross-Team Discovery

Agents can find other agents by role or capability without knowing their identity
in advance. This enables lateral queries that the leader hierarchy cannot pre-plan.

### Discovery API

```elixir
# Find agents by role
PeerProtocol.Discovery.find_by_role("security_auditor", scope: :company)
# → [%AgentRef{id: "...", name: "...", team_id: "...", availability: :available}]

# Find agents by capability
PeerProtocol.Discovery.find_by_capability("database_migration", scope: :department)
# → [%AgentRef{...}, ...]

# Find agents available right now (not at concurrency limit)
PeerProtocol.Discovery.find_available(role: "code_reviewer", team_id: "eng-team-a")
# → [%AgentRef{...}]
```

### Lateral Query Protocol

A lateral query is a question sent to a peer agent without going through a shared
leader. The query is a task_comment-style message with a `lateral_query` type.

```
Agent A needs knowledge agent B possesses
  │
  ▼
A → find_by_role("domain_expert") → [B, C]
  │
  ▼
A → send lateral_query to B:
  {type: :lateral_query, question: "...", urgency: :blocking | :non_blocking}
  │
  ▼
B receives query in inbox
  │
  ├── B answers directly → A receives answer as inbox message
  │
  └── B can't answer → B routes to someone who can, or declines with explanation
```

Lateral queries are advisory — B can decline. If declined, A routes to their leader.

### Discovery Index

The discovery index is a lightweight table maintained by the system (not agents):

```sql
CREATE TABLE agent_discovery_index (
  agent_id       TEXT PRIMARY KEY,
  team_id        TEXT NOT NULL,
  roles          TEXT[],          -- array of role strings
  capabilities   TEXT[],          -- array of capability strings
  availability   TEXT,            -- available | busy | unavailable | paused
  updated_at     TEXT NOT NULL
);

CREATE INDEX idx_discovery_role ON agent_discovery_index USING GIN(roles);
CREATE INDEX idx_discovery_cap ON agent_discovery_index USING GIN(capabilities);
```

Updated on every heartbeat run completion (availability recalculated from
current concurrency utilization).

---

## Region-Level File Locking

When agents work in parallel on a shared codebase (via git worktrees or shared
workspace), region-level locking prevents two agents from editing the same lines
simultaneously.

A region is a contiguous line range within a file. Locks are advisory (not
enforced by the OS) but carrying a claimed lock is a peer protocol obligation —
other agents will check before editing.

### Region Lock Schema

```elixir
defmodule PeerProtocol.RegionLock do
  @type t :: %__MODULE__{
    id:            String.t(),
    agent_id:      String.t(),
    team_id:       String.t(),
    file_path:     String.t(),
    start_line:    non_neg_integer(),
    end_line:      non_neg_integer(),
    intent:        String.t(),          # what the agent is doing to this region
    claimed_at:    DateTime.t(),
    expires_at:    DateTime.t()          # claimed_at + 10 minutes (default)
  }
end
```

### Lock Lifecycle

```
Agent intends to edit file region {path, start_line, end_line}
  │
  ▼
Claim lock:
  PeerProtocol.RegionLock.claim(agent_id, file_path, start_line, end_line, intent)
  │
  ▼
Overlap check: are any active locks covering any lines in [start_line, end_line]?
  │
  ├── No overlap → grant lock, return {:ok, lock}
  │
  └── Overlap detected
        → return {:conflict, [overlapping_locks]}
        → Agent must: wait, negotiate, or choose different region
  │
  ▼
Agent edits the region
  │
  ▼
Release lock:
  PeerProtocol.RegionLock.release(lock.id)
  (or lock expires automatically after 10 minutes)
```

### Overlap Detection

```elixir
defmodule PeerProtocol.RegionLock.OverlapDetector do
  def check_overlap(new_start, new_end, existing_locks) do
    Enum.filter(existing_locks, fn lock ->
      # Two ranges overlap if neither is entirely before the other
      not (new_end < lock.start_line or new_start > lock.end_line)
    end)
  end
end
```

### Intent Broadcasting

Before claiming a lock, agents broadcast their intent:

```
Agent broadcasts intent to team's peer channel:
  {agent_id, intent: "Refactoring auth middleware lines 45-120",
   file: "lib/auth/middleware.ex", lines: [45, 120]}
  │
  ▼
Other agents see broadcast, adjust their own plans if needed
(e.g., "I was going to edit lines 100-150 — I'll wait for A to finish")
  │
  ▼
Agent claims lock after a brief yield window (500ms default)
```

This cooperative pre-announcement reduces conflicts before they happen.

### Lock Expiry

Locks expire after 10 minutes (configurable) to prevent dead locks from agent crashes:

```
Lock expiry timer fires
  │
  ▼
Lock.expires_at < now() → auto-release lock
  │
  ▼
Emit :region_lock_expired telemetry
  {lock_id, agent_id, file_path, duration_held}
  │
  ▼
If agent was still editing (run still active):
  → Notify agent via inbox: "Lock on {file}:{range} expired. Reclaim if still needed."
```

### Conflict Resolution

When two agents have conflicting edits (lock violation or post-merge conflict):

```
Conflict detected (merge conflict or lock violation)
  │
  ▼
1. Both agents are notified
   │
   ▼
2. Priority resolution:
   - Higher task priority wins
   - If equal priority: first-claimed lock wins
   - If no lock (uncoordinated): escalate to team leader
   │
   ▼
3. Losing agent receives:
   {:conflict_lost, winner_agent_id, winner_lock}
   → Losing agent must reload the file and re-apply their changes on top
```

---

## Signal Theory Position

The Peer Protocol implements **Layer 1 (The Network)** of the Optimal System.

```
OS Layer 1 — The Network
  ↕
PeerProtocol — defines the inter-node signaling patterns

NODES AND EDGES: Every agent is a node. Every handoff, review request,
  negotiation, and lateral query is a directed edge — a Signal transmitted
  from one node to another. Peer Protocol defines the edge types, their
  encoding format (handoff schema, review request schema), and the routing
  rules (inbox-based delivery, atomic write protocol).

TOPOLOGY: Discovery indexes make the full network topology queryable.
  An agent that cannot find a node with a needed capability cannot route
  its Signal to the right destination — a Shannon routing failure. Discovery
  prevents routing failures by making the network's variety accessible.

FILE LOCKING AS CHANNEL COORDINATION: Two agents editing the same region
  is a channel collision — two signals trying to occupy the same space
  simultaneously. Region locking is the channel coordination protocol
  that prevents collisions before they degrade output.
```

### Governing Principle: Shannon — Channel Encoding

Handoffs are the channel encoding between agent nodes. A poor handoff (incomplete
`actions_taken`, no `discoveries`, no `files_changed`) forces the receiving agent
to re-read the entire task history — a Shannon fidelity failure. The handoff schema
is the minimum sufficient encoding: the receiving agent should need nothing else
to continue work from where the sender stopped.

The structured handoff format, required field validations, and acknowledgment
protocol enforce Shannon's constraint: the Signal must carry enough information
to survive the channel and be decoded correctly at the receiver.

### Governing Principle: Beer — Viable Structure

Peer review gates are S2 (Coordination) at the team scope. Without them, agents
could produce outputs that contradict each other or violate team standards —
a Beer S2 failure where coordination between S1 operational units collapses.
Review gates impose the minimum viable coordination structure: before work
progresses past a quality gate, it must pass a peer check.

---

## See Also

- [team-coordination.md](team-coordination.md) — Leader-worker hierarchy that peer protocol extends laterally
- [heartbeat.md](heartbeat.md) — Inbox polling (step 3) processes handoffs and review requests
- [decision-graph.md](decision-graph.md) — `decisions_made` in handoffs reference decision graph nodes
- [context-mesh.md](context-mesh.md) — `context_refs` in handoffs point to keeper entries
- [conversations.md](conversations.md) — Multi-agent conversations use discovery to find participants
- [governance.md](governance.md) — Escalation path when peer negotiation fails
- [optimal-system-mapping.md](optimal-system-mapping.md) — Full 7-layer OS mapping

---

*Peer Protocol v1.0 — Structured handoffs, review gates, task negotiation, cross-team discovery, and region-level file locking*
