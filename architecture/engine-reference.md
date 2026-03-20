# Engine Reference Architecture

> How to build the engine underneath a Canopy workspace. This is the reference
> implementation based on OptimalOS — 35+ modules, 23 CLI commands, 269 contexts,
> 416 entities, 1045 edges. Built in Elixir/OTP, but the patterns apply to any
> language.
>
> Read [`engine-layer.md`](engine-layer.md) first for backend OPTIONS.
> This document shows the IMPLEMENTATION — services, data flow, storage schemas,
> and how the funnel narrows from all your data to the agent's context window.

---

## The Funnel Model

The engine is a funnel. Wide at the bottom (all your data), narrow at the top
(the agent's context window). Every query starts in the ocean and gets filtered
down to what fits in the tunnel.

```
AGENT CONTEXT WINDOW (the tunnel — 2K-50K tokens)
         ▲
         │ formatted, structured, tiered
         │
    ┌────┴─────────────────────────────┐
    │  CONTEXT ASSEMBLER               │
    │  Combines L0 + L1 + L2 results   │
    │  Respects token budgets          │
    │  Formats for the agent           │
    └────┬──────────┬──────────┬───────┘
         │          │          │
    ┌────┴───┐ ┌────┴───┐ ┌───┴────┐
    │ L0     │ │ L1     │ │ L2     │
    │ Cache  │ │ Search │ │ Full   │
    │ Always │ │ Ranked │ │ Top N  │
    │ ~2K    │ │ ~10K   │ │ ~50K   │
    └────┬───┘ └────┬───┘ └───┬────┘
         │          │          │
    ┌────┴──────────┴──────────┴───────┐
    │  FUSION LAYER                    │
    │  Reciprocal Rank Fusion (k=60)   │
    │  Deduplication                    │
    │  Temporal decay + S/N boosting   │
    └────┬──────────┬──────────┬───────┘
         │          │          │
    ┌────┴───┐ ┌────┴───┐ ┌───┴────┐
    │ TEXT   │ │ VECTOR │ │ GRAPH  │
    │ FTS5   │ │ Cosine │ │ Edge   │
    │ BM25   │ │ Search │ │ Trav.  │
    └────┬───┘ └────┬───┘ └───┬────┘
         │          │          │
    ┌────┴──────────┴──────────┴───────┐
    │  THE OCEAN — all stored data     │
    │  contexts table + vectors table  │
    │  + edges table + memory tables   │
    │  + files on disk                 │
    └──────────────────────────────────┘
```

**NOT cylinders.** The agent doesn't have separate pipes to text search, vector
search, and graph search. It has ONE query interface (`/search`). The engine fans
out to all relevant stores in parallel, fuses results via RRF, then serves them
through the tier system. The agent never knows which store provided which result.

---

## The 12 Services

The engine is 12 services organized in 4 layers. Each service is an independent
process (GenServer in Elixir, microservice in other languages). They communicate
through function calls or message passing — never shared state.

```
LAYER 4 — USER INTERFACE
┌──────────────────────────────────────────────────┐
│  CLI Commands (Mix tasks)                        │
│  /search, /ingest, /assemble, /graph, /health,   │
│  /reweave, /verify, /remember, /rethink, etc.    │
└─────────────────────┬────────────────────────────┘
                      │ calls
LAYER 3 — ORCHESTRATION
┌──────────┬──────────┬──────────┬─────────────────┐
│ Context  │ Intake   │ Session  │ Simulator       │
│ Assembler│ Pipeline │ Manager  │                 │
│          │          │          │ Monte Carlo     │
│ Tiered   │ Classify │ Session  │ scenario        │
│ loading  │ → route  │ persist  │ planning +      │
│ L0+L1+L2 │ → write  │ + resume │ impact analysis │
│          │ → index  │ + compact│                 │
└────┬─────┴────┬─────┴────┬─────┴────┬────────────┘
     │          │          │          │
LAYER 2 — INTELLIGENCE
┌────┴─────┬────┴─────┬────┴─────┬────┴────────────┐
│ Search   │ Classif- │ Semantic │ Intent          │
│ Engine   │ ier      │ Processor│ Analyzer        │
│          │          │          │                 │
│ FTS5 +   │ S=(M,G,  │ Entity   │ Query intent    │
│ vector + │ T,F,W)   │ extract, │ detection,      │
│ graph    │ classify │ summarize│ routing         │
│ + RRF    │ + S/N    │ L0/L1    │                 │
│ fusion   │ gate     │ generate │                 │
└────┬─────┴────┬─────┴────┬─────┴────┬────────────┘
     │          │          │          │
LAYER 1 — STORAGE
┌────┴─────┬────┴─────┬────┴─────┬────┴────────────┐
│ Store    │ Vector   │ Graph    │ Memory          │
│ (SQLite) │ Store    │          │ Bridge          │
│          │          │          │                 │
│ contexts │ vectors  │ entities │ episodic,       │
│ + FTS5   │ + cosine │ + edges  │ semantic,       │
│ + ETS    │ search   │ + trav.  │ procedural,     │
│ cache    │          │          │ foresight,      │
│          │          │          │ observations    │
└──────────┴──────────┴──────────┴─────────────────┘
```

### Service Descriptions

| # | Service | Type | Responsibility |
|---|---------|------|----------------|
| 1 | **Store** | GenServer | SQLite connection + ETS hot cache. All DB access goes through here. Owns migrations, DDL, raw queries. |
| 2 | **VectorStore** | Stateless | Embedding storage + cosine similarity search. Stores vectors as float32 BLOBs in SQLite. |
| 3 | **Graph** | Stateless | Knowledge graph edge CRUD. Creates `mentioned_in`, `lives_in`, `cross_ref`, `supersedes` edges. |
| 4 | **Memory Bridge** | Stateless | Reads/writes episodic, semantic, procedural, and foresight memory. Connects engine to memory subsystem. |
| 5 | **SearchEngine** | GenServer | Hybrid search: FTS5 BM25 + vector cosine + graph traversal, fused via RRF with temporal decay and S/N boosting. |
| 6 | **Classifier** | Stateless | Signal Theory classification: S=(M,G,T,F,W). Rule-based + LLM fallback. S/N quality gate (reject < 0.3). |
| 7 | **SemanticProcessor** | Stateless | Entity extraction, summarization, L0 abstract generation, L1 overview generation. LLM-powered with graceful degradation. |
| 8 | **IntentAnalyzer** | Stateless | Analyzes query intent (search, navigate, create, update) and suggests search parameters. |
| 9 | **ContextAssembler** | Stateless | Tiered context assembly. Builds L0 (inventory) + L1 (summaries) + L2 (full content) within token budgets. |
| 10 | **Intake** | GenServer | Signal ingestion pipeline: classify → route → write → index → cross-ref → memory. The main write path. |
| 11 | **Session Manager** | DynamicSupervisor | Per-session GenServers for conversation state. Session compression when context fills. |
| 12 | **Simulator** | GenServer | Monte Carlo scenario planning + impact analysis. Uses MCTS for decision tree exploration. |

### Supporting Modules (not services — stateless functions)

| Module | What It Does |
|--------|-------------|
| **Router** | Keyword → node routing. Maps entities and triggers to workspace sections. |
| **Topology** | Loads the workspace structure (nodes, people, roles). |
| **L0Cache** | Generates + caches the always-loaded L0 inventory. Auto-refreshes every 30 min. |
| **Indexer** | File crawler. Walks the workspace, classifies files, persists Context records. |
| **Composer** | Output generation with Signal Theory encoding. Genre skeletons + receiver adaptation. |
| **HealthDiagnostics** | 10 diagnostic checks: orphans, stale signals, FTS drift, entity merge candidates, etc. |
| **GraphAnalyzer** | Triangle detection, cluster analysis, hub identification on the edge graph. |
| **Reflector** | Entity co-occurrence scan for missing edges. |
| **Reweaver** | Backward pass: finds stale contexts and suggests updates based on newer signals. |
| **VerifyEngine** | L0 fidelity test: does the abstract actually match the content? |
| **RememberLoop** | Friction capture: explicit observations, contextual extraction, session mining. |
| **RethinkEngine** | Evidence synthesis when cumulative confidence reaches threshold. |
| **MemoryExtractor** | Extracts patterns, decisions, and facts from session transcripts. |
| **SessionCompressor** | Compresses long sessions into structured handoff summaries. |

---

## Storage Schema

One SQLite database. Six core tables. Two virtual tables. One view.

### contexts (the universal table)

Every piece of content in the workspace — files, signals, memories, skills — is a
row in `contexts`. This is the single source of truth for the search index.

```sql
CREATE TABLE contexts (
  id TEXT PRIMARY KEY,             -- SHA-based or UUID
  uri TEXT NOT NULL DEFAULT '',    -- optimal://nodes/ai-masters/signals/...
  type TEXT NOT NULL DEFAULT 'resource',  -- resource | signal | memory | skill
  path TEXT,                       -- filesystem path
  title TEXT NOT NULL DEFAULT '',
  l0_abstract TEXT NOT NULL DEFAULT '',   -- ~15 words, always-loaded tier
  l1_overview TEXT NOT NULL DEFAULT '',   -- ~200 words, on-demand tier
  content TEXT NOT NULL DEFAULT '',       -- full content, deep tier

  -- Signal Theory dimensions
  mode TEXT,           -- linguistic | visual | code | data | mixed
  genre TEXT,          -- note | transcript | brief | spec | plan | ...
  signal_type TEXT,    -- inform | direct | commit | decide | express
  format TEXT,         -- markdown | json | yaml | code
  structure TEXT,      -- genre-specific skeleton name

  -- Routing
  node TEXT NOT NULL DEFAULT 'inbox',     -- primary workspace section
  routed_to TEXT NOT NULL DEFAULT '[]',   -- JSON array of cross-ref destinations

  -- Quality
  sn_ratio REAL NOT NULL DEFAULT 0.5,     -- 0.0-1.0 signal-to-noise
  entities TEXT NOT NULL DEFAULT '[]',     -- JSON array of extracted entities

  -- Temporal
  created_at TEXT,
  modified_at TEXT,
  valid_from TEXT,        -- when this becomes relevant
  valid_until TEXT,       -- when this expires
  supersedes TEXT,        -- ID of context this replaces

  -- Metadata
  metadata TEXT NOT NULL DEFAULT '{}',    -- JSON blob for extensibility
  indexed_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

**Why one table?** Every content type needs the same operations: search, tier, classify,
route, version. Separate tables for signals vs resources vs memories creates schema
divergence and duplicate queries. One table, filtered by `type`.

### contexts_fts (full-text search)

```sql
CREATE VIRTUAL TABLE contexts_fts USING fts5(
  id UNINDEXED,
  title,
  content,
  node UNINDEXED,
  type UNINDEXED,
  genre UNINDEXED
);

-- Auto-populated via INSERT/UPDATE/DELETE triggers on contexts
```

### vectors (embeddings)

```sql
CREATE TABLE vectors (
  context_id TEXT PRIMARY KEY REFERENCES contexts(id),
  embedding BLOB NOT NULL,       -- float32 little-endian (768 dims = 3KB)
  dimensions INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### entities + edges (knowledge graph)

```sql
CREATE TABLE entities (
  name TEXT PRIMARY KEY,
  type TEXT DEFAULT 'unknown',   -- person | org | concept | product | event
  properties TEXT DEFAULT '{}',  -- JSON
  first_seen TEXT,
  last_seen TEXT
);

CREATE TABLE edges (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source TEXT NOT NULL,           -- entity name, context ID, or node name
  target TEXT NOT NULL,
  relation TEXT NOT NULL,         -- mentioned_in | lives_in | cross_ref | works_on | supersedes
  weight REAL DEFAULT 1.0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_edges_source ON edges(source);
CREATE INDEX idx_edges_target ON edges(target);
CREATE INDEX idx_edges_relation ON edges(relation);
```

**Edge types:**

| Relation | Source | Target | Meaning |
|----------|--------|--------|---------|
| `mentioned_in` | entity name | context ID | Entity appears in this context |
| `lives_in` | context ID | node name | Context belongs to this workspace section |
| `cross_ref` | context ID | node name | Context is cross-referenced to this section |
| `works_on` | entity name | node name | Person works on this section |
| `supersedes` | context ID | context ID | Newer context replaces older one |

### Memory tables

```sql
-- Episodic: what happened in past sessions
CREATE TABLE episodic_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  summary TEXT NOT NULL,
  entities TEXT DEFAULT '[]',      -- JSON array
  decisions TEXT DEFAULT '[]',     -- JSON array
  action_items TEXT DEFAULT '[]',  -- JSON array
  compressed_at TEXT
);

-- Observations: friction capture for learning loop
CREATE TABLE observations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category TEXT NOT NULL,          -- e.g. "data_quality", "routing", "search"
  content TEXT NOT NULL,
  confidence REAL NOT NULL DEFAULT 0.6,
  source TEXT NOT NULL DEFAULT 'explicit',  -- explicit | contextual | mined
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Foresight: forward-looking predictions
CREATE TABLE foresight (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  prediction TEXT NOT NULL,
  confidence REAL NOT NULL DEFAULT 0.5,
  start_time TEXT,
  end_time TEXT,
  duration_days INTEGER,
  source_context_id TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### sessions

```sql
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  started_at TEXT NOT NULL,
  last_active TEXT NOT NULL,
  turn_count INTEGER DEFAULT 0,
  token_estimate INTEGER DEFAULT 0,
  compressed_summary TEXT,
  metadata TEXT DEFAULT '{}'
);
```

---

## Data Flow: The 3 Paths

### Write Path (Intake Pipeline)

When new information enters the workspace:

```
Raw input ("Ed called about pricing, wants $2K")
   │
   ▼
┌──────────────┐
│ CLASSIFIER   │  S=(linguistic, note, inform, markdown, note-skeleton)
│              │  sn_ratio = 0.7
│              │  Reject if S/N < 0.3
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ ROUTER       │  Keywords: "Ed", "pricing" → ai-masters
│              │  Financial data → also money-revenue
│              │  Cross-ref destinations: ["ai-masters", "money-revenue"]
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ SEMANTIC     │  Extract entities: ["Ed Honour", "$2K"]
│ PROCESSOR    │  Generate L0 abstract: "Ed Honour pricing call, $2K per seat"
│              │  Generate L1 overview: ~200 word summary
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ WRITER       │  Write signal file: ai-masters/signals/2026-03-20-ed-pricing.md
│              │  Write cross-ref: money-revenue/signals/2026-03-20-ed-pricing.md
│              │  Frontmatter: genre, type, entities, sn_ratio, routed_to
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ STORE        │  INSERT into contexts table
│              │  FTS5 auto-syncs via trigger
│              │  ETS cache updated
└──────┬───────┘
       │
       ├──── GRAPH: create edges (Ed Honour → context, context → ai-masters)
       ├──── VECTOR: embed L0+title, store in vectors table
       ├──── MEMORY: record episodic entry
       └──── FORESIGHT: extract predictions if any ("pricing due next week")
```

**Total time**: ~2-5 seconds (with LLM classification). ~200ms without LLM (rule-based only).

### Read Path (Search + Assembly)

When the agent needs information:

```
Agent query: "What did Ed say about pricing?"
   │
   ▼
┌──────────────┐
│ INTENT       │  Detect: search query, topic="Ed + pricing"
│ ANALYZER     │  Suggest: search with entity filter
└──────┬───────┘
       │
       ▼  PARALLEL fan-out
       ├──────────────────────────────────────────┐
       │                          │               │
┌──────┴──────┐  ┌───────────────┴──┐  ┌─────────┴────┐
│ TEXT SEARCH  │  │ VECTOR SEARCH    │  │ GRAPH SEARCH │
│             │  │                  │  │              │
│ FTS5 BM25   │  │ Embed query      │  │ "Ed Honour"  │
│ "Ed pricing"│  │ cosine vs all    │  │ → edges →    │
│ → ranked    │  │ vectors          │  │ all Ed       │
│ results     │  │ → ranked results │  │ contexts     │
└──────┬──────┘  └───────────┬──────┘  └──────┬───────┘
       │                     │                │
       └─────────┬───────────┘                │
                 │                            │
       ┌─────────┴────────────────────────────┘
       │
       ▼
┌──────────────┐
│ FUSION       │  Reciprocal Rank Fusion (k=60)
│              │  Deduplicate (same context from multiple stores)
│              │  Apply temporal decay (newer = higher)
│              │  Apply S/N boost (quality contexts rank higher)
│              │  → Single ranked list
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ CONTEXT      │  Token budget: L0=3K, L1=10K, L2=50K
│ ASSEMBLER    │  L0: pre-cached inventory (what exists)
│              │  L1: summaries of top matches (what's relevant)
│              │  L2: full content of top 1-3 (what to read)
│              │  → Assembled context string with tier markers
└──────┬───────┘
       │
       ▼
Agent receives structured, tiered context
```

**Total time**: ~100-500ms for keyword+graph. ~500-2000ms with vectors. ~2-10s for agentic multi-round.

### Learning Path (Memory Loop)

When the system learns from experience:

```
Session ends OR user observes friction
   │
   ├──── EXPLICIT: "always check duplicates before inserting"
   │     → Classify category → Store observation (confidence 0.6)
   │
   ├──── CONTEXTUAL: scan recent signals for correction patterns
   │     → MemoryExtractor finds correction signals
   │     → Store observations (confidence 0.4 each)
   │
   └──── SESSION MINING: bulk extract from transcripts
         → SessionCompressor summarizes session
         → MemoryExtractor extracts patterns
         → Store observations (confidence 0.3 each)
              │
              ▼
┌──────────────────┐
│ ACCUMULATION     │  GROUP BY category
│                  │  Sum confidence per category
│                  │  When sum >= 1.5 → ready for synthesis
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ RETHINK ENGINE   │  Gather all observations + search results for topic
│                  │  Generate synthesis with evidence
│                  │  Produce structured report:
│                  │    - What was observed (evidence)
│                  │    - What it means (synthesis)
│                  │    - What to change (proposed updates)
│                  │  → Human reviews → approves → updates workspace ROM
└──────────────────┘
```

**This is how the workspace gets smarter over time.** Raw friction → observations →
accumulation → synthesis → codified knowledge. The learning loop turns RAM (session
experience) into ROM (workspace knowledge).

---

## Supervision Tree (OTP Model)

The engine runs as a supervision tree. If any service crashes, the supervisor
restarts it independently without taking down the whole engine.

```
OptimalEngine.Supervisor (one_for_one)
├── Store              ← starts FIRST (all others depend on DB)
├── Router             ← loads routing rules from topology
├── Indexer            ← file crawler, depends on Store
├── SearchEngine       ← query executor, depends on Store
├── L0Cache            ← inventory cache, depends on Store
├── Intake             ← ingestion pipeline, depends on all above
├── Simulator          ← scenario planning, depends on SearchEngine
├── SessionRegistry    ← Registry for session name lookup
├── SessionSupervisor  ← DynamicSupervisor for per-session GenServers
├── Memory.Episodic    ← episodic memory service
├── Memory.Cortex      ← semantic memory + knowledge graph queries
└── Memory.Learning    ← observation accumulation + pattern detection
```

**Why one_for_one?** Each service is independent. If the SearchEngine crashes, the
Store keeps running, sessions continue, and SearchEngine restarts fresh. Only the
Store starting first matters (it's the DB connection).

**In other languages:**
- **Python**: Each service is an async class. Use `asyncio.TaskGroup` or separate processes.
- **Go**: Each service is a goroutine. Use channels for inter-service communication.
- **Node.js**: Each service is a class with async methods. Single process, event loop.
- **Rust**: Each service is a `tokio::spawn`ed task. Channels for communication.

The pattern is the same: independent services, one owns the DB, others communicate
through function calls, crash isolation per service.

---

## Knowledge Graph: Triple-Store Architecture

The knowledge graph is built on the MIOSA Knowledge system — a triple-store
(subject-predicate-object) with 3-way indexing and optional SPARQL querying.

### Why Triples

Every relationship in a workspace is a triple: `("Ed Honour", "works_on", "AI Masters")`.
Triples are the simplest possible graph representation — they compose into arbitrarily
complex structures without schema changes. Add a new relationship type? Just assert
a new triple. No migration needed.

### 3-Way Indexing (SPO / POS / OSP)

The triple-store maintains three indexes for the same data:

```
SPO index:  (subject, predicate, object)    ← "What does Ed work on?"
POS index:  (predicate, object, subject)    ← "Who works on AI Masters?"
OSP index:  (object, subject, predicate)    ← "What relationships mention AI Masters?"
```

**Automatic index selection** based on which positions are bound:

| Query Pattern | Index Used | Example |
|--------------|-----------|---------|
| `(?s, ?p, ?o)` | Full scan (SPO) | "Give me everything" |
| `(Ed, ?p, ?o)` | SPO | "What do we know about Ed?" |
| `(?s, works_on, ?o)` | POS | "Who works on what?" |
| `(?s, ?p, AI Masters)` | OSP | "What connects to AI Masters?" |
| `(Ed, works_on, ?o)` | SPO | "What does Ed work on?" |
| `(Ed, works_on, AI Masters)` | SPO | "Does Ed work on AI Masters?" (existence check) |

O(1) or O(log n) for any query pattern. No query is slow regardless of which
fields you bind.

### Dictionary Encoding (Advanced)

For high-performance knowledge graphs, encode RDF terms as 64-bit integer IDs
instead of storing raw strings in every triple:

```
Bits 63-60: Type tag
  0x1 = URI
  0x2 = Blank node
  0x3 = Literal (string)
  0x4 = Integer (inline — value stored in low 60 bits, NO dictionary lookup)
  0x5 = DateTime (inline — epoch millis in low 60 bits)
  0x6 = Decimal (inline — custom float format)

Bits 59-0: Sequence ID (from :atomics counter) or inline value
```

**Why**: Storing `"Ed Honour"` as a 8-byte integer vs a 10-byte string reduces
storage 20x when the same entity appears in 100+ triples. Joins on integers
are 10-50x faster than string comparison. Inline encoding for numbers and dates
means common values never touch the dictionary at all.

### Quad Store: Named Graphs

The knowledge graph is actually a **quad store** — every triple has an optional
fourth element: the **graph** it belongs to. This lets you manage multiple
isolated knowledge graphs in one store.

```
Triple:  (subject, predicate, object)
Quad:    (graph, subject, predicate, object)
```

**Why quads matter for workspaces:**
- Each workspace section (node) gets its own named graph
- Agent-specific knowledge stays isolated from shared facts
- You can query across all graphs OR scope to one
- Reasoning can be graph-scoped (infer within a domain, not globally)

**Quad indexing** — 4 permutation indices instead of 3:

| Index | Key Order | Answers |
|-------|----------|---------|
| GSPO | graph, subject, predicate, object | "What's in this graph?" |
| GPOS | graph, predicate, object, subject | "Who has this property in this graph?" |
| SPOG | subject, predicate, object, graph | "Which graphs contain this fact?" |
| POSG | predicate, object, subject, graph | "Where does this relationship exist?" |

### Implementation Options

| Backend | Storage | Best For | Trade-offs |
|---------|---------|----------|-----------|
| **ETS** (in-memory) | 3-4 ordered_set tables | Single-node, fast, <1M triples | Lost on restart. Fast restores from snapshots. Sub-microsecond reads. |
| **SQLite edges** | 1 table + 3-4 indexes | Persistence without infrastructure | Slightly slower than ETS. Survives restarts. |
| **RocksDB** | LSM-tree key-value | >100K triples, persistent, large graphs | C NIF. Prefix scans as trie iterators. Best for graphs that don't fit in memory. |
| **Mnesia** (distributed) | Replicated across nodes | Multi-node BEAM clusters | Complex setup. Worth it for distributed systems. |
| **Neo4j** | Native graph DB | >1M triples, complex traversals | JVM dependency. Overkill for most workspaces. |
| **DuckDB** | Embedded OLAP | Analytics over graph data | Great for aggregate queries. Not a graph traversal engine. |

**RocksDB key encoding** (when using dictionary encoding):
```
Triple key: 24 bytes (3 × 64-bit big-endian IDs)
  [subject_id:8][predicate_id:8][object_id:8]

Quad key: 32 bytes (4 × 64-bit big-endian IDs)
  [graph_id:8][subject_id:8][predicate_id:8][object_id:8]

Value: empty — the key IS the data

Big-endian encoding ensures lexicographic order = numeric order,
enabling efficient prefix scans for pattern matching.
```

**Recommendation**: SQLite edges table for most workspaces (it's already in the
Store). Add ETS overlay for hot-path reads. Use the 3-index pattern on SQLite:

```sql
CREATE TABLE edges (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source TEXT NOT NULL,
  predicate TEXT NOT NULL,
  target TEXT NOT NULL,
  weight REAL DEFAULT 1.0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- The 3-way index
CREATE INDEX idx_edges_spo ON edges(source, predicate, target);
CREATE INDEX idx_edges_pos ON edges(predicate, target, source);
CREATE INDEX idx_edges_osp ON edges(target, source, predicate);
```

### SPARQL (Optional)

For workspaces that need structured graph queries, the engine can include a
SPARQL 1.1 subset parser + executor:

```sparql
# Find all people who work on AI Masters and their roles
SELECT ?person ?role WHERE {
  ?person works_on ai-masters .
  ?person has_role ?role .
}

# Find triangle opportunities (A→B, A→C, but no B→C)
SELECT ?a ?b ?c WHERE {
  ?a related_to ?b .
  ?a related_to ?c .
  FILTER NOT EXISTS { ?b related_to ?c }
  FILTER (?b != ?c)
}
```

Most workspaces don't need SPARQL — the edge queries in the Graph module handle
90% of cases. SPARQL is for power users who want complex multi-hop traversals.

### OWL Reasoning (Advanced)

For knowledge-intensive workspaces, the engine can run forward-chaining OWL 2 RL
rules to materialize inferred triples:

```
If: (Ed works_on AI-Masters) AND (AI-Masters is_part_of Lunivate)
Then infer: (Ed works_on Lunivate)    ← transitive closure

If: (Ed reports_to Roberto) AND (reports_to subPropertyOf works_with)
Then infer: (Ed works_with Roberto)   ← property hierarchy
```

Semi-naive evaluation: only fires rules on NEW triples from the previous round.
Runs until fixed-point (no new inferences). 16 built-in rules covering transitivity,
property hierarchy, class membership, and inverse relationships.

### Advanced Join Strategies

For complex graph queries with 4+ triple patterns sharing variables:

| Strategy | When to Use | How It Works |
|----------|------------|-------------|
| **Nested loop** | Small inputs (<100 results per pattern) | For each result in A, scan B for matches. Simple, no setup cost. |
| **Hash join** | Medium/large with good selectivity | Build hash table on smaller input, probe with larger. O(n+m). |
| **Leapfrog Triejoin** | 4+ patterns sharing variables | Worst-case optimal multi-way join. Uses sorted iterators (prefix scans on RocksDB, sorted ETS) as tries. Seeks to the next matching position across all iterators simultaneously. |

**Cost-based query optimization** (for engines that need it):
1. Collect per-predicate statistics: total count, distinct subjects, distinct objects
2. Estimate cardinality for each triple pattern based on bound positions
3. Reorder patterns: most selective first (smallest estimated cardinality)
4. For ≤5 patterns: exhaustive join enumeration
5. For >5 patterns: DPccp algorithm (Moerkotte & Neumann) for near-optimal ordering
6. Cache optimized query plans (LRU, invalidated on writes)

Most workspaces don't need this — simple pattern matching handles 95% of queries.
Add cost-based optimization when you have >10K edges and complex multi-hop queries.

---

## Memory Subsystem: MIOSA Memory Architecture

The memory system is built on MIOSA Memory — a collection-based store with
episodic recording, context injection, Cortex synthesis, and the SICA learning engine.

### Memory Collections

Memory is organized in named collections with typed entries:

```
collections/
├── episodic          ← What happened (sessions, events, calls)
│   ├── patterns      ← Recurring patterns extracted from episodes
│   ├── solutions     ← Fix recipes and approaches that worked
│   └── decisions     ← Choices made with rationale
├── semantic          ← What's true (facts, entities, relationships)
├── procedural        ← How to do things (skills, workflows, rules)
└── workspace         ← Workspace-specific context (per-project)
```

Each entry:
```
{
  key: "ed-pricing-preference",
  value: "Ed prefers $2K/seat annual billing, resists monthly",
  tags: ["ed-honour", "pricing", "ai-masters"],
  metadata: {
    category: :project_info,
    scope: :workspace,
    created_at: "2026-03-20T...",
    access_count: 5,
    relevance_score: 0.85
  }
}
```

### 7-Category Taxonomy

Content is auto-classified into categories using keyword signal matching:

| Category | Triggers (keyword signals) | What It Captures |
|----------|---------------------------|-----------------|
| `user_preference` | prefer, like, want, style, always, never | How the user wants things done |
| `project_info` | project, build, feature, milestone, deadline | Current project state |
| `project_spec` | spec, requirement, must, constraint, API | Technical specifications |
| `lesson` | learned, mistake, remember, don't, avoid | Captured corrections |
| `pattern` | pattern, usually, tends to, often, when | Recurring behaviors |
| `solution` | fixed, solved, workaround, approach, solution | What worked |
| `context` | context, background, history, previously | Situational knowledge |

**3 scopes**: `global` (all workspaces), `workspace` (this project), `session` (this conversation).

### Memory Injection: What Gets Surfaced

The Injector decides WHICH memories are relevant to the current conversation.
Weighted relevance scoring:

```
relevance = (base_score * 0.3) + (contextual_score * 0.5) + (recency_score * 0.2)

Where:
  base_score      = category weight (lesson: 0.9, pattern: 0.8, solution: 0.85, ...)
                  × scope weight (session: 1.0, workspace: 0.8, global: 0.6)

  contextual_score = max of:
                    - file extension match (working on .ex? boost Elixir memories)
                    - task keyword match (fixing bug? boost solutions + lessons)
                    - error message match (seen this error before?)
                    - session topic match (talking about Ed? boost Ed memories)

  recency_score   = exp(-0.693 * hours_since_access / 48)
                    Half-life of 48 hours. Recent memories surface first.
```

**Threshold**: Only inject memories with `relevance >= 0.5`. Below that → noise.

### Context Strategies

When assembling context for the agent, three strategies:

| Strategy | When to Use | How It Works |
|----------|------------|-------------|
| **Recent** | Simple tasks, short conversations | Last N messages from session. No memory injection. |
| **Relevant** | Most tasks | Recent messages + keyword-matched memories injected as system context. The default. |
| **Summary** | Long sessions approaching token limit | Older messages summarized, recent kept verbatim, memories injected. |

**Token budget compaction** (3 thresholds):

| Threshold | % of Limit | Action |
|-----------|-----------|--------|
| **Warn** | 85% | Log warning. Continue normally. |
| **Compact** | 90% | Summarize older messages. Trim low-relevance memories. |
| **Hard stop** | 95% | Generate handoff summary. Start fresh session with summary as L0. |

### Cortex: Periodic Synthesis

A background process that periodically distills memory + sessions into a
structured bulletin:

```
Every N minutes (configurable):
  1. Read recent sessions (last 24h)
  2. Read long-term memory (all collections)
  3. Extract topic frequencies via keyword analysis
  4. Build structured prompt for LLM
  5. Generate bulletin (temperature: 0.2, max_tokens: 500)
  6. Cache bulletin for fast reads
```

**Bulletin structure**:
```markdown
## Current Focus
- [what the user is actively working on]

## Pending Items
- [tasks mentioned but not completed]

## Key Decisions
- [choices made with rationale]

## Patterns
- [recurring behaviors or preferences detected]

## Context
- [background needed for current work]
```

The Cortex bulletin is injected into L0 when available — it's a synthesized
"what you need to know right now" snapshot. Costs ~500 tokens. Updated every
30 minutes or on-demand.

### SICA Learning Engine

The self-improving learning loop:

```
OBSERVE  → Track every tool call, error, correction, and outcome
           Record: {type, tool, duration, success, result}

REFLECT  → Detect patterns in observations
           "This error happened 3 times with the same fix"
           "User corrected this approach — capture alternative"

PROPOSE  → Generate candidate rules/patterns
           "When X happens, do Y instead of Z"
           Confidence scored by evidence count

TEST     → Validate proposed rules against future interactions
           Does the rule actually help? Track hit rate.

INTEGRATE → Graduate tested rules into procedural memory
            High-confidence rules → workspace ROM (skills, reference docs)
            Low-confidence rules → keep testing
```

**3 memory tiers in the learning engine**:

| Tier | Storage | TTL | What Lives Here |
|------|---------|-----|----------------|
| **Working** | In-memory (ETS) | 15 minutes | Raw observations, scratch data |
| **Episodic** | JSONL files | 30 days | Session recordings, interaction logs |
| **Semantic** | Permanent store | Forever | Graduated patterns, proven rules, facts |

**Consolidation triggers**:
- **Incremental**: Every 5 interactions — lightweight pattern scan
- **Full**: Every 50 interactions — deep analysis across all episodic memory

User corrections get **immediate capture** — when the user says "no, do it this
way", the correction is stored with high confidence (0.9) and surfaces in future
similar situations.

---

## The Scoring Formula

Search results are ranked by a composite score:

```
final_score = bm25_score * temporal_factor * sn_ratio_boost

Where:
  bm25_score      = SQLite FTS5 BM25 rank (higher = more relevant)
  temporal_factor  = exp(-age_hours / (genre_half_life * 24))
  sn_ratio_boost   = 0.5 + (sn_ratio * 0.5)   -- range 0.5 to 1.0
```

**Temporal decay by genre:**

| Genre | Half-Life | Why |
|-------|----------|-----|
| Signal / note | 30 days | Temporal signals decay fast |
| Transcript | 60 days | Call notes stay relevant longer |
| Decision | 180 days | Decisions have long relevance |
| Reference / spec | 720 days | Reference material barely decays |
| Context (persistent fact) | 720 days | Ground truth is nearly permanent |

**S/N ratio boost:** Higher quality contexts rank higher. A context with `sn_ratio: 0.9`
gets a 0.95x multiplier. One with `sn_ratio: 0.3` gets a 0.65x multiplier. This
means well-classified, well-structured content naturally surfaces above noisy captures.

---

## RRF Fusion: How Multiple Stores Merge

When search hits both text index and vector store, results are fused using
Reciprocal Rank Fusion:

```
For each result r in result_set S:
  rrf_score(r) = Σ  1 / (k + rank_in_S(r))   for each S containing r

k = 60 (standard constant)
```

**Example:**

| Context | Text Rank | Vector Rank | RRF Score |
|---------|----------|------------|-----------|
| ed-pricing-call | 1 | 3 | 1/61 + 1/63 = 0.0323 |
| ai-masters-plan | 2 | 1 | 1/62 + 1/61 = 0.0325 |
| pricing-decision | 3 | 2 | 1/63 + 1/62 = 0.0320 |

`ai-masters-plan` wins because it ranked top-1 in vector search even though it was
rank-2 in text search. RRF respects both signals without needing to normalize scores
across different ranking systems.

---

## CLI Commands (The User Interface)

Every engine function is exposed through a CLI command. The agent calls these
commands, never the database directly.

### Core Operations

| Command | What It Does | Services Used |
|---------|-------------|---------------|
| `/search <query>` | Hybrid search with options | SearchEngine + VectorStore + Graph |
| `/ingest <text>` | Classify → route → write → index | Intake + Classifier + Router + SemanticProcessor + Store |
| `/assemble <topic>` | Build tiered context bundle | ContextAssembler + SearchEngine + L0Cache |
| `/read <uri> --tier l0\|l1\|full` | Read at specific tier | Store |
| `/ls <uri>` | Browse workspace structure | Store + Topology |
| `/l0` | Show always-loaded context | L0Cache |
| `/index` | Full reindex from files | Indexer + Store |
| `/stats` | Store statistics | Store |

### Graph Analysis

| Command | What It Does | Services Used |
|---------|-------------|---------------|
| `/graph` | Stats + sample edges | Graph |
| `/graph triangles` | Find A→B, A→C but no B→C | GraphAnalyzer |
| `/graph clusters` | Find isolated knowledge islands | GraphAnalyzer |
| `/graph hubs` | Entities with degree >2σ | GraphAnalyzer |
| `/reflect` | Entity co-occurrences without edges | Reflector |

### Health & Verification

| Command | What It Does | Services Used |
|---------|-------------|---------------|
| `/health` | 10 diagnostic checks | HealthDiagnostics + Store |
| `/verify --sample N` | L0 fidelity test | VerifyEngine + Store |
| `/reweave <topic>` | Find stale contexts, suggest updates | Reweaver + SearchEngine + Graph |

### Learning Loop

| Command | What It Does | Services Used |
|---------|-------------|---------------|
| `/remember <text>` | Capture explicit observation | RememberLoop |
| `/remember --contextual` | Scan recent signals for friction | RememberLoop + MemoryExtractor |
| `/remember --mine` | Bulk extract from sessions | RememberLoop + MemoryExtractor |
| `/remember --escalations` | Categories ready for synthesis | RememberLoop |
| `/rethink <topic>` | Synthesize when confidence >= 1.5 | RethinkEngine + SearchEngine |

### Simulation

| Command | What It Does | Services Used |
|---------|-------------|---------------|
| `/simulate` | Monte Carlo scenario planning | Simulator + MCTS |
| `/impact` | Impact analysis of proposed changes | Simulator + SearchEngine |

---

## Implementing in Your Language

The engine is language-agnostic. Here's how the 12 services map:

### Python Implementation

```python
# Service 1: Store
class Store:
    def __init__(self, db_path="engine/db/workspace.db"):
        self.conn = sqlite3.connect(db_path)
        self.cache = {}  # LRU cache, max 500 entries
        self._run_migrations()

    def raw_query(self, sql, params=[]):
        return self.conn.execute(sql, params).fetchall()

    def insert_context(self, context: Context):
        # INSERT into contexts + auto-triggers handle FTS5
        pass

# Service 5: SearchEngine
class SearchEngine:
    def __init__(self, store, vector_store, graph):
        self.store = store
        self.vector_store = vector_store
        self.graph = graph

    def search(self, query, **opts):
        # Fan out to all stores in parallel
        text_results = self._fts_search(query, opts)
        vector_results = self.vector_store.search(query, opts)
        graph_results = self.graph.search_by_entity(query)

        # Fuse via RRF
        fused = self._rrf_fusion(text_results, vector_results, graph_results)

        # Apply temporal decay + S/N boost
        scored = [self._apply_scoring(r) for r in fused]

        return sorted(scored, key=lambda r: r.score, reverse=True)[:opts.get('limit', 10)]

# Service 10: Intake
class Intake:
    def __init__(self, classifier, router, semantic, store, graph, vector_store, memory):
        self.classifier = classifier
        self.router = router
        # ... all dependencies injected

    def process(self, text, **opts):
        # 1. Classify
        signal = self.classifier.classify(text)
        if signal.sn_ratio < 0.3:
            raise SignalTooNoisy(signal)

        # 2. Route
        destinations = self.router.route(signal, text)

        # 3. Semantic processing
        entities = self.semantic.extract_entities(text)
        l0 = self.semantic.generate_l0(text)
        l1 = self.semantic.generate_l1(text)

        # 4. Write files
        files = self._write_signal_files(signal, destinations, text)

        # 5. Index
        context = self.store.insert_context(...)

        # 6. Graph edges (async)
        self.graph.create_edges(context, entities, destinations)

        # 7. Vector embedding (async)
        self.vector_store.embed_and_store(context.id, l0 + title)

        # 8. Memory (async)
        self.memory.record_episodic(context)

        return IntakeResult(context=context, files=files, destinations=destinations)
```

### Go Implementation

```go
// Service 1: Store
type Store struct {
    db    *sql.DB
    cache *lru.Cache
    mu    sync.RWMutex
}

func NewStore(dbPath string) (*Store, error) {
    db, err := sql.Open("sqlite3", dbPath)
    if err != nil { return nil, err }
    cache, _ := lru.New(500)
    s := &Store{db: db, cache: cache}
    s.runMigrations()
    return s, nil
}

// Service 5: SearchEngine
type SearchEngine struct {
    store       *Store
    vectorStore *VectorStore
    graph       *Graph
}

func (se *SearchEngine) Search(ctx context.Context, query string, opts SearchOpts) ([]Context, error) {
    // Fan out in parallel
    g, gctx := errgroup.WithContext(ctx)
    var textResults, vectorResults, graphResults []ScoredResult

    g.Go(func() error { /* FTS5 search */ })
    g.Go(func() error { /* vector search */ })
    g.Go(func() error { /* graph search */ })

    if err := g.Wait(); err != nil { return nil, err }

    // Fuse via RRF
    fused := rrfFusion(textResults, vectorResults, graphResults)
    return applyScoring(fused, opts.Limit), nil
}
```

### Node.js Implementation

```typescript
// Service 1: Store
class Store {
    private db: Database;
    private cache: Map<string, Context>;

    constructor(dbPath: string) {
        this.db = new Database(dbPath);
        this.cache = new Map();
        this.runMigrations();
    }

    async rawQuery(sql: string, params: any[]): Promise<any[]> {
        return this.db.prepare(sql).all(...params);
    }
}

// Service 5: SearchEngine
class SearchEngine {
    constructor(
        private store: Store,
        private vectorStore: VectorStore,
        private graph: Graph,
    ) {}

    async search(query: string, opts: SearchOpts = {}): Promise<Context[]> {
        // Fan out in parallel
        const [textResults, vectorResults, graphResults] = await Promise.all([
            this.ftsSearch(query, opts),
            this.vectorStore.search(query, opts),
            this.graph.searchByEntity(query),
        ]);

        // Fuse via RRF
        const fused = this.rrfFusion(textResults, vectorResults, graphResults);
        return this.applyScoring(fused).slice(0, opts.limit ?? 10);
    }
}
```

---

## What EverMemOS Got Right (and What We Stole)

| Pattern | EverMemOS | Our Adaptation |
|---------|-----------|----------------|
| **Foresight memory** | Predictions with time bounds | Added `foresight` table with confidence + time windows |
| **Agentic retrieval** | LLM judges sufficiency, generates sub-queries | Available as escalation in retrieval hierarchy (step 6) |
| **RRF fusion** | BM25 + vector via Reciprocal Rank Fusion (k=60) | Same formula, same k value — it's standard IR |
| **Boundary detection** | LLM decides when conversation segment is complete | Informs SessionCompressor design |
| **Multi-run evaluation** | N independent LLM judge calls with std dev | Pattern for our `/verify` quality checks |

| Pattern | EverMemOS | Why We Didn't Steal It |
|---------|-----------|----------------------|
| **Triple-store infra** | MongoDB + Elasticsearch + Milvus | Too heavy. We have our own triple-store (SPO/POS/OSP) on SQLite/ETS from MIOSA Knowledge. |
| **MemCell** | Atomic memory container | Our Context struct already serves this role |
| **Profile synthesis** | Cluster + synthesize user profiles | Our Cortex bulletin + entity system covers this better |
| **Learning engine** | None (they don't have one) | Our SICA loop (Observe→Reflect→Propose→Test→Integrate) is more sophisticated |
| **Computer use** | Claimed but doesn't exist in OSS repo | Vaporware |
| **Graph visualization** | Claimed but doesn't exist in OSS repo | Vaporware |

### Where MIOSA Systems Came From

The knowledge graph and memory subsystems in this reference architecture are
battle-tested — they come from two production Elixir libraries:

| System | Repo | What It Provides |
|--------|------|-----------------|
| **MIOSA Knowledge** | `Miosa-osa/miosa-knowledge` | Quad store with 3/4-way indexing, SPARQL parser, OWL 2 RL reasoning, RocksDB persistence, `for_agent/2` context injection |
| **MIOSA Memory** | `Miosa-osa/miosa-memory` | Collections, episodic recording, Cortex synthesis, SICA learning, taxonomy classification, session persistence, token budget compaction |

Both are pure Elixir, designed for single-node personal systems that scale to
distributed with backend swaps (ETS → Mnesia → RocksDB → Riak). The patterns are
language-agnostic — implement in Python, Go, Node, or Rust using the same architecture.

---

## Related

- [`engine-layer.md`](engine-layer.md) — Pluggable backend options (what to use)
- [`system-model.md`](system-model.md) — 4-dimensional coordinate system (where things sit)
- [`../guides/data-architecture.md`](../guides/data-architecture.md) — Data buckets, tiers, storage rules (how to organize)
- [`tiered-loading.md`](tiered-loading.md) — L0/L1/L2/L3 specification
- [`memory-architecture.md`](memory-architecture.md) — Memory type deep dive
- [`processing-pipeline.md`](processing-pipeline.md) — 6R knowledge pipeline
