# Three-Space Architecture

OptimalOS organizes all information into three distinct spaces: Self, Notes, and Ops. This separation is not cosmetic — conflating the spaces produces 6 specific failure modes that degrade system performance over time. This document defines each space, maps it to OptimalOS components, and explains why the boundaries must be maintained.

---

## The Spaces

### 1. Self (Identity)

**What it is**: The agent's identity, operating principles, voice, and stable personality. The part of the system that doesn't change when the world changes.

**Where in OptimalOS**:

| Component | Role |
|-----------|------|
| `CLAUDE.md` | System instructions, routing table, genre skeletons, Signal Theory rules |
| `reference/kernel.yaml` | Universal primitives — the non-negotiable operating constraints |
| `reference/methodology.md` | Core philosophy and working approach |
| `01-operator/context.md` | the operator's persistent identity: goals, working style, constraints |
| `rhythm/` | Operating cadence — the behavioral patterns that define how the system runs |

**What belongs here**: Stable facts about identity and operating method. How the operator thinks. What genre to send to whom. What the system is for. What never changes regardless of current projects.

**What does NOT belong here**: Current project status, weekly priorities, or anything that will be different in 30 days.

**Earlier KM equivalent**: `self/` folder with `identity.md`, `principles.md`, `voice.md`

---

### 2. Notes (Knowledge)

**What it is**: The stored cognitive patterns — decision trees, playbooks, domain knowledge, scenarios, historical signals, genre templates. the operator's externalized library.

**Where in OptimalOS**:

| Component | Role |
|-----------|------|
| `01-12/` numbered folders | All domain knowledge organized by node |
| `*/context.md` files | Persistent facts per domain (ground truth) |
| `*/signal.md` files | Temporal state per domain (weekly/episodic) |
| `docs/taxonomy/genres/` | Genre templates — 27+ skeletons for encoding outputs |
| `docs/architecture/` | System architecture specs and ADRs |
| Engine SQLite database | Indexed, searchable, scored contexts — the retrieval layer over the notes |

**What belongs here**: Everything the operator has learned, decided, observed, or built that has value beyond the current session. Playbooks. Decision trees. People context. Domain knowledge.

**What does NOT belong here**: Today's tasks (that's Ops), or fundamental identity principles (that's Self).

**The key distinction within Notes**: `context.md` (permanent facts) vs `signal.md` (temporal state). This is the single most important boundary in the entire system. Violating it is the root cause of Decay Failure and Herniation Failure.

**Earlier KM equivalent**: `notes/` folder with all knowledge content

---

### 3. Ops (State)

**What it is**: The current operational state — what is happening right now, this week, today. The live layer of the system.

**Where in OptimalOS**:

| Component | Role |
|-----------|------|
| `rhythm/today.md` | THE daily working file — the only file edited during the day |
| `*/signal.md` files | Weekly status per node (also in Notes, but represents current state) |
| `week-plan.md` | Current week's execution plan |
| `weekly-review.md` | This week's review output |
| `alignment.md` | Current drift scores across 4 dimensions |
| Engine `sessions` table | Active conversation state |
| Engine `observations` table | Captured friction patterns from current sessions |

**What belongs here**: What is true TODAY or THIS WEEK. Current priorities. Current blockers. Current delegation status. Energy log for today.

**What does NOT belong here**: Permanent facts about a domain (those go in context.md in Notes), or identity principles (those go in Self).

**The critical rule**: Ops is the only space that gets refreshed daily. If information belongs in Ops and it doesn't get updated, you have Decay Failure.

**Earlier KM equivalent**: `ops/` folder with `state.md`, `tasks.md`, `metrics.md`

---

## Why Three Spaces Matter

Earlier knowledge management research identified 6 failure modes that occur when the spaces are conflated. OptimalOS maps these to its own architecture.

### Failure Mode 1: Identity Drift

**What it is**: The agent loses consistent voice and operating principles as the Self space bleeds into Notes.

**How it happens in OptimalOS**: The genre skeletons in `CLAUDE.md` get overridden by ad-hoc formats in individual signal files. Over time, the agent starts writing in whatever style the last signal used, rather than the genre appropriate for the receiver.

**OptimalOS defense**: `CLAUDE.md` is the canonical Self. Genre skeletons defined there are not negotiated per-signal. The People table in `CLAUDE.md` is authoritative for receiver genre preferences — individual signal files do not override it.

---

### Failure Mode 2: State Pollution

**What it is**: Operational state corrupts the Notes knowledge base. Yesterday's status gets treated as permanent fact.

**How it happens in OptimalOS**: Writing current project status into `context.md` instead of `signal.md`. Example: "the operator is currently focused on AI Masters launch" written into `01-operator/context.md` — this becomes stale in two weeks but looks like permanent fact.

**OptimalOS defense**: The context.md vs signal.md distinction is absolute. Permanent facts → context.md. Current state → signal.md. The engine's temporal decay scoring automatically deprioritizes signal.md entries as they age, but context.md entries do not decay — which is why polluting context.md with state is particularly damaging.

---

### Failure Mode 3: Knowledge Paralysis

**What it is**: Too much context loaded at once. The Notes space overwhelms the Ops space — the agent has so much knowledge available that it can't act on the current task.

**How it happens in OptimalOS**: Reading 10 full files before answering a question. Using `mix optimal.read --tier full` when L1 would suffice. Loading all 12 node contexts for every session regardless of what the session needs.

**OptimalOS defense**: Tiered loading (L0/L1/L2). Search returns L0 abstracts (~100 tokens each). Read L1 only if the result is relevant. Read full only when necessary. The session context budget (5K tokens for topic assembly, 2K for L0) enforces this discipline structurally.

---

### Failure Mode 4: Personality Loss

**What it is**: The agent becomes generic because the Self space is not maintained.

**How it happens in OptimalOS**: `CLAUDE.md` becomes outdated — the People table doesn't reflect current team composition, the routing table misses new domains, the genre skeletons drift. The agent falls back on default behavior instead of OptimalOS-specific behavior.

**OptimalOS defense**: The People table and routing table in `CLAUDE.md` are treated as living documents. When the operator introduces a new person or domain, `CLAUDE.md` is updated. This is the only file that defines Self — it must be current.

---

### Failure Mode 5: Stale State

**What it is**: Yesterday's Ops are treated as today's reality. The operational layer is not refreshed.

**How it happens in OptimalOS**: `rhythm/today.md` not updated at boot. `week-plan.md` from three weeks ago still being referenced. Energy log not updated for days. The agent is operating on last week's state while making this week's decisions.

**OptimalOS defense**: The boot/shutdown ritual (`rhythm/boot.md` and `rhythm/shutdown.md`) exists specifically to refresh the Ops space daily. Boot generates a new `today.md` from the current `week-plan.md`. Shutdown captures the day's state before it's lost. Without this ritual, Stale State is the default outcome.

---

### Failure Mode 6: Context Confusion

**What it is**: The agent can't tell if information is permanent fact or current status — so it can't reliably update either.

**How it happens in OptimalOS**: Ed Honour's email address (permanent fact) and Ed Honour's current negotiating position (current state) are both in the same file. When the negotiating position changes, should the file be updated? Yes. But the email address shouldn't be. If they're mixed, the distinction is lost.

**OptimalOS defense**: Strict file separation. `context.md` = permanent facts. `signal.md` = weekly/temporal. Never mix them. The rule "Persistent facts → context.md. Weekly/temporal → signal.md. Don't mix them" in `CLAUDE.md` is the direct defense against Context Confusion.

---

## How OptimalOS Maintains the Boundaries

| Challenge | Mechanism |
|-----------|-----------|
| State pollution into context.md | Explicit rule: context.md vs signal.md separation |
| Knowledge paralysis | Tiered loading (L0/L1/L2), session context budget |
| Stale state | Boot/shutdown ritual, engine temporal decay scoring |
| Identity drift | CLAUDE.md as canonical Self, genre skeletons are not overridden |
| Personality loss | People table and routing table maintained as living documents |
| Context confusion | context.md (permanent) vs signal.md (temporal) distinction is absolute |

---

## Quick Diagnostic

When something feels wrong with the system, use this to locate the space where the failure is occurring:

| Symptom | Likely Failure | Space Affected |
|---------|---------------|---------------|
| Agent gives wrong genre to a person | Identity drift or genre mismatch | Self |
| Search returns stale results as top hits | Decay failure, state pollution | Notes / Ops |
| Too much context loaded, can't focus | Knowledge paralysis | Notes → Ops |
| Agent doesn't know about a new person/domain | Personality loss | Self |
| context.md has outdated status info | State pollution | Notes |
| today.md hasn't been updated in days | Stale state | Ops |
| Can't tell if a fact is permanent or current | Context confusion | Notes + Ops boundary |

Run `mix optimal.health` to get an automated diagnostic across all three spaces.

---

## See Also

- `reference/failure-modes.md` — Full diagnostic treatment of all 11 Signal Theory failure modes
- `reference/session-lifecycle.md` — How the three spaces are loaded and persisted in each session type
- `rhythm/` — The daily ritual that maintains the Ops space
- `CLAUDE.md` — The canonical Self space definition
