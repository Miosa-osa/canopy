# Optimal System Mapping

> Canopy is the implementation of the Optimal System architecture defined in
> *Signal Theory: The Architecture of Optimal Intent Encoding in Communication Systems*.
> This document is the canonical reference for how Canopy's protocol, architecture,
> and file structure map to the paper's 7-layer model.

---

## The Insight

Signal Theory defines the **Optimal System** — a 7-layer cybernetic architecture
derived from four governing principles (Shannon, Ashby, Beer, Wiener) that any
viable communication system must satisfy at every level of recursion.

Canopy implements all 7 layers. The paper defined the theory; Canopy is the substrate.

What the paper calls "the Optimal System," Canopy calls "the workspace protocol."
What the paper calls "the Signal Network," Canopy calls "the org chart." What the
paper calls "the Viable System Model," Canopy calls "SYSTEM.md + governance + teams."
The names differ. The architecture is identical.

---

## The 7-Layer Mapping

| # | OS Layer | What It Does | Canopy Implementation | Key Files |
|---|----------|-------------|----------------------|-----------|
| 1 | **The Network** | Nodes, topology, routing | `company.yaml` (org chart), `reportsTo` (edges), divisions (subnets), departments (superclusters), teams (clusters), escalation chains (routing rules); peer protocol defines inter-node edge types and signaling patterns | `protocol/company-format.md`, `protocol/division-format.md`, `protocol/department-format.md`, `protocol/team-format.md`, `architecture/team-coordination.md`, `architecture/peer-protocol.md` |
| 2 | **The Signal** | S=(M,G,T,F,W) — encoded intent | `signal:` frontmatter field on every agent, deliverable templates (Structure), S/N quality gates | `protocol/signal-theory.md`, `architecture/signal-integration.md` |
| 3 | **The Composition** | Micro-structure of each Signal | 8 body sections in agent definitions, SKILL.md process steps, workflow phases, spec-layer bindings; conversations compose multi-agent signals into collective intelligence | `protocol/agent-format.md`, `protocol/spec-layer.md`, `architecture/conversations.md` |
| 4 | **The Interface** | Progressive disclosure, decoding surface | L0/L1/L2 tiered loading, `context_tier` field, catalog system, the OSA desktop app; speculative execution extends interface into the time dimension — pre-loading likely-next context | `architecture/progressive-disclosure.md`, `architecture/tiered-loading.md`, `architecture/speculative-execution.md` |
| 5 | **The Data Layer** | Storage, capture, process, archive | `agents/`, `skills/`, `teams/`, `projects/`, `tasks/` directories; `.canopy/` runtime state; engine backends; 4-layer memory system; context mesh (per-team keeper — shared in-flight team data substrate) | `architecture/system-model.md`, `architecture/memory-architecture.md`, `architecture/context-mesh.md` |
| 6 | **The Feedback Loop** | Circular causality, self-correction | Heartbeat 9-step cycle, S/N quality gates, 6R processing pipeline, success metrics, evidence gates; decision graph confidence cascade closes the feedback loop on every decision; self-healing verifies recovery closing the error feedback loop | `architecture/heartbeat.md`, `architecture/processing-pipeline.md`, `architecture/decision-graph.md`, `architecture/self-healing.md` |
| 7 | **The Governance (VSM)** | Beer's 5 recursive subsystems | `SYSTEM.md` (S5 policy), CEO agent (S4 intelligence), orchestrators (S3 control), team coordination (S2), individual agents (S1 operations); self-healing implements S3/S4 at agent scope — autonomous control and intelligence without human intervention | `architecture/governance.md`, `protocol/workspace-protocol.md`, `architecture/self-healing.md` |

---

---

## Runtime Subsystem Mapping (Entries 21–26)

The six runtime subsystems added to the control plane each implement a specific OS layer.
This table provides the canonical mapping for reference:

| Subsystem | File | OS Layer | Primary Principle | Role |
|-----------|------|----------|------------------|------|
| **Context Mesh** | `context-mesh.md` | **L5 — Data** | Ashby (keeper variety ≥ signal variety) | Per-team GenServer keepers are the shared data substrate for in-flight team context |
| **Decision Graph** | `decision-graph.md` | **L6 — Feedback Loop** | Wiener (confidence cascade closes every loop) | DAG of decisions, goals, observations — confidence propagates through all downstream nodes on every state change |
| **Self-Healing** | `self-healing.md` | **L7 — Governance (S3/S4)** | Beer (S3 control + S4 intelligence at agent scope) | Classifies errors, spawns budget-capped ephemeral agents, verifies recovery, escalates via algedonic channel |
| **Conversations** | `conversations.md` | **L3 — Composition** | Ashby (debate variety ≥ problem variety) | Structured multi-agent dialogue that composes individual agent signals into collective intelligence |
| **Peer Protocol** | `peer-protocol.md` | **L1 — Network** | Shannon (handoffs are the channel encoding between nodes) | Defines all inter-node edge types: handoffs, review gates, negotiation, discovery, file locking |
| **Speculative Execution** | `speculative-execution.md` | **L4 — Interface** | Shannon (speculate on high-probability signals to eliminate latency) | Anticipatory interface — starts work before formal assignment, promotes on valid assumptions, discards on invalid |

---

## The 4 Governing Principles in Canopy

Every design decision in Canopy traces to one of these constraints. When something
breaks, the diagnostic question is always: *which principle was violated?*

### Shannon — Channel Capacity

> Every channel has a finite ceiling. Don't exceed the receiver's bandwidth.

| Enforcement Point | Mechanism |
|-------------------|-----------|
| Progressive disclosure (L0/L1/L2) | Token budgets prevent context window overflow |
| `context_tier` field | Agents load only what their tier permits |
| Session compaction | Auto-compact at 900K tokens, hard stop at 950K |
| Budget system | Dollar caps enforce compute channel limits |
| S/N quality gates | Reject signals that waste channel capacity |

### Ashby — Requisite Variety

> The regulator's variety must equal or exceed the variety of disturbances it faces.

| Enforcement Point | Mechanism |
|-------------------|-----------|
| 169 agents across 5 divisions, 20 departments, 43 teams | Genre variety matches task variety — organizational variety matches operational variety |
| 130 skills across 17 categories | Capability variety matches situational variety |
| Multiple adapter types (OSA, Claude Code, Cursor, Codex, HTTP) | Runtime variety matches deployment variety |
| `signal:` field with 5 dimensions | Each agent's encoding variety is explicitly declared |
| Team composition | Clusters combine agents to amplify variety beyond individual capacity |

### Beer — Viable Structure

> Every viable system requires 5 recursive subsystems: Operations, Coordination, Control, Intelligence, Policy.

| Enforcement Point | Mechanism |
|-------------------|-----------|
| Recursive 4-level hierarchy | Every division, department, and team IS a viable system (see VSM Mapping below) |
| `SYSTEM.md` as boot file | S5 (Policy) loaded first, constraining everything downstream |
| `reportsTo` hierarchy | Explicit structural relationships, no orphaned nodes |
| 4-dimension coordinate space | Every piece of state has a coherent position (Persistence, Attention, Authorship, Space) |
| Verification contracts | Drift detection maintains structural coherence over time |

### Wiener — Feedback Closure

> Never broadcast without confirmation. Close the loop.

| Enforcement Point | Mechanism |
|-------------------|-----------|
| Heartbeat step 8 | "Always comment before exiting" — every execution closes the loop |
| Escalation protocol | Traverses org chart until resolution — loops don't stay open |
| 6R processing pipeline | Phase 6 (Rethink) closes the learning loop |
| Evidence gates | Projects and tasks require proof before completion |
| S/N rejection notices | Failed quality gates loop back to the producing agent |

---

## The Signal Lifecycle at the Agent Level

Every agent processes signals through a complete lifecycle. This is not abstract —
it is the actual runtime flow when an agent receives work:

```
ARRIVE ─── Signal reaches the agent
  │         (task assignment, user message, another agent's output, file, video, PDF)
  │
  ├─ MODE CHECK: Can I perceive this?
  │   linguistic (text) ✓ most agents
  │   visual (image/video) → need multimodal tools or transcoding
  │   code (source) ✓ engineering agents
  │   data (structured) ✓ analysis agents
  │   If NO → ROUTE to capable agent or TRANSCODE via tool
  │
  ├─ FORMAT CHECK: Can I read this container?
  │   markdown, text ✓ native
  │   PDF → need read tool (format transcoder)
  │   video → need transcription tool (mode + format transcoder)
  │   JSON/YAML → need parse tool or native capability
  │   If NO → TRANSCODE via tool or ROUTE
  │
  ├─ GENRE CHECK: Do I have competence to decode this form?
  │   spec, report, brief → check agent's signal: field and Communication Style
  │   If NO → ROUTE to agent with matching genre competence
  │
  ├─ TYPE CHECK: What is this signal asking me to do?
  │   direct → execute an action
  │   inform → absorb information
  │   decide → make a choice
  │   commit → promise delivery
  │   express → acknowledge perspective
  │
DECODE ─── Extract actionable meaning
  │         (Identity & Memory → Core Mission → Critical Rules filter)
  │
PROCESS ── Apply domain expertise
  │         (Process/Methodology → tool invocations → skill execution)
  │
ENCODE ─── Produce output signal
  │         (Deliverable Templates → resolve S=(M,G,T,F,W))
  │         Mode: determined by receiver's decoding capacity
  │         Genre: determined by the deliverable template
  │         Type: determined by the intent (inform? direct? commit?)
  │         Format: determined by the channel (markdown, JSON, CLI)
  │         Structure: determined by the genre skeleton (template W)
  │
TRANSMIT ─ Send to next node
  │         (via reportsTo chain, team inbox, or direct handoff)
  │
FEEDBACK ─ Close the loop
           (heartbeat step 8: always comment before exiting)
           (evidence gates: proof that intent was decoded correctly)
```

### Tools in the Lifecycle

Tools participate at specific points in the lifecycle:

| Lifecycle Phase | Tool Role | Examples |
|----------------|-----------|---------|
| ARRIVE/FORMAT CHECK | Format transcoders | `read` (PDF→text), `bash` (extract data from files) |
| ARRIVE/MODE CHECK | Mode transcoders | Transcription (audio→text), OCR (image→text), vision (image→description) |
| PROCESS | Domain operations | `bash` (run tests), `search` (retrieve information), `web-search` (scan external signals) |
| ENCODE | Output formatting | `write` (create artifacts), `edit` (modify existing signals) |
| TRANSMIT | Network bridging | HTTP tools (cross-network), `bash` (system-level communication) |

### Skills in the Lifecycle

Skills activate during the PROCESS and ENCODE phases:

| Phase | Skill Role |
|-------|-----------|
| PROCESS | The skill's Process section provides step-by-step instructions — the agent follows the genre template instead of inventing the process |
| ENCODE | The skill's Output section pre-resolves Genre, Format, and often Structure — reducing encoding decisions from 5 dimensions to 1-2 |

---

## Body Sections as Signal Architecture

The 8 mandatory sections in every agent definition (see `protocol/agent-format.md`)
are not arbitrary documentation requirements. Each section encodes a specific
architectural property of the agent as a Signal Network node:

| Section | Architectural Role | Governing Principle |
|---------|-------------------|-------------------|
| **Identity & Memory** | Node identity — persistent state that survives across sessions | Beer (coherent identity at every scale) |
| **Core Mission** | Variety amplification — expands what the agent CAN handle | Ashby (sufficient variety to match task diversity) |
| **Critical Rules** | Variety attenuation — constrains what the agent MUST NOT handle | Ashby (bounded variety prevents competence overreach) |
| **Process / Methodology** | Encoding procedures — domain-specific signal transformation logic | Shannon (efficient encoding within channel capacity) |
| **Deliverable Templates** | Pre-resolved Structure (W) — output skeletons encoded in advance | Ashby (genre templates convert System 2 → System 1) |
| **Communication Style** | Receiver calibration — how the agent matches output to receiver bandwidth | Shannon (bandwidth matching) + Ashby (genre-receiver alignment) |
| **Success Metrics** | Feedback loop targets — measurable outcomes that close the Wiener loop | Wiener (every execution has a measurable feedback signal) |
| **Skills** | Capability repertoire — which dual-process genre templates this agent can invoke | Ashby (skills amplify variety without increasing cognitive load) |

**Core Mission + Critical Rules** together implement Ashby's Law at the agent level:
Core Mission defines the variety the agent amplifies (what it handles), Critical Rules
define the variety it attenuates (what it refuses). The balance between amplification
and attenuation determines the agent's effective operating scope — its autonomy boundary.

---

## VSM (Viable System Model) Mapping

Beer's Viable System Model is recursive — every viable system contains the same
5 subsystems, and every subsystem is itself a viable system. In Canopy, this
recursion manifests at every level of the organizational hierarchy: company,
division, department, team, and agent scope.

### Company Level

| VSM Subsystem | Role | Canopy Implementation |
|--------------|------|----------------------|
| **S1 — Operations** | Execute work | The 5 divisions executing their strategic mandates |
| **S2 — Coordination** | Synchronize S1 units | Cross-division coordination patterns, shared escalation protocols |
| **S3 — Control** | Monitor, allocate resources | CEO agent, company-level budget enforcement, S/N quality gates |
| **S4 — Intelligence** | Scan environment, adapt | CEO strategic planning, 6R processing pipeline, learning loop, proactive triggers |
| **S5 — Policy** | Identity, ethos, boundaries | `SYSTEM.md` (immutable identity), `company.yaml` (mission, governance rules), board powers |

### Division Level (Recursive)

Every division replicates this structure. See `protocol/division-format.md`.

| VSM Subsystem | Division-Level Implementation |
|--------------|------------------------------|
| **S1** | Departments executing their domain mandates |
| **S2** | Cross-Department Coordination section — patterns for inter-department work |
| **S3** | Division head, division-level budget allocation, resource rebalancing |
| **S4** | Division head surfaces strategic risks and cross-department patterns to CEO |
| **S5** | Division Mission — the identity statement that constrains all departments within |

### Department Level (Recursive)

Every department replicates this structure. See `protocol/department-format.md`.

| VSM Subsystem | Department-Level Implementation |
|--------------|--------------------------------|
| **S1** | Teams executing assigned work |
| **S2** | Cross-Team Coordination section — patterns for inter-team handoffs |
| **S3** | Department head, department-level budget, cross-team blocker resolution |
| **S4** | Department-level pattern recognition surfaced in status reports to division |
| **S5** | Department Mission — the identity statement that bounds team behavior |

### Team Level (Recursive)

Every team replicates this structure. See `protocol/team-format.md`.

| VSM Subsystem | Team-Level Implementation |
|--------------|--------------------------|
| **S1** | Team members executing assigned tasks |
| **S2** | Team coordination patterns, shared inbox, handoff protocols |
| **S3** | Team manager agent, team-level budget, task allocation |
| **S4** | Team retrospectives, pattern recognition across team tasks |
| **S5** | Team mission (in team manifest), team-specific rules |

### Algedonic Channel

The paper defines **algedonic channels** as viability-preserving bypass signals that
route directly from the point of disturbance to the policy level (S5) when normal
processing channels are too slow or too noisy.

In Canopy: the **escalation protocol** (`architecture/governance.md`) IS the algedonic
channel. When an agent encounters a viability threat (budget exhaustion, security
incident, unresolvable conflict), escalation bypasses the normal `reportsTo` chain
and routes directly to the board/human operator.

---

## Autonomy Levels

The paper (Section 11.6.3) defines 5 levels of agent autonomy, each corresponding
to the VSM subsystem scope the agent possesses internally. Autonomy is not a
permission setting — it is an **architectural requirement**. An agent deployed at
Level 5 without Systems 2-5 internally encoded is not autonomous; it is unregulated.

| Level | Operator Role | Agent's VSM Scope | Canopy Mechanism |
|-------|--------------|-------------------|-----------------|
| **L1: Operator** | Human provides all direction | S1 only (Operations) | Agent with `context_tier: l0`, no reports, explicit task assignment |
| **L2: Collaborator** | Human and agent share planning | S1 + S2 (+ Coordination) | Agent with `reportsTo`, team membership, peer awareness |
| **L3: Consultant** | Agent takes initiative, human provides expertise | S1-S4 (through Intelligence) | Manager agent, can delegate via heartbeat, runs partial processing pipeline |
| **L4: Approver** | Agent operates independently, human gates high-stakes decisions | S1-S5 with human veto | CEO/orchestrator agent with approval gates (`governance.md`) for consequential actions |
| **L5: Autonomous** | Agent has full operational independence | Complete S1-S5 | Requires encoded organizational intent at S5, algedonic channel to human, emergency stop |

**Autonomy certification**: Before deploying an agent at a given level, verify that
its internal architecture possesses the VSM subsystems required for that level.
An agent whose genre competence spans only routine resolution cannot be certified
for Level 3, where judgment-requiring situations fall within its scope.

---

## The Substrate Insight

The paper describes the Optimal System as an abstract architecture. It defines
WHAT each layer does but not HOW organizational intent gets physically stored and
retrieved. Canopy IS that physical substrate — the missing implementation layer:

```
THE SUBSTRATE — What Canopy Adds to Signal Theory

AGENT DEFINITIONS ──── Encoded organizational roles
  Identity (who they are in the network)
  Genre competence (signal: field — what they can encode/decode)
  Decision boundaries (Critical Rules — Ashby variety attenuation)
  Skills (capability repertoire — Ashby variety amplification)
  Autonomy scope (context_tier → L1-L5 VSM subsystem scope)

SKILL DEFINITIONS ──── Encoded organizational processes
  Reusable encoding procedures (genre templates)
  Dual-process encoding (skills convert System 2 → System 1 over time)
  Cross-agent composability (same skill, different agent context)

DIVISION MANIFESTS ─── Encoded network subnets
  Strategic envelopes with budget ceilings
  Cross-department coordination (S2 at division scope)
  Division heads as subnet gateways (S3 at division scope)

DEPARTMENT MANIFESTS ── Encoded network superclusters
  Mid-level variety management (Ashby compression)
  Cross-team coordination patterns (S2 at department scope)
  Department heads as cluster gateways (S3 at department scope)

TEAM MANIFESTS ─────── Encoded network clusters
  Clusters with shared genre competence
  Budget rollup (channel capacity allocation)
  Coordination protocols (S2 at team scope)

PROJECT MANIFESTS ──── Encoded signal chains
  Milestone sequences (sequential signal topology)
  Evidence gates (feedback loop closure points)
  Cross-team dependencies (inter-subnet routing)

TASK MANIFESTS ─────── Encoded atomic signals
  Single-intent work units (one Signal per task)
  Templates for recurring patterns (genre establishment)
  Scheduling constraints (channel capacity planning)

PROGRESSIVE DISCLOSURE ── Encoded bandwidth matching
  Tier 0: catalog (~100 tokens) — Shannon minimum
  Tier 1: activation (~2K tokens) — Ashby sufficient variety
  Tier 2: full resources — complete variety when needed
```

The encoding medium is **markdown** — human-readable, machine-parseable,
version-controllable, diff-able. YAML frontmatter carries machine-readable
metadata. Markdown body carries human-readable behavioral definition. Directory
structure carries topology. This is the Transposition of the Mind (Section 2.1.1
of the paper): encoding cognitive processes — reasoning patterns, decision
frameworks, mental models — as signals that preserve their actionable meaning
across the network.

---

## DIKW in the Substrate

The paper defines the DIKW hierarchy as a Signal lifecycle:

| Level | Signal Theory Definition | Canopy Implementation |
|-------|------------------------|----------------------|
| **Data** | Raw, unprocessed facts | Raw file contents, task inputs, tool outputs |
| **Information** | Data + context + meaning (the decoded Signal) | Loaded context after tiered disclosure — agent has situational awareness |
| **Knowledge** | Accumulated decoded Signals — patterns across many signals | 4-layer memory system (episodic → semantic), 6R pipeline outputs, learned patterns |
| **Wisdom** | The ability to encode optimal Signals based on accumulated knowledge | Agent Critical Rules, decision boundaries, process methodologies — the judgment encoded in agent definitions |

---

## Related Documents

### By OS Layer

| Layer | Key Documents |
|-------|-------------|
| L1 Network | `protocol/company-format.md`, `protocol/division-format.md`, `protocol/department-format.md`, `protocol/team-format.md`, `architecture/team-coordination.md`, **`architecture/peer-protocol.md`** |
| L2 Signal | `protocol/signal-theory.md`, `architecture/signal-integration.md`, `architecture/cross-workspace-signals.md` |
| L3 Composition | `protocol/agent-format.md`, `protocol/spec-layer.md`, **`architecture/conversations.md`** |
| L4 Interface | `architecture/progressive-disclosure.md`, `architecture/tiered-loading.md`, **`architecture/speculative-execution.md`** |
| L5 Data | `architecture/system-model.md`, `architecture/memory-architecture.md`, `architecture/basement.md`, **`architecture/context-mesh.md`** |
| L6 Feedback | `architecture/heartbeat.md`, `architecture/processing-pipeline.md`, `protocol/verification.md`, **`architecture/decision-graph.md`** |
| L7 Governance | `architecture/governance.md`, `protocol/workspace-protocol.md`, `architecture/budgets.md`, **`architecture/self-healing.md`** |

### Foundational

- `protocol/signal-theory.md` — The Signal encoding framework (S=(M,G,T,F,W), 6 encoding principles, 11 failure modes)
- `guides/signal-theory-quickstart.md` — 5-minute introduction to Signal Theory in practice
- `architecture/system-model.md` — The 4-dimension coordinate space (the substrate's addressing scheme)
