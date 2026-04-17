# The Canopy System Model

> The workspace is not a stack of layers. It is a coordinate system.
> Every piece of the system sits at a position across 4 dimensions:
> **Persistence**, **Attention**, **Authorship**, and **Space**.
>
> Previous architecture docs (tiered-loading, memory-architecture, three-space-model,
> project-layer) each described one dimension. This document is the unified map.

---

## Why Not Layers

Layers imply a stack — one thing on top of another, data flowing up and down.
That model breaks for Canopy because:

- Memory is not "above" or "below" context loading — it feeds INTO loading
- The three-space model (Self/Knowledge/Ops) cross-cuts everything
- Project output is neither config nor runtime — it's a third category
- Context (what the agent sees right now) is a RESULT of the other dimensions, not a layer

The system is a **4-dimensional coordinate space**. Each thing in the workspace
has a position across all 4 dimensions. Understanding a component means knowing
its 4 coordinates.

---

## The 4 Dimensions

```
PERSISTENCE ─────── How long does it live?
ATTENTION ──────── How does it enter the agent's awareness?
AUTHORSHIP ─────── Who creates and maintains it?
SPACE ──────────── What kind of thing is it?
```

### Dimension 1: Persistence (Time Axis)

How long does this thing exist? When does it die?

```
Ephemeral ──────── Session ──────── Permanent ──────── Immutable
dies with the      dies when the     lives until        never changes
conversation       task/session      explicitly         (protocol,
(working memory,   ends or expires   deleted or         standards,
scratch notes)     (tasks, sessions, superseded         methodology)
                   observations)     (knowledge,
                                     output, agents,
                                     skills)
```

| Value | Lifespan | Can Be Deleted? | Examples |
|-------|----------|----------------|----------|
| **Ephemeral** | This conversation | Automatic | Working memory, agent scratch pad, current task context |
| **Session** | Hours to days | Expires or purged | Task queue, active sessions, inbox, conflict files |
| **Permanent** | Until explicitly removed | Manual or via learning loop | Reference docs, knowledge notes, output artifacts, agents, skills |
| **Immutable** | Forever | Never | SYSTEM.md core identity, protocol specs, Signal Theory definitions |

### Dimension 2: Attention (Loading Axis)

How does this thing get into the agent's context window?

```
Always ─────────── On-Demand ──────── Searched ──────── Invisible
in context from    loaded when the     found via query,   powers the system
first token to     agent needs it      keyword, or        but never enters
last               for current task    entity match       the context window
```

| Value | Token Cost | Trigger | Examples |
|-------|-----------|---------|----------|
| **Always** | ~100 tokens per item | Boot sequence | SYSTEM.md, L0 abstracts, active task, budget status |
| **On-Demand** | ~2K tokens per item | Task relevance, entity mention, explicit request | Agent definitions, skill definitions, L1 summaries |
| **Searched** | Variable | Query match, cross-reference | Reference docs, knowledge notes, semantic memory, episodic memory |
| **Invisible** | 0 tokens | Skill execution calls the engine | SQLite, FTS5, vector search, knowledge graph, integrations |

The invisible layer has pluggable backends — swap SQLite for Qdrant, filesystem edges
for Neo4j, Ollama for OpenAI. See [`engine-layer.md`](engine-layer.md) for all options.

This is what the old "tiered loading" doc described — but it's one dimension, not the whole system.

### Dimension 3: Authorship (Origin Axis)

Who creates this thing and who maintains it?

```
Protocol ──────── Human ──────── Agent ──────── Derived
shipped with       written or     generated      computed from
the workspace,     edited by      during agent   other data,
defines the        the human      operation      not directly
system             operator                      authored
```

| Value | Who Writes | Who Reviews | Examples |
|-------|-----------|------------|----------|
| **Protocol** | Workspace designer | Version controlled | SYSTEM.md, skills, agents, workflows, spec contracts |
| **Human** | The operator | Self-reviewed | Reference docs, governance rules, budget thresholds, compositions |
| **Agent** | The AI agent | Human reviews output | Output artifacts, session logs, task comments, observations |
| **Derived** | Computation | Nobody (internal) | L0 abstracts, search indexes, embeddings, entity graph edges, cache |

### Dimension 4: Space (Category Axis)

What kind of thing is it? What role does it play?

```
Identity ──── Capability ──── Knowledge ──── Operations ──── Product
who the        what the        what the       what the        what the
agent IS       agent CAN DO    agent KNOWS    agent is        agent
                                              DOING NOW       PRODUCES
```

| Value | Contains | Lifecycle | Old Model Mapping |
|-------|---------|-----------|-------------------|
| **Identity** | SYSTEM.md, company.yaml, agent self-definition, methodology, preferences | Permanent, slow change | Three-Space "Self" |
| **Capability** | Agent definitions, skill definitions, workflows, engine config | Permanent, version-controlled | Canopy Layer |
| **Knowledge** | Reference docs, semantic memory, entity graph, knowledge notes, data/ | Permanent, steady growth | Three-Space "Knowledge" + Memory "Semantic" |
| **Operations** | Task queue, sessions, observations, inbox, health checks, logs | Temporal, flowing | Three-Space "Ops" + Memory "Working" + Memory "Episodic" |
| **Product** | output/, src/, apps/, generated artifacts | Permanent, created by agents | Project Layer |

---

## The Coordinate Map

Every component in the system has 4 coordinates. This is the complete map:

### Identity Space

| Component | Persistence | Attention | Authorship | Notes |
|-----------|------------|-----------|------------|-------|
| SYSTEM.md (core identity) | Immutable | Always | Protocol | The brain transplant. Never changes during operation. |
| company.yaml | Permanent | Always | Human | Org chart, budget, governance. Human edits. |
| Agent self-definition | Permanent | Always | Protocol | Loaded at boot. Defines role, rules, encoding. |
| Methodology | Permanent | On-Demand | Protocol+Learning | Updated only by /rethink with human approval. |
| Preferences | Permanent | On-Demand | Derived+Learning | Learned from observation patterns. Slow evolution. |
| Budget status | Session | Always | Derived | Computed from ledger. In context so agent knows limits. |

### Capability Space

| Component | Persistence | Attention | Authorship | Notes |
|-----------|------------|-----------|------------|-------|
| Agent definitions | Permanent | On-Demand | Protocol | Loaded when agent role is activated. |
| Skill definitions | Permanent | On-Demand | Protocol | Loaded when skill is invoked. |
| Workflows | Permanent | On-Demand | Protocol | Multi-step process definitions. |
| Spec contracts | Permanent | Searched | Protocol | Validation rules, acceptance criteria. |
| Engine config | Permanent | Invisible | Protocol | Powers skills without entering context. |
| Compositions | Permanent | On-Demand | Human | Reusable output templates. |

### Knowledge Space

| Component | Persistence | Attention | Authorship | Notes |
|-----------|------------|-----------|------------|-------|
| Reference docs | Permanent | Searched | Human | Domain knowledge, playbooks, decision trees. |
| Semantic memory (facts) | Permanent | Searched | Derived | Extracted from episodic memory, conflict-resolved. |
| Entity graph | Permanent | Invisible | Derived | Relationship edges between entities. Powers search. |
| Knowledge notes | Permanent | Searched | Agent+Human | Pipeline output. Agent writes, human reviews. |
| Procedural memory | Permanent | On-Demand | Derived+Learning | "When X, do Y." Trigger-matched at task start. |
| Data files | Permanent | Searched | Agent | Working data (leads, pipeline, metrics). Agent consumption. |
| L0 abstracts | Derived | Always | Derived | Compressed from knowledge. Pre-computed. |
| L1 summaries | Derived | On-Demand | Derived | Structured overviews. Cached 10 min. |
| Embeddings / vectors | Derived | Invisible | Derived | Power semantic search. Never in context. |

### Operations Space

| Component | Persistence | Attention | Authorship | Notes |
|-----------|------------|-----------|------------|-------|
| Working memory | Ephemeral | Always | Agent | Current context window contents. Dies with session. |
| Task queue | Session | Always | Agent | Active tasks, priorities, assignments. |
| Active sessions | Session | On-Demand | Agent | Session persistence for heartbeat resume. |
| Episodic memory | Session→Permanent | Searched | Derived | Compressed session records. Time-indexed. |
| Observations | Session→Permanent | Searched | Agent | Friction patterns. Accumulate toward /rethink. |
| Inbox | Session | On-Demand | External | Unprocessed inputs awaiting classification. |
| Conflict files | Session | On-Demand | Derived | Reweave conflicts awaiting human resolution. |
| Health checks | Session | Searched | Derived | Diagnostic results. Regenerated on demand. |
| Budget ledger | Permanent | Invisible | Derived | Append-only transaction log. Powers budget status. |

### Product Space

| Component | Persistence | Attention | Authorship | Notes |
|-----------|------------|-----------|------------|-------|
| Output artifacts | Permanent | On-Demand | Agent→Human | Proposals, reports, analyses. Human reviews. |
| Source code | Permanent | Searched | Agent | Built by dev-shop workspaces. |
| Applications | Permanent | Searched | Agent+Human | Managed apps, integrations. |
| Published content | Permanent | On-Demand | Agent→Human | Articles, social posts, scripts. |

---

## Context Is Not a Dimension

Context is the **view** — what the agent sees right now. It's computed by slicing
across all 4 dimensions:

```
CONTEXT WINDOW (what the agent sees at this moment)
═══════════════════════════════════════════════════

From Identity:    SYSTEM.md + company.yaml + budget status
From Capability:  Current agent definition + active skill
From Knowledge:   L0 abstracts + relevant L1 summaries + search results
From Operations:  Current task + session state + recent observations
From Product:     Relevant output artifacts (if reviewing/continuing work)

TOTAL: ~50K-150K tokens of the 1M window
       The rest is conversation + reasoning
```

Context assembly follows this protocol:

```
1. BOOT — Load Identity (always)
   SYSTEM.md, company.yaml, agent self-definition, budget status
   Cost: ~3K tokens

2. TASK — Load relevant Capability (on-demand)
   The specific agent role + the specific skill being invoked
   Cost: ~4K tokens

3. RECALL — Load relevant Knowledge (searched)
   L0 abstracts (always loaded), then L1 for task-relevant resources
   Procedural memory matched against current task triggers
   Cost: ~10K-30K tokens

4. RESUME — Load relevant Operations (on-demand)
   Current task details, session handoff (if resuming), recent observations
   Cost: ~2K-5K tokens

5. REVIEW — Load relevant Product (if applicable)
   Output artifacts being reviewed, continued, or revised
   Cost: ~2K-10K tokens

Total boot context: ~20K-50K tokens
Remaining for conversation + reasoning: ~950K tokens
```

This is how tiered loading (L0/L1/L2) fits in — it's the MECHANISM for step 3.
L0 is what's always in the Knowledge slice. L1 is what gets added on-demand.
L2 is the full content when L1 isn't enough.

---

## Memory Is Not a Dimension Either

Memory is a SYSTEM that operates across the Persistence and Knowledge dimensions.
The 4 memory types from memory-architecture.md map like this:

| Memory Type | Persistence | Attention | Space | What It Actually Is |
|-------------|------------|-----------|-------|-------------------|
| **Working** | Ephemeral | Always | Operations | The context window itself. Not stored anywhere. |
| **Episodic** | Session→Permanent | Searched | Operations→Knowledge | Compressed session records. Starts as ops, best ones promote to knowledge. |
| **Semantic** | Permanent | Searched | Knowledge | Extracted facts. Lives in the knowledge space. Queryable. |
| **Procedural** | Permanent | On-Demand | Capability | Learned patterns. Functions like a skill — "when X, do Y." |

The memory system is the machinery that MOVES information across dimensions:

```
Working Memory (ephemeral, operations)
       │
       │ session ends → compress
       ▼
Episodic Memory (session, operations)
       │
       │ fact extraction → verify
       ▼
Semantic Memory (permanent, knowledge)
       │
       │ pattern detection → synthesize
       ▼
Procedural Memory (permanent, capability)
```

Each transition moves information:
- From **shorter** to **longer** persistence
- From **operations** space to **knowledge** space to **capability** space
- From **agent-authored** to **derived**
- From **always** attention to **searched** attention

This is the learning loop. The workspace gets smarter over time because
information flows from ephemeral experience to permanent capability.

---

## The Three Flows

Information doesn't just sit at coordinates — it moves. There are 3 primary flows:

### Flow 1: Attention Flow (Reading)

How information enters the agent's awareness during a task.

```
Identity (always)
    ↓
Capability (on-demand, triggered by task)
    ↓
Knowledge (searched, triggered by query/entity)
    ↓
Operations (on-demand, task state)
    ↓
Product (on-demand, if reviewing output)
    ↓
═══════════════════════
CONTEXT WINDOW
═══════════════════════
```

### Flow 2: Production Flow (Writing)

How the agent creates new things.

```
Task received
    ↓
Agent reads Capability (skill) + Knowledge (reference)
    ↓
Agent produces → Product (output/, src/, data/)
    ↓
Agent logs → Operations (.canopy/tasks/, sessions/)
    ↓
Human reviews → Product status: draft → approved
```

### Flow 3: Learning Flow (Memory)

How the workspace gets smarter over time.

```
Agent operates → Working Memory (ephemeral)
    ↓ session compress
Episodic Memory (operations)
    ↓ fact extraction
Semantic Memory (knowledge)
    ↓ pattern detection
Procedural Memory (capability)
    ↓ /rethink synthesis (requires human approval)
Identity updates (methodology, heuristics)
```

Each flow has a different timescale:
- **Attention**: milliseconds (within a single turn)
- **Production**: minutes to hours (within a task)
- **Learning**: days to weeks (across many sessions)

---

## Signal Theory: The Physics

The 4 dimensions describe WHERE things sit. The 3 flows describe HOW things move.
**Signal Theory describes the LAWS that govern every transition.**

Every time information crosses a boundary — agent to human, agent to agent, workspace
to workspace, knowledge to context, input to output — it must be encoded as a Signal.

### The Signal: S = (M, G, T, F, W)

Every output resolves 5 encoding dimensions:

```
S = (Mode, Genre, Type, Format, Structure)
```

| Dim | Name | What It Resolves | Example Values |
|-----|------|-----------------|----------------|
| **M** | Mode | How is it perceived? | linguistic, visual, code, data, mixed |
| **G** | Genre | What conventionalized form? | spec, brief, report, proposal, pitch, plan, transcript, note |
| **T** | Type | What does it DO? (speech act) | direct (compel action), inform, commit, decide, express |
| **F** | Format | What container? | markdown, code, JSON, YAML, HTML |
| **W** | Structure | Internal skeleton? | Genre-specific template (meddpicc-scorecard, adr-template, etc.) |

All 5 dimensions MUST be resolved before output crosses any boundary.
Unresolved dimensions = noise. Noise = failed signal.

### The 4 Constraints (Physics)

These are not guidelines. They're laws. Violate any one and the output fails.

| Constraint | Law | Violation |
|-----------|-----|-----------|
| **Shannon** (the ceiling) | Don't exceed the receiver's bandwidth | 500 lines when 20 suffice |
| **Ashby** (the repertoire) | Have enough genre variety for every situation | Prose when a table is needed |
| **Beer** (the architecture) | Coherent structure at every scale | Orphaned logic, no section headers |
| **Wiener** (the feedback loop) | Close every loop — verify the receiver decoded | Broadcasting without confirmation |

### Where Signal Theory Applies in the System

Signal Theory governs EVERY boundary crossing in the 3 flows:

**Attention Flow boundaries:**
```
Knowledge → Context window
  Signal Theory determines: WHAT gets loaded (relevance scoring),
  HOW MUCH (Shannon — don't overload the window),
  AT WHAT DEPTH (L0 abstract vs L1 summary vs L2 full)
```

**Production Flow boundaries:**
```
Agent → Output artifact
  Signal Theory determines: WHICH GENRE (brief? spec? report?),
  FOR WHOM (genre-receiver alignment),
  HOW STRUCTURED (W dimension — genre skeleton),
  QUALITY GATE (S/N score ≥ 0.3 or reject)

Agent → Agent (handoff/delegation)
  Signal Theory determines: Agent A's output genre must match
  Agent B's expected input genre. Mismatch = rejection.

Agent → Human (delivery)
  Signal Theory determines: Match the person's genre preference.
  Salespeople get briefs. Developers get specs. CEOs get decision logs.
```

**Learning Flow boundaries:**
```
Working Memory → Episodic Memory
  Signal Theory determines: WHAT to compress (key moments with high S/N),
  what to discard (filler, noise, low-value turns)

Episodic → Semantic (fact extraction)
  Signal Theory determines: WHAT counts as a fact (high-confidence claims),
  how to resolve conflicts (contradicting facts → dispute records)

Semantic → Procedural (pattern detection)
  Signal Theory determines: WHEN a pattern has enough evidence
  (confidence threshold), how to encode the procedure
```

### The S/N Quality Gate

Applied at every phase transition and output delivery:

```
Agent produces output
       ↓
┌─────────────────────┐
│ S/N GATE            │
│                     │
│ 1. All 5 dims       │ ← Unresolved dimension? REJECT
│    resolved?        │
│ 2. Filler detected? │ ← "Let me think..." REJECT
│ 3. Genre matches    │ ← Spec to salesperson? REJECT
│    receiver?        │
│ 4. Shannon check    │ ← 10x longer than needed? REJECT
│ 5. Structure?       │ ← No skeleton? REJECT
│                     │
│ Score: 0.0 ─── 1.0  │
└────────┬────────────┘
         │
    ≥ 0.3 PASS         < 0.3 REJECT
         │                    │
    TRANSMIT            REJECTION NOTICE
    to receiver         back to agent
```

S/N thresholds are configurable per workflow phase. Default: 0.3.
QA deliverables: 0.7. Client-facing: 0.8.

### The 11 Failure Modes

When signals fail, they fail in specific, diagnosable ways:

```
SHANNON VIOLATIONS (capacity):
  Routing Failure       → Wrong recipient. Re-route.
  Bandwidth Overload    → Too much output. Compress.
  Fidelity Failure      → Meaning lost in encoding. Re-encode.

ASHBY VIOLATIONS (variety):
  Genre Mismatch        → Wrong form. Use correct genre.
  Variety Failure       → No genre exists. Create one.
  Structure Failure     → No skeleton. Impose template.

BEER VIOLATIONS (architecture):
  Bridge Failure        → No shared context. Add preamble.
  Herniation Failure    → Incoherence across levels. Re-structure.
  Decay Failure         → Outdated signal. Audit and update.

WIENER VIOLATIONS (feedback):
  Feedback Failure      → No confirmation loop. Close it.

CROSS-CUTTING:
  Adversarial Noise     → Deliberate degradation. Escalate.
```

## Optimal System Layer Mapping

The 4-dimension coordinate space IS the **Layer 5 (Data Layer)** addressing scheme of the Optimal System. Every piece of workspace state has a position in (Persistence, Attention, Authorship, Space), and this position determines how the signal is stored, loaded, and routed.

The three system flows map to OS layers:

| Flow | OS Layer | Connection |
|------|----------|-----------|
| **Attention Flow** | Layer 4 (Interface) | What surfaces to the agent — progressive disclosure, tiered loading |
| **Production Flow** | Layer 2 (Signal) + Layer 3 (Composition) | Signals created, encoded, transmitted between agents |
| **Learning Flow** | Layer 6 (Feedback Loop) | Results fed back, patterns accumulated, knowledge synthesized |

The coordinate space provides what the paper's Optimal System requires but does not specify: a concrete addressing scheme for the data substrate.

See `optimal-system-mapping.md` for the canonical 7-layer mapping.

---

### Signal Theory Is Not a Dimension

It's tempting to add Signal Theory as a 5th dimension. It's not.

The 4 dimensions (Persistence, Attention, Authorship, Space) describe the
**geography** — where things are.

The 3 flows (Attention, Production, Learning) describe the **routes** —
how things move.

Signal Theory describes the **physics** — the laws that govern what happens
when information travels those routes. Every transition is an encoding event.
Every encoding event resolves S=(M,G,T,F,W). Every resolution is checked
against the 4 constraints. Every violation is a named failure mode.

```
GEOGRAPHY: 4 dimensions (where things sit)
ROUTES:    3 flows (how things move)
PHYSICS:   Signal Theory (laws governing transitions)
```

The workspace is a coordinate space with 3 flows governed by Signal Theory.
That's the complete system model.

---

## Mapping to the Filesystem

Every coordinate maps to a directory:

```
workspace/
│
├── SYSTEM.md              Identity × Immutable × Always × Protocol
├── company.yaml           Identity × Permanent × Always × Human
│
├── agents/                Capability × Permanent × On-Demand × Protocol
├── skills/                Capability × Permanent × On-Demand × Protocol
├── workflows/             Capability × Permanent × On-Demand × Protocol
├── spec/                  Capability × Permanent × Searched × Protocol
│
├── reference/             Knowledge × Permanent × Searched × Human
│   └── compositions/      Capability × Permanent × On-Demand × Human
│
├── engine/                Knowledge × Permanent × Invisible × Protocol
│   ├── search index       Knowledge × Derived × Invisible × Derived
│   ├── vector store       Knowledge × Derived × Invisible × Derived
│   └── integrations       Capability × Permanent × Invisible × Protocol
│
├── output/                Product × Permanent × On-Demand × Agent→Human
├── src/                   Product × Permanent × Searched × Agent
├── data/                  Knowledge × Permanent × Searched × Agent
├── apps/                  Product × Permanent × Searched × Agent+Human
│
└── .canopy/               Operations × Session × Various × Agent/Derived
    ├── tasks/             Operations × Session × Always × Agent
    ├── sessions/          Operations × Session × On-Demand × Agent
    ├── observations/      Operations × Session→Perm × Searched × Agent
    ├── episodic/          Operations × Session→Perm × Searched × Derived
    ├── semantic/          Knowledge × Permanent × Searched × Derived
    ├── procedural/        Capability × Permanent × On-Demand × Derived
    └── budget-ledger.jsonl Operations × Permanent × Invisible × Derived
```

### The Purge Tests

Each space can be independently deleted. The purge test validates separation:

| Delete | Agent loses | Agent keeps | Can rebuild? |
|--------|-----------|------------|-------------|
| `.canopy/` | Task state, sessions, memory | Identity, capability, knowledge, product | Yes — boots fresh, rebuilds from files |
| `output/` + `src/` | All work product | Identity, capability, knowledge, operations | Yes — produces new output from same config |
| `reference/` + `data/` | Domain knowledge | Identity, capability, operations, product | Partially — agent still works but has no reference material |
| `agents/` + `skills/` | All capabilities | Identity, knowledge, operations, product | No — agent has identity but can't do anything |
| `SYSTEM.md` | Identity | Everything else | No — agent doesn't know who it is |

---

## How to Use This Model

### "Where does X go?"

Ask: what are its 4 coordinates?

| Question | Think About |
|----------|------------|
| How long should it last? | **Persistence**: ephemeral, session, permanent, immutable |
| When should the agent see it? | **Attention**: always, on-demand, searched, invisible |
| Who creates and owns it? | **Authorship**: protocol, human, agent, derived |
| What kind of thing is it? | **Space**: identity, capability, knowledge, operations, product |

**Example**: "Where do I put a brand guideline document?"
- Persistence: **Permanent** (doesn't change often)
- Attention: **Searched** (loaded when brand-related tasks come up)
- Authorship: **Human** (the operator writes it)
- Space: **Knowledge** (it's domain information)
- **Answer**: `reference/brand-guidelines.md`

**Example**: "Where do I put a generated sales proposal?"
- Persistence: **Permanent** (survives sessions)
- Attention: **On-Demand** (loaded when reviewing or continuing)
- Authorship: **Agent→Human** (agent writes, human reviews)
- Space: **Product** (it's work output)
- **Answer**: `output/proposals/2026-03-20-acme-proposal.md`

**Example**: "Where do I put the observation that agents keep misspelling company names?"
- Persistence: **Session→Permanent** (accumulates toward /rethink)
- Attention: **Searched** (checked during learning loop)
- Authorship: **Agent** (captured during operation)
- Space: **Operations** (ephemeral friction data)
- **Answer**: `.canopy/observations/spelling.jsonl`

**Example**: "Where does the agent's learned preference for using tables over bullet points go?"
- Persistence: **Permanent** (survived enough observations)
- Attention: **On-Demand** (loaded when generating output)
- Authorship: **Derived** (synthesized by /rethink)
- Space: **Capability** (it's procedural — "when X, do Y")
- **Answer**: `.canopy/procedural/output-formatting.yaml` (or promoted to `self/preferences.md` after /rethink)

---

## Relationship to Previous Docs

This document supersedes the separate models. Each previous doc described one dimension:

| Previous Doc | What It Described | Dimension | Status |
|-------------|-------------------|-----------|--------|
| `tiered-loading.md` | L0/L1/L2 context management | **Attention** dimension | Still valid as implementation detail |
| `memory-architecture.md` | Working/Episodic/Semantic/Procedural | **Persistence** + cross-dimension flow | Still valid as implementation detail |
| `three-space-model.md` | Self/Knowledge/Ops + 6 failure modes | **Space** dimension (3 of 5 categories) | Subsumed — 5 spaces now, not 3 |
| `project-layer.md` | Canopy Layer / Project Layer / .canopy | **Authorship** dimension | Subsumed — authorship is one of 4 dimensions |

The previous docs remain as **implementation guides** for their specific dimension.
This document is the **system map** that shows how they all fit together.

---

## The One-Sentence Version

Every component in a Canopy workspace answers 4 questions:
**How long does it live? When does the agent see it? Who writes it? What kind of thing is it?**

The filesystem encodes the answers. The engine reads the coordinates.
Context is the view. Memory is the flow. The workspace is the territory.

---

## Related

- [tiered-loading.md](tiered-loading.md) — Implementation detail for the Attention dimension
- [memory-architecture.md](memory-architecture.md) — Implementation detail for the Learning Flow
- [three-space-model.md](three-space-model.md) — Implementation detail for the Space dimension (Self/Knowledge/Ops)
- [project-layer.md](project-layer.md) — Implementation detail for the Authorship dimension
- [sessions.md](sessions.md) — Session persistence (Operations space)
- [heartbeat.md](heartbeat.md) — Agent execution cycle (Attention flow)
- [processing-pipeline.md](processing-pipeline.md) — 6R pipeline (Production + Learning flows)
