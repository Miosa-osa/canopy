# OptimalOS Methodology

## Core Philosophy

The operator's brain externalized as markdown files. Every numbered folder is a decision tree category. Every `context.md` is a persistent pattern library. Every signal file is episodic memory. Every playbook is a pre-computed response tree. The engine is optimal search across the whole library.

The insight: "My brain is nothing but markdown files." That is the architecture. The system grows with every new scenario captured. Retrieval gets faster as the library matures. The operator builds their ROM externally.

Three axioms:

1. Every output is a Signal — S = (Mode, Genre, Type, Format, Structure). Resolve all 5 dimensions before producing any non-trivial output. Unresolved dimensions create noise.
2. Maximize Signal-to-Noise ratio. Zero exceptions. S/N is not one metric among many; it is the measure of communication quality.
3. The engine searches the library optimally. Claude Code processes signals. Humans make decisions.

---

## Cognitive Science Foundation

OptimalOS is grounded in four cybernetic theories, applied to personal knowledge management and cognitive augmentation.

### Shannon — Channel Capacity
Every communication channel has finite capacity. Don't exceed the receiver's bandwidth. A 500-line explanation when 20 lines suffice is a Shannon violation. Applied in OptimalOS: S/N threshold of 0.3 minimum; signals scoring below are rejected at ingest. L0/L1/L2 tiered loading respects the reader's context window as a channel constraint.

### Ashby — Requisite Variety
A system must have enough response variety to handle every situation it encounters. If the situation needs a spec, write a spec — not a wall of prose. Applied in OptimalOS: 27-genre taxonomy ensures a valid encoding exists for every signal type. Genre mismatch is a diagnosable failure mode, not a style preference.

### Beer — Viable System Structure
Viable systems maintain coherent structure at every scale. A response, a file, a node, the full knowledge base — each must be coherently organized. No orphaned logic, no structure gaps. Applied in OptimalOS: `mix optimal.health` runs 10 structural diagnostics. Orphaned contexts, missing entities, and disconnected nodes are flagged as Beer violations.

### Wiener — Feedback Loops
Never broadcast without confirmation. Close every loop — verify the receiver decoded correctly. Applied in OptimalOS: `VerifyEngine` cold-reads L0 abstracts and confirms they predict content. `RethinkEngine` synthesizes evidence when confidence accumulates. The system never drifts silently.

### Signal Theory
Source: "Signal Theory: The Architecture of Optimal Intent Encoding".

Every Signal has 5 dimensions:

| Dim | Name | What It Determines |
|-----|------|--------------------|
| M | Mode | How it is perceived: linguistic, visual, code, data, mixed |
| G | Genre | Conventionalized form: spec, brief, transcript, note, plan, ... |
| T | Type | Speech act: direct (compel action), inform, commit, decide, express |
| F | Format | Container: markdown, code file, JSON, CLI output, diff |
| W | Structure | Internal skeleton: genre-specific template |

Before producing any non-trivial output, resolve all 5. Unresolved dimensions produce noise at the receiver.

---

## The Universal Signal Pattern

Every piece of information entering the system follows this 7-stage lifecycle:

### 1. CLASSIFY
Resolve S=(M,G,T,F,W) for the incoming signal. The intake pipeline applies this automatically via `mix optimal.ingest`. Manual classification uses the routing table in CLAUDE.md. S/N below 0.3 → reject. S/N 0.3–0.6 → accept with flagging. S/N above 0.6 → accept normally.

### 2. ROUTE
Match the classified signal to one or more nodes using the routing table. Financial data always routes to `11-money-revenue` in addition to the primary node. Decisions always route to the relevant `context.md` under "Key Decisions." Ambiguous signals route to `09-new-stuff` rather than misrouting.

### 3. STORE
Persistent facts → `context.md`. Temporal/episodic signals → dated signal files under `signals/`. Weekly status → `signal.md`. Never mix persistent facts with temporal signals in the same file.

### 4. INDEX
FTS5 full-text search index + entity extraction + optional vector embeddings. Run `mix optimal.index` after major file changes. Search-first retrieval uses this index — never grep through folders when `mix optimal.search` exists.

### 5. CONNECT
Cross-reference extracted entities. Build knowledge graph edges between co-occurring entities. The `GraphAnalyzer` tracks triangles (A→B and A→C exist but B→C is missing), clusters (isolated islands), and hubs (nodes with >2σ connection degree). Missing edges are synthesis opportunities.

### 6. DECAY
Apply temporal relevance based on genre half-lives. Operational signals decay faster than architectural decisions. The `Reweaver` module runs backward passes to find stale contexts and suggest updates. `mix optimal.reweave "topic"` surfaces what needs refreshing.

### 7. RETRIEVE
Hybrid search combining BM25 keyword scoring + vector similarity + Reciprocal Rank Fusion (RRF). Tiered loading: L0 (~100 tokens, abstract only) → L1 (~2K tokens, overview) → full (complete content). Never load full when L1 suffices.

---

## Quality Standards

| Standard | Threshold | Enforcement |
|----------|-----------|-------------|
| S/N ratio | 0.3 minimum at ingest | Intake rejects below threshold |
| L0 fidelity | Abstract must predict content | `mix optimal.verify` cold-reads and scores |
| Entity coverage | Every context has extracted entities | `mix optimal.health` flags missing |
| Graph connectivity | No orphaned contexts | `mix optimal.health` check #3 |
| Genre compliance | Every output matches a known genre skeleton | Manual review + taxonomy reference |
| Context freshness | Signals older than threshold flagged as stale | `mix optimal.reweave` with `--days` param |

---

## The 10-Stage Pipeline

The core pipeline has 6 foundational stages, extended to 10 with OptimalOS-specific capabilities.

### Core 6

**1. Record** — Signal intake via `mix optimal.ingest`. Auto-classifies S=(M,G,T,F,W), routes to primary + cross-reference nodes, writes signal files to disk, indexes in SQLite with FTS5, records in episodic memory, feeds SICA learning patterns.

**2. Reduce** — L0/L1/L2 tiered abstractions generated at ingest time. `SearchEngine` uses BM25 + vector scoring to rank results. L0 abstracts (~100 tokens) enable high-throughput scanning without loading full content.

**3. Reflect** — Entity co-occurrence scanning identifies missing knowledge graph edges. `Reflector` module surfaces pairs that appear together frequently but have no explicit connection. Run: `mix optimal.reflect --min 3`.

**4. Reweave** — Backward pass across the knowledge base. `Reweaver` identifies contexts that reference entities whose state has changed since the context was written. Surfaces update candidates with confidence scores. Run: `mix optimal.reweave "topic"`.

**5. Verify** — Cold-read fidelity testing. `VerifyEngine` reads L0 abstracts without access to full content, predicts what the full content contains, then compares predictions against reality. Fidelity score measures how well the abstraction represents the source. Run: `mix optimal.verify --sample 20`.

**6. Rethink** — Evidence synthesis when confidence accumulates. `RethinkEngine` tracks observation counts per topic in the `RememberLoop`. When confidence reaches threshold (default 1.5), it synthesizes accumulated evidence into updated beliefs. Run: `mix optimal.rethink "topic"` or `--force` to override threshold.

### OptimalOS Extensions

**7. Remember** — 3-mode friction capture via `RememberLoop`. Modes: explicit observation (`mix optimal.remember "text"`), contextual scan of recent signals (`--contextual`), bulk extraction from session transcripts (`--mine`). Feeds the Rethink confidence accumulator.

**8. Simulate** — Monte Carlo scenario planning via MCTS + `Simulator`. Models decision trees with probability-weighted outcomes. Stress-tests plans before committing. Run: `mix optimal.simulate`.

**9. Diagnose** — 10-check health diagnostics via `HealthDiagnostics`. Checks: orphaned contexts, entity drift, duplicate signals, missing cross-references, stale L0 abstracts, disconnected graph nodes, genre violations, S/N outliers, routing conflicts, index staleness. Run: `mix optimal.health`.

**10. Analyze** — Graph structure analysis via `GraphAnalyzer`. Triangle detection finds A→B + A→C without B→C (synthesis opportunities). Cluster detection finds isolated knowledge islands. Hub detection finds entities with anomalous connectivity (>2σ degree). Run: `mix optimal.graph triangles`.

---

## Operating Rhythm

The `rhythm/` folder is the daily operating layer. It defines HOW the operator moves through the system each day.

### Daily Sequence

| Block | Time | Mode | Purpose |
|-------|------|------|---------|
| BOOT | ~3pm | OPERATE | Wake → run `rhythm/boot.md` → generate `rhythm/today.md` from `week-plan.md` |
| OPERATE | 3–5pm | OPERATE | Clear queue: Slack, email, delegate, triage. Pre-call prep from `01-operator/positioning-playbook.md` |
| BUILD 1 | 5–8pm | BUILD | Deep work block 1. Single focus. No Slack. Load context: `mix optimal.assemble "{topic}"` |
| BREAK | 8–9pm | — | Eat. Move. |
| BUILD 2 | 9pm–1am | BUILD | Deep work block 2. Peak hours. Protect this window. |
| FLEX | 1–4am | LEARN / BUILD | Whatever energy allows: absorb, overflow build, content |
| SHUTDOWN | ~4–5am | EXTRACT | Run `rhythm/shutdown.md` → capture everything → energy log → seed tomorrow |

### Block Transition Protocol
Every block switch follows: **SAVE → CLEAR → LOAD**. No exceptions. Context leakage between modes degrades both.

### After Every Call
Mode → EXTRACT immediately. Run `mix optimal.ingest` while memory is fresh. Delay degrades signal quality.

### Weekly Cadence

**Monday — Brain Dump**
The operator walks through each node stream-of-consciousness. Capture everything. Classify after. Build `week-plan.md` from extracted priorities. Flag top 3 non-negotiables. Identify outbound signals (who gets what, in what genre).

**Friday — Review**
- Single-loop: Did the 3 non-negotiables happen? (`week-plan.md`)
- Double-loop: Were they the RIGHT 3 things? (`weekly-review.md`)
- Fidelity check: Did delegated signals come back as intended?
- Update `alignment.md` drift scores
- Run `mix optimal.health` — diagnose knowledge base
- Run `mix optimal.reweave` on key topics — find stale contexts
- Run `mix optimal.graph triangles` — find synthesis opportunities
- Run `mix optimal.remember --escalations` — see what's ready for Rethink

**Monthly — Triple-Loop Review**
`monthly-review.md` + alignment drift scoring across 4 dimensions. Assess whether the system itself needs structural changes.

---

## Failure Modes

Diagnosable failure modes organized by constraint violated:

### Shannon Violations (capacity exceeded)
| Mode | Symptom | Fix |
|------|---------|-----|
| Routing Failure | Signal sent to wrong node | Re-route using routing table |
| Bandwidth Overload | Output too dense for receiver | Reduce, prioritize, apply tiered loading |
| Fidelity Failure | Meaning lost in abstraction | Re-encode with clearer L0 structure |

### Ashby Violations (insufficient variety)
| Mode | Symptom | Fix |
|------|---------|-----|
| Genre Mismatch | Wrong form for receiver | Re-encode in correct genre from taxonomy |
| Variety Failure | No genre exists for situation | Create new genre; add to taxonomy |
| Structure Failure | No internal skeleton | Impose genre-specific template |

### Beer Violations (structural incoherence)
| Mode | Symptom | Fix |
|------|---------|-----|
| Bridge Failure | No shared context between sender/receiver | Add preamble; establish conventions |
| Herniation Failure | Incoherence across abstraction layers | Re-encode with proper L0/L1/L2 traversal |
| Decay Failure | Outdated signal presenting as current | Run `mix optimal.reweave`; version or sunset |

### Wiener Violations (open feedback loops)
| Mode | Symptom | Fix |
|------|---------|-----|
| Feedback Failure | No confirmation that signal was decoded | Close the loop: verify, check, confirm |

---

## What Sets OptimalOS Apart

OptimalOS builds on foundational personal knowledge management concepts with significant extensions:

| Dimension | Traditional PKM | OptimalOS |
|-----------|----------------|-----------|
| Foundation | General PKM | Signal Theory (Shannon + Ashby + Beer + Wiener) |
| Signal model | Content-centric | S=(M,G,T,F,W) 5-dimensional encoding |
| Genre system | Informal | 27-genre formal taxonomy with skeletons |
| Retrieval | Vector similarity | Hybrid BM25 + vector + RRF with tiered loading |
| Quality gate | None | S/N threshold 0.3; L0 fidelity verification |
| Maintenance | Manual | 10-check automated diagnostics |
| Graph analysis | Basic | Triangle detection, cluster analysis, hub detection |
| Scenario planning | None | Monte Carlo MCTS simulation |
| Friction capture | None | 3-mode RememberLoop → RethinkEngine synthesis |
| Operating rhythm | None | Cognitive mode system with daily/weekly/monthly cadence |

Core innovations built from scratch: simulation, graph analysis, S/N scoring, tiered loading, the genre taxonomy, and the full operating rhythm layer.

---

## Reference Commands

```bash
# Ingest a signal
cd engine && mix optimal.ingest "text or --file path --genre transcript"

# Search before answering questions
cd engine && mix optimal.search "query" --limit 5 --node ai-masters

# Assemble tiered context for a topic
cd engine && mix optimal.assemble "AI Masters pricing"

# Health check
cd engine && mix optimal.health

# Graph analysis
cd engine && mix optimal.graph triangles

# Friction capture
cd engine && mix optimal.remember --contextual
cd engine && mix optimal.remember --escalations

# Synthesis
cd engine && mix optimal.rethink "topic"

# Staleness check
cd engine && mix optimal.reweave "topic" --days 30

# L0 fidelity verification
cd engine && mix optimal.verify --sample 20
```

Full command reference: `CLAUDE.md` → "Context Engine" section.
Full genre catalogue: `docs/taxonomy/genres.md`
Architecture deep-dive: `docs/architecture/`
