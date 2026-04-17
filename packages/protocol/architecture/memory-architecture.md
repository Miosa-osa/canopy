# Memory Architecture

> 4-layer memory system for persistent, retrievable, and decaying knowledge. Agents
> don't just process — they remember. Memory architecture defines how knowledge is
> stored, retrieved, strengthened, decayed, and synthesized across sessions.
>
> Cognitive memory layers modeled on human memory systems. Designed for OSA Operations
> with tiered loading integration, Signal Theory classification, and budget-aware retrieval.

---

## The 4 Layers

```
┌─────────────────────────────────────────────────────┐
│  WORKING MEMORY                                     │
│  Current session context, active task state          │
│  Volatile — cleared on session end                   │
│  Capacity: bounded by context window                 │
├─────────────────────────────────────────────────────┤
│  EPISODIC MEMORY                                    │
│  Session transcripts, compressed interaction logs   │
│  Time-indexed — "what happened, when, with whom"     │
│  Capacity: unlimited, with compression + decay       │
├─────────────────────────────────────────────────────┤
│  SEMANTIC MEMORY                                    │
│  Extracted facts, entities, relationships            │
│  Query-indexed — "what do we know about X"           │
│  Capacity: unlimited, with conflict resolution       │
├─────────────────────────────────────────────────────┤
│  PROCEDURAL MEMORY                                  │
│  Learned patterns, preferences, heuristics           │
│  Trigger-indexed — "when X happens, do Y"            │
│  Capacity: curated, high-confidence only             │
└─────────────────────────────────────────────────────┘
```

---

## Layer 1: Working Memory

Working memory is the agent's current context — what it knows RIGHT NOW during
this session. It maps directly to the LLM context window.

### Contents

```yaml
working_memory:
  system_prompt: "..."           # SYSTEM.md + agent definition
  l0_abstracts: [...]            # Always-loaded knowledge (from tiered-loading)
  l1_summaries: [...]            # On-demand summaries loaded for current task
  task_context:                  # Current task details
    id: "task_01HQ..."
    description: "Draft pricing proposal for AI Masters"
    constraints: ["Must not exceed $2K", "Use brief genre"]
  conversation_history: [...]    # This session's turns
  scratch_pad: "..."             # Agent's working notes (thinking out loud)
```

### Characteristics

| Property | Value |
|----------|-------|
| Persistence | None — volatile, session-scoped |
| Capacity | Context window minus system overhead |
| Access time | Immediate (in-context) |
| Decay | Instant on session end |
| Population | Boot sequence loads L0, task loads L1, user provides input |

### Overflow Handling

When working memory approaches context limits:

```
Context usage check (every turn)
  │
  ├── < 70% → Normal operation
  │
  ├── 70-85% → Compress: summarize older conversation turns
  │
  ├── 85-90% → Evict: remove lowest-relevance L1 summaries
  │
  ├── 90-95% → Compact: write session handoff, start fresh session
  │
  └── > 95% → Emergency: dump to episodic memory, hard reset
```

```elixir
defmodule Memory.Working do
  @warning_threshold 0.70
  @compress_threshold 0.85
  @evict_threshold 0.90
  @compact_threshold 0.95

  def check_pressure(session) do
    usage = Session.token_usage(session.id)
    ratio = usage / session.context_limit

    cond do
      ratio > @compact_threshold ->
        {:compact, create_handoff(session)}
      ratio > @evict_threshold ->
        {:evict, find_evictable_l1(session)}
      ratio > @compress_threshold ->
        {:compress, find_compressible_turns(session)}
      ratio > @warning_threshold ->
        {:warn, "Context usage at #{Float.round(ratio * 100, 1)}%"}
      true ->
        :ok
    end
  end
end
```

---

## Layer 2: Episodic Memory

Episodic memory records WHAT HAPPENED — sessions, conversations, events, decisions.
It is time-indexed and narrative in structure.

### What Gets Stored

```yaml
episodic_record:
  id: "ep_01HQ..."
  type: "memory.episodic"
  timestamp: "2026-03-19T14:30:00Z"
  agent_id: "strategist"
  session_id: "sess_01HQ..."

  event:
    type: "conversation"          # conversation | decision | observation | handoff
    participants: ["operator", "strategist"]
    summary: "Discussed AI Masters pricing. Operator wants $1.5K, partner wants $2K."
    key_moments:
      - turn: 5
        content: "Operator: 'The Wyatt/Carson principle says no decision barriers'"
      - turn: 12
        content: "Decision: narrow to $1.5K-$2K range, final decision by March 25"

  extracted:
    decisions: ["Pricing range narrowed to $1.5K-$2K"]
    action_items: ["Operator to call partner by March 25"]
    entities_mentioned: ["Ed Honour", "AI Masters", "Wyatt Carson"]
    sentiment: "collaborative"

  compression:
    original_tokens: 4500
    compressed_tokens: 800
    compression_ratio: 0.18
    full_transcript_ref: "store://sessions/sess_01HQ.json"
```

### Compression Pipeline

Raw sessions are too large to store at full fidelity. Episodic memory compresses:

```
Raw session (4500 tokens)
  │
  ▼
Stage 1: Extract key moments (turns with decisions, emotions, commitments)
  │  Output: ~30% of original
  ▼
Stage 2: Summarize non-key segments (compress filler into one-line summaries)
  │  Output: ~18% of original
  ▼
Stage 3: Structure into episodic record (YAML format above)
  │  Output: ~800 tokens
  ▼
Store compressed record + pointer to full transcript
```

```elixir
defmodule Memory.Episodic do
  def compress_session(session) do
    turns = Session.get_turns(session.id)

    key_moments = turns
      |> Enum.filter(&is_key_moment?/1)
      |> Enum.map(&extract_moment/1)

    summary = Summarizer.compress(turns, target: 200)

    extracted = %{
      decisions: Extractor.decisions(turns),
      action_items: Extractor.actions(turns),
      entities_mentioned: Extractor.entities(turns),
      sentiment: Analyzer.sentiment(turns)
    }

    %EpisodicRecord{
      session_id: session.id,
      agent_id: session.agent_id,
      summary: summary,
      key_moments: key_moments,
      extracted: extracted,
      compression_ratio: byte_size(summary) / Session.token_count(session.id)
    }
  end

  defp is_key_moment?(turn) do
    has_decision?(turn) or has_commitment?(turn) or
    has_strong_emotion?(turn) or has_new_entity?(turn)
  end
end
```

### Retrieval Patterns

Episodic memory is retrieved by time, entity, or narrative thread:

```elixir
# "What happened with Ed last week?"
Memory.Episodic.query(
  entity: "Ed Honour",
  after: ~U[2026-03-12 00:00:00Z],
  limit: 5
)

# "What decisions did we make about pricing?"
Memory.Episodic.query(
  topic: "pricing",
  event_type: :decision,
  limit: 10
)

# "Show me all sessions where the operator was frustrated"
Memory.Episodic.query(
  sentiment: "frustrated",
  participant: "operator",
  limit: 5
)
```

---

## Layer 3: Semantic Memory

Semantic memory stores FACTS — extracted, verified, and queryable. Unlike episodic
memory (which records events), semantic memory records knowledge.

### What Gets Stored

```yaml
semantic_record:
  id: "sem_01HQ..."
  type: "memory.semantic"

  fact:
    statement: "Ed Honour wants $2K per seat for AI Masters advanced course"
    confidence: 0.90
    source: "ep_01HQ..."          # Episodic record this was extracted from
    first_seen: "2026-03-15"
    last_confirmed: "2026-03-18"
    times_confirmed: 3

  entity:
    primary: "Ed Honour"
    related: ["AI Masters", "pricing"]
    node: "04-ai-masters"

  status: "active"                 # active | superseded | disputed | archived
  superseded_by: null              # If superseded, pointer to replacement fact
```

### Fact Lifecycle

```
New fact extracted from episodic memory
  │
  ▼
Check for existing semantic records on same topic
  │
  ├── No existing → Create new record (confidence: 0.6)
  │
  ├── Confirms existing → Increment times_confirmed, boost confidence
  │
  ├── Contradicts existing → Create dispute record
  │     ├── Both facts get status: "disputed"
  │     ├── Log conflict for human resolution
  │     └── Proactive agent (Knowledge Guardian) monitors disputes
  │
  └── Supersedes existing → New record active, old record superseded
```

### Conflict Resolution

```elixir
defmodule Memory.Semantic.ConflictResolver do
  def resolve(existing, new_fact) do
    cond do
      confirms?(existing, new_fact) ->
        {:confirm, boost_confidence(existing)}

      contradicts?(existing, new_fact) ->
        {:dispute, create_dispute(existing, new_fact)}

      supersedes?(existing, new_fact) ->
        {:supersede, %{
          new: %{new_fact | status: :active},
          old: %{existing | status: :superseded, superseded_by: new_fact.id}
        }}

      true ->
        {:coexist, new_fact}  # Different enough to be separate facts
    end
  end

  defp contradicts?(a, b) do
    same_entity?(a, b) and same_attribute?(a, b) and different_value?(a, b)
  end
end
```

### Entity Graph

Semantic memory maintains an entity relationship graph:

```
Ed Honour ──[partner_of]──→ AI Masters
Ed Honour ──[proposes]──→ $2K pricing
Operator ──[counters]──→ $1.5K pricing
AI Masters ──[has_product]──→ Advanced Course
Advanced Course ──[price_range]──→ $1.5K-$2K
```

Entities are nodes. Relations are typed edges. The graph enables:
- "What do we know about Ed?" → traverse all edges from Ed node
- "What's connected to pricing?" → find all entities linked to pricing
- "Are there unconnected entities that should be linked?" → graph analysis

---

## Layer 4: Procedural Memory

Procedural memory stores HOW TO DO THINGS — learned patterns, preferences,
heuristics, and skills. It activates automatically when trigger conditions match.

### What Gets Stored

```yaml
procedural_record:
  id: "proc_01HQ..."
  type: "memory.procedural"

  pattern:
    trigger: "the operator asks about pricing for any product"
    action: |
      1. Search semantic memory for current pricing facts
      2. Load L1 for the relevant product node
      3. Check 11-money-revenue for revenue targets
      4. Present options with Signal Theory genre: brief
    confidence: 0.85
    times_applied: 12
    success_rate: 0.92

  source: "Learned from 12 pricing conversations, Feb-Mar 2026"
  category: "communication"        # communication | workflow | technical | domain
  scope: "global"                  # global | node-specific | agent-specific
```

### Learning Pipeline

Procedural memories are extracted from patterns across multiple episodic records:

```
Episodic memory accumulates similar events
  │
  ▼
Pattern detector identifies recurring sequence
  (e.g., "Every time the operator asks about pricing, the successful
   interactions followed steps 1-2-3")
  │
  ▼
Candidate procedural memory created (confidence: 0.5)
  │
  ▼
Next occurrence → pattern applied → outcome measured
  │
  ├── Success → confidence += 0.1, success_rate updated
  │
  └── Failure → confidence -= 0.15, pattern revised or archived
  │
  ▼
Confidence > 0.8 → pattern promoted to active procedural memory
```

```elixir
defmodule Memory.Procedural do
  @promotion_threshold 0.8
  @demotion_threshold 0.3
  @min_applications 5

  def evaluate(pattern, outcome) do
    updated = %{pattern |
      times_applied: pattern.times_applied + 1,
      success_rate: update_rate(pattern, outcome),
      confidence: adjust_confidence(pattern, outcome)
    }

    cond do
      updated.confidence < @demotion_threshold ->
        {:archive, updated}
      updated.confidence >= @promotion_threshold and updated.times_applied >= @min_applications ->
        {:promote, updated}
      true ->
        {:update, updated}
    end
  end
end
```

### Trigger Matching

When an agent receives input, procedural memory is checked for matching triggers:

```
User input arrives
  │
  ▼
Extract intent + entities from input
  │
  ▼
Query procedural memory for matching triggers
  │
  ├── Match found (confidence > threshold)
  │   └── Inject procedure into working memory as suggested approach
  │
  └── No match → agent uses default reasoning
```

Procedural memory is ADVISORY, not mandatory. The agent sees the suggested procedure
but can override it if the situation differs from the pattern.

---

## Cross-Layer Interactions

### Episodic → Semantic (Fact Extraction)

After every session, the episodic compression pipeline feeds extracted facts
into semantic memory:

```
Session ends
  ↓
Episodic record created (compressed session)
  ↓
Fact extractor pulls: decisions, entities, relationships, numbers
  ↓
Each fact checked against semantic memory (confirm/contradict/new)
  ↓
Semantic memory updated
```

### Semantic → Procedural (Pattern Detection)

When enough semantic facts accumulate around a topic, pattern detection looks
for procedural knowledge:

```
Semantic facts accumulate
  ↓
Pattern detector runs (weekly, or on threshold)
  ↓
Detects: "Every time entity X is involved with topic Y, outcome Z follows"
  ↓
Creates candidate procedural memory
  ↓
Validated over next N occurrences
```

### Procedural → Working (Runtime Injection)

Active procedural memories inject into working memory at task start:

```
Task assigned to agent
  ↓
Match task against procedural triggers
  ↓
Matching procedures loaded into working memory
  ↓
Agent sees: "Based on past interactions, the recommended approach is..."
```

### Working → Episodic (Session Capture)

At session end, working memory flows to episodic storage:

```
Session ends (or compacts)
  ↓
Working memory snapshot taken
  ↓
Compressed into episodic record
  ↓
Original session archived to cold storage
```

---

## Memory Budget

Memory operations cost tokens. Budget enforcement prevents runaway memory costs:

```yaml
memory_budget:
  episodic:
    compression_cost: 500          # tokens to compress a session
    max_records_per_day: 50        # prevent event storms
    retention_days: 90             # archive after 90 days

  semantic:
    extraction_cost: 200           # tokens per fact extraction
    max_facts: 10000               # total semantic records
    conflict_resolution_cost: 300  # tokens per conflict check

  procedural:
    pattern_detection_cost: 1000   # tokens per detection run
    max_patterns: 500              # total procedural records
    detection_frequency: "weekly"  # how often to run detection

  total_monthly_budget: 50.00      # USD cap for all memory operations
```

---

## Storage Implementation

### Recommended Stack

```
┌──────────────────┐
│  Working Memory   │ → LLM context window (no external storage)
├──────────────────┤
│  Episodic Memory  │ → SQLite table + compressed JSON
│                   │   Full transcripts → cold storage (S3/filesystem)
├──────────────────┤
│  Semantic Memory  │ → SQLite with FTS5 + entity graph table
│                   │   Vector embeddings for semantic search (optional)
├──────────────────┤
│  Procedural Memory│ → YAML files in workspace (version controlled)
│                   │   Indexed in SQLite for trigger matching
└──────────────────┘
```

### Schema (SQLite Reference)

```sql
-- Episodic memory
CREATE TABLE episodic_records (
  id TEXT PRIMARY KEY,
  agent_id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  event_type TEXT NOT NULL,
  summary TEXT NOT NULL,
  key_moments TEXT,              -- JSON array
  extracted TEXT,                 -- JSON object
  compression_ratio REAL,
  full_transcript_ref TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_episodic_time ON episodic_records(timestamp);
CREATE INDEX idx_episodic_agent ON episodic_records(agent_id);

-- Semantic memory
CREATE TABLE semantic_records (
  id TEXT PRIMARY KEY,
  statement TEXT NOT NULL,
  confidence REAL NOT NULL,
  source_episodic_id TEXT,
  primary_entity TEXT,
  related_entities TEXT,         -- JSON array
  node TEXT,
  status TEXT DEFAULT 'active',
  superseded_by TEXT,
  times_confirmed INTEGER DEFAULT 1,
  first_seen TEXT,
  last_confirmed TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE VIRTUAL TABLE semantic_fts USING fts5(statement, primary_entity);
CREATE INDEX idx_semantic_entity ON semantic_records(primary_entity);
CREATE INDEX idx_semantic_status ON semantic_records(status);

-- Entity graph
CREATE TABLE entity_edges (
  source_entity TEXT NOT NULL,
  target_entity TEXT NOT NULL,
  relation_type TEXT NOT NULL,
  weight REAL DEFAULT 1.0,
  source_record TEXT,           -- semantic record that established this edge
  created_at TEXT DEFAULT (datetime('now')),
  PRIMARY KEY (source_entity, target_entity, relation_type)
);
```

---

## Relationship to Other Architecture Files

| File | How It Relates |
|------|---------------|
| `basement.md` | Memory types defined in Basement taxonomy |
| `tiered-loading.md` | Working memory populated via L0/L1/L2 loading |
| `proactive-agents.md` | Knowledge Guardian maintains memory quality |
| `heartbeat.md` | Session end triggers episodic compression |
| `sessions.md` | Session state = working memory serialization |
| `signal-integration.md` | Fact extraction uses Signal classification |
| `context-mesh.md` | Complement to individual memory: the Context Mesh holds shared in-flight team context (decisions made, files changed, open questions) that persists across agent run boundaries — distinct from per-agent episodic/semantic memory |

---

*Memory Architecture v1.0 — Cognitive memory system for OSA Operations*
