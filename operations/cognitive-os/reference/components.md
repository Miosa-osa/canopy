# OptimalOS Components

> Quick-reference: what module do I use for X?
> Every engine module — role, public API, process type, dependencies.

---

## Decision Table

| I need to... | Use |
|---|---|
| Store or retrieve a context | `Store` |
| Search across all content | `SearchEngine.search/2` |
| Ingest raw text as a signal | `Intake.process/2` |
| Build tiered context for a topic | `ContextAssembler.assemble/2` |
| Get the always-loaded L0 inventory | `L0Cache.get/0` |
| Route a signal to nodes | `Router.route/1` |
| Classify S=(M,G,T,F,W) dimensions | `Classifier` (stateless) |
| Address content by URI | `URI` (stateless) |
| Crawl and index the filesystem | `Indexer.full_index/0` |
| Find synthesis opportunities | `GraphAnalyzer.triangles/1` |
| Find missing graph edges | `Reflector.reflect/1` |
| Run a "what if" scenario | `Simulator.simulate/2` |
| Plan optimal response to a scenario | `MCTS.plan_response/2` |
| Estimate impact probabilities | `MonteCarlo.sample/2` |
| Generate LLM summaries + embeddings | `SemanticProcessor.process/1` |
| Store/search vector embeddings | `VectorStore` (stateless) |
| Call Ollama (LLM or embed) | `Ollama` (stateless) |
| Record a friction observation | `RememberLoop.remember/2` |
| Synthesize accumulated evidence | `RethinkEngine.rethink/2` |
| Run knowledge base health checks | `HealthDiagnostics.run/0` |
| Find stale contexts on a topic | `Reweaver.reweave/2` |
| Score L0 abstract fidelity | `VerifyEngine.verify/1` |
| Re-encode a signal for a receiver | `Composer.render_for/3` |
| Feed recent data to Cortex | `CortexFeed.recall/0` |
| Extract memories from a session | `MemoryExtractor.extract/1` |
| Compress a session transcript | `SessionCompressor.compress/2` |
| Query the knowledge graph | `Bridge.Knowledge` (stateless) |
| Record episodic events | `Bridge.Memory.record_event/3` |
| Audit signal theory violations | `Bridge.Signal.audit/1` |

---

## Layer 0 — Data

### Store

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/store.ex` |
| **Type** | GenServer (supervised, started first) |
| **What** | Owns the SQLite connection and an ETS hot cache. All data goes through here. Cache entries are LRU-evicted at 500-entry watermark. |

**Tables**

| Table | Purpose |
|---|---|
| `contexts` | Universal context table. All types stored here. |
| `signals` | VIEW over `contexts WHERE type = 'signal'`. Backward compat. |
| `contexts_fts` | FTS5 virtual table (title + content). Powers BM25 search. |
| `entities` | Named entities extracted from contexts. |
| `edges` | Typed directed graph edges between contexts, entities, and nodes. |
| `decisions` | Decision log entries with rationale. |
| `sessions` | Session tracking (ephemeral). |
| `vectors` | Embeddings as little-endian float32 BLOBs (768 dims). |
| `observations` | Friction observations from RememberLoop. |

**Public API**

```elixir
Store.insert_context(%Context{})           # {:ok} | {:error, reason}
Store.insert_contexts([%Context{}])        # {:ok, count} | {:error, reason}
Store.get_context(id)                      # {:ok, %Context{}} | {:error, :not_found}
Store.get_by_node(node, opts)              # {:ok, [%Context{}]} | {:error, reason}
Store.delete_context(id)                   # :ok | {:error, reason}
Store.stats()                              # {:ok, map()} | {:error, reason}
Store.raw_query(sql, params)               # {:ok, [[term()]]} | {:error, reason}

# Backward compat (signal wrappers)
Store.insert_signal(%Signal{})
Store.get_signal(id)
Store.delete_signal(id)
```

**Dependencies:** `Exqlite`, `Context`, `Graph`, `Signal`

---

### VectorStore

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/vector_store.ex` |
| **Type** | Stateless module |
| **What** | Stores and searches 768-dim embeddings in the `vectors` SQLite table via cosine similarity. Suitable up to ~50K vectors; no native extension required. |

**Public API**

```elixir
VectorStore.store(context_id, embedding)   # :ok | {:error, reason}
VectorStore.search(query_embedding, opts)  # {:ok, [{context_id, score}]} | {:error, reason}
  # opts: :limit, :min_similarity, :type_filter, :node_filter
```

**Dependencies:** `Store`

---

### L0Cache

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/l0_cache.ex` |
| **Type** | GenServer (supervised) |
| **What** | Builds and caches the always-loaded L0 structural inventory: node map, skill list, resource index, memory summary, system state. Auto-refreshes every 30 minutes. Max 12,000 characters. |

**Public API**

```elixir
L0Cache.get()      # String.t() — current L0 inventory string
L0Cache.refresh()  # :ok — force immediate refresh (cast)
```

**Dependencies:** `Store`, `Bridge.Memory`

---

## Layer 1 — Classification

### Classifier

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/classifier.ex` |
| **Type** | Stateless module |
| **What** | Detects context type (`:signal`, `:resource`, `:memory`, `:skill`). For signals: classifies S=(M,G,T,F,W) via YAML frontmatter parsing with regex fallback. Extracts entities from content using topology's known-people list. |

**Genre patterns detected** (ordered by specificity): `invoice`, `profit-loss`, `budget`, `decision-log`, `adr`, `spec`, `runbook`, `postmortem`, `standup`, `transcript`, `plan`, `brief`, `proposal`, `pitch`, `changelog`, `readme`, `note`

**Public API** (all pure functions, no process state)

```elixir
Classifier.classify_file(path, content, opts)  # {:ok, %Context{}} | {:error, reason}
Classifier.classify_text(text, opts)           # {:ok, %Context{}} | {:error, reason}
```

**Dependencies:** `Context`, `Signal`, `Topology`

---

### Bridge.Signal

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/bridge/signal.ex` |
| **Type** | Stateless module |
| **What** | Bridge to `SignalBridge`. Augments classification with SignalBridge's inference, audits Signal Theory constraint violations (Shannon, Ashby, Beer, Wiener), measures S/N ratio, wraps signals as CloudEvents v1.0.2 envelopes. |

**Public API**

```elixir
Bridge.Signal.enhance_classification(signal, raw_text)  # %OptSignal{}
Bridge.Signal.audit(signal)                             # [{atom(), String.t()}]
Bridge.Signal.measure_sn(signal)                        # float()
Bridge.Signal.to_cloud_event(signal)                    # map()
```

**Dependencies:** `SignalBridge`, `OptimalEngine.Signal`

---

## Layer 2 — Routing

### Router

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/router.ex` |
| **Type** | GenServer (supervised) |
| **What** | Routes signals to destination node IDs using topology rules. All matching rules fire (not first-match). Priority levels: `:critical` > `:high` > `:normal` > `:low`. Cross-cutting rules: financial genres always copy to `money-revenue`; signals mentioning known people copy to `team`. Fallback: `["inbox"]`. |

**Public API**

```elixir
Router.route(%Signal{})  # {:ok, [node_id]} | {:error, reason}
Router.reload()          # :ok — reload rules from topology files
```

**Dependencies:** `Signal`, `Topology`

---

### Topology

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/topology.ex` |
| **Type** | Stateless module |
| **What** | Loads `.system/config.yaml` and `topology.yaml`. Provides node config, genre half-lives, routing rules, and endpoint (person) definitions with genre competence lists. Stateless — call `load/0` at startup and pass the result around. |

**Public API**

```elixir
Topology.load()                             # {:ok, t()} | {:error, reason}
Topology.half_life_for(topology, genre)     # non_neg_integer() (hours)
Topology.nodes(topology)                    # %{node_id => node_entry()}
Topology.primary_genre_for(topology, id)    # String.t() | nil
Topology.endpoint_for(topology, id)         # endpoint() | nil
```

---

### URI

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/uri.ex` |
| **Type** | Stateless module |
| **What** | `optimal://` URI scheme. Addressable namespaces: `resources/`, `user/memories/`, `agent/memories/`, `agent/skills/`, `nodes/{id}/`, `sessions/{id}/`, `inbox/`. |

**Public API**

```elixir
URI.parse("optimal://nodes/ai-masters/signals/foo.md")
  # %{namespace: :nodes, segments: [...], raw: "..."}
URI.from_path(absolute_path)   # "optimal://..." | nil
URI.resolve(uri_string)        # absolute_path | nil
URI.namespace(uri_string)      # atom()
URI.ls(uri_prefix)             # {:ok, [%Context{}]} | {:error, reason}
```

---

## Layer 3 — Search and Retrieval

### SearchEngine

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/search_engine.ex` |
| **Type** | GenServer (supervised) |
| **What** | Hybrid search combining SQLite FTS5 BM25 + vector cosine similarity + RRF fusion + temporal decay + S/N boost + knowledge graph boost. Returns `%Context{}` with `:score` set. |

**Scoring formula:** `final_score = bm25_score × temporal_factor × sn_ratio_boost × graph_boost`

**Public API**

```elixir
SearchEngine.search(query, opts)              # {:ok, [%Context{}]} | {:error, reason}
SearchEngine.search_node(node, query, opts)   # {:ok, [%Context{}]} | {:error, reason}
  # opts: :type, :node, :genre, :uri, :limit, :offset, :min_score
```

**Dependencies:** `Store`, `VectorStore`, `Topology`, `IntentAnalyzer`, `Ollama`, `Bridge.Knowledge`, `Bridge.Memory`

---

### ContextAssembler

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/context_assembler.ex` |
| **Type** | Stateless module |
| **What** | Builds tiered context bundles for a query. L0 = structural inventory (~3K tokens), L1 = relevant file summaries (~10K tokens), L2 = full content for top results (~50K tokens). Returns token counts and source list. |

**Public API**

```elixir
ContextAssembler.assemble(query, opts)
  # {:ok, %{l0: str, l1: str, l2: str, total_tokens: int, sources: [...], search_scores: [...]}}
ContextAssembler.l0()            # {:ok, String.t()}
ContextAssembler.l1(query)       # {:ok, String.t()}
```

**Dependencies:** `L0Cache`, `SearchEngine`, `Store`, `Bridge.Knowledge`

---

### IntentAnalyzer

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/intent_analyzer.ex` |
| **Type** | Stateless module |
| **What** | Analyzes a search query to extract intent type, expand query terms, identify likely nodes, and detect temporal hints. LLM-enhanced when Ollama is available; regex heuristic fallback. Always returns `{:ok, map()}`. |

**Intent types:** `:lookup`, `:comparison`, `:temporal`, `:decision`, `:exploration`

**Public API**

```elixir
IntentAnalyzer.analyze(query)
  # {:ok, %{
  #   expanded_query: str,
  #   intent_type: atom,
  #   key_entities: [str],
  #   temporal_hint: :recent | :historical | :any,
  #   node_hints: [str]
  # }}
```

**Dependencies:** `Ollama`

---

## Layer 4 — Knowledge Graph

### Graph

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/graph.ex` |
| **Type** | Stateless module |
| **What** | Manages edges in the `edges` SQLite table. Typed directed graph — entities, contexts, and nodes all coexist as endpoints. No FK constraints (mixed endpoint types). |

**Edge types**

| Relation | Meaning |
|---|---|
| `mentioned_in` | entity → context |
| `lives_in` | context → node |
| `cross_ref` | context → context (secondary routing) |
| `works_on` | entity → node (from topology) |
| `supersedes` | context → context |

**Public API**

```elixir
Graph.create_edges_for_context(context)           # :ok
Graph.create_edges_for_context_db(db, context)    # :ok (in-process, no GenServer hop)
Graph.edges_for(id, opts)                         # {:ok, [edge_map()]} | {:error, reason}
Graph.stats()                                     # {:ok, map()} | {:error, reason}
Graph.top_entities(limit)                         # {:ok, [map()]} | {:error, reason}
Graph.sample_edges(limit)                         # {:ok, [map()]} | {:error, reason}
```

**Dependencies:** `Store`

---

### Bridge.Knowledge

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/bridge/knowledge.ex` |
| **Type** | Stateless module |
| **What** | Queries SQLite `edges` directly for graph-based score boosting. No GenServer hop. Also provides on-demand OWL 2 RL reasoning via `KnowledgeBridge` (only when explicitly requested). |

**Public API**

```elixir
Bridge.Knowledge.graph_boost(results, query)  # [map()] — results with boosted scores
Bridge.Knowledge.context_for(topic)           # String.t() — markdown context
Bridge.Knowledge.materialize()                # {:ok, inferred_count} | {:error, reason}
```

**Dependencies:** `Store`, `KnowledgeBridge`

---

### GraphAnalyzer

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/graph_analyzer.ex` |
| **Type** | Stateless module |
| **What** | Three graph analyses over the `edges` table. LLM-enhanced when Ollama is available; degrades gracefully. Always returns `{:ok, result}`. |

**Public API**

```elixir
GraphAnalyzer.triangles(opts)   # {:ok, [%{a: id, b: id, c: id, suggestion: str|nil}]}
  # Open triangles: A→B, A→C exist but B→C missing. Synthesis opportunities.
  # opts: :limit (default 20)

GraphAnalyzer.clusters()        # {:ok, [%{entities: [...], size: int}]}
  # BFS connected components on the undirected edge graph. Isolated islands.

GraphAnalyzer.hubs()            # {:ok, [%{entity: str, degree: int}]}
  # Entities with degree > 2σ above mean. Highly connected nodes.
```

**Dependencies:** `Store`, `Ollama`

---

### Reflector

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/reflector.ex` |
| **Type** | Stateless module |
| **What** | Finds entity pairs that co-occur in multiple contexts but have no direct edge. Suggests relationship type via LLM or heuristic. Never raises. |

**Public API**

```elixir
Reflector.reflect(opts)
  # {:ok, [%{source: str, target: str, cooccurrences: int, confidence: float,
  #           suggested_relation: str, reason: str}]}
  # opts: :min_cooccurrences (default 2), :limit (default 20)

Reflector.shared_contexts(entity_a, entity_b)
  # {:ok, [context_id]} — contexts where both appear
```

**Dependencies:** `Store`, `Ollama`

---

## Layer 5 — Intelligence

### Simulator

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/simulator.ex` |
| **Type** | GenServer (supervised) |
| **What** | Scenario planning engine. Traces "what if" mutations (entity removal, node cancellation, revenue change) through the knowledge graph via weighted BFS (depth 3). Returns structured impact report with affected entities, affected nodes, critical dependencies, risk assessment, and recommendations. |

**Edge weights:** `works_on` (1.5) > `cross_ref` (1.2) > `mentioned_in` (1.0) > `lives_in` (0.6) > `supersedes` (0.4)

**Public API**

```elixir
Simulator.simulate(scenario, opts)            # {:ok, report()} | {:error, reason}
  # opts: :max_depth (default 3)
  # e.g. "What if Ed leaves AI Masters?"

Simulator.impact_analysis(entity_or_node, opts)   # {:ok, impact()} | {:error, reason}
  # e.g. "Bennett", "agency-accelerants"
```

**Mutation types:** `:entity_removal`, `:node_cancellation`, `:revenue_change`, `:dependency_break`, `:general`

**Dependencies:** `Store`, `Ollama`

---

### MCTS

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/mcts.ex` |
| **Type** | Stateless module |
| **What** | Monte Carlo Tree Search over simulation impact reports. Explores action sequences (reassign, hire, restructure, pause, pivot, redistribute) using UCB1 to find the optimal recovery strategy. |

**Public API**

```elixir
MCTS.plan_response(impact_report, opts)
  # {:ok, plan()} | {:error, reason}
  # opts: :budget (simulation count, default 32)
  # Returns: best_sequence, explored_paths, confidence, expected_outcome, alternatives, tree_stats
```

**Dependencies:** `Simulator` (for input), no runtime process dependencies

---

### MonteCarlo

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/monte_carlo.ex` |
| **Type** | Stateless module |
| **What** | Probability estimation over simulation reports. Samples N outcomes by flip-coining each affected edge. Returns impact distributions per node with percentile breakdowns. |

**Public API**

```elixir
MonteCarlo.sample(simulation_report, opts)
  # {:ok, distribution()} | {:error, reason}
  # opts: :simulations (default 1000)
  # Returns: simulations, outcomes (best/worst/expected/median),
  #          node_distributions (p10/p50/p90), confidence_interval_95, histogram
```

**Dependencies:** `Store`

---

### SemanticProcessor

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/semantic_processor.ex` |
| **Type** | Stateless module |
| **What** | LLM-powered enrichment pipeline: generates L0 abstract (≤200 chars), L1 overview (≤1500 chars), computes and stores embedding. Writes `.abstract.md` and `.overview.md` sidecar files. Silent no-op when Ollama is unavailable — never blocks the indexing pipeline. |

**Public API**

```elixir
SemanticProcessor.process(%Context{})   # {:ok, %Context{}} — always succeeds
```

**Dependencies:** `Context`, `Ollama`, `VectorStore`

---

## Layer 6 — Processing Pipeline

### Intake

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/intake.ex` |
| **Type** | GenServer (supervised) |
| **What** | Full signal ingestion pipeline: classify → route → write files → cross-reference → index → episodic record. Non-critical steps (episodic recording, SICA observation) run async. Enforces Signal Theory quality gates (S/N < 0.3 → reject, S/N < 0.6 + routing failure → quarantine). |

**Quality actions:** `:accepted`, `:quarantined`, `:rejected`

**Public API**

```elixir
Intake.process(raw_text, opts)
  # {:ok, result()} | {:error, reason}
  # opts: :genre, :node, :title, :entities, :type
  # result: %{signal, context, files_written, routed_to, cross_references,
  #           uri, quality_violations, quality_action}
```

**Dependencies:** `Classifier`, `Router`, `Intake.Writer`, `SemanticProcessor`, `Store`, `Indexer`, `Bridge.Memory`, `Bridge.Signal`

---

### Indexer

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/indexer.ex` |
| **Type** | GenServer (supervised) |
| **What** | Crawls the OptimalOS directory tree, classifies content by file type and path, and upserts Contexts into SQLite. Long-running index runs execute in a linked Task. Skips `.git`, `node_modules`, `engine/`, `tasks/`, hidden dirs. |

**File type classification**

| Files | Context type |
|---|---|
| `.md` in numbered folders | `:signal` |
| `.md` in `docs/` | `:resource` |
| Source code, config, data | `:resource` |
| `_memories/` subtree | `:memory` |
| `_skills/` subtree | `:skill` |
| Binary files | `:resource` (metadata only, no content read) |

**Public API**

```elixir
Indexer.full_index()           # {:ok, :started} | {:error, :already_running}
Indexer.index_file(path)       # {:ok, %Context{}} | {:error, reason}
Indexer.status()               # map()
```

**Dependencies:** `Classifier`, `Router`, `SemanticProcessor`, `Store`, `Topology`, `URI`, `Bridge.Knowledge`, `Bridge.Memory`

---

### MemoryExtractor

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/memory_extractor.ex` |
| **Type** | Stateless module |
| **What** | Extracts structured memories from session transcripts. Six categories: `:fact`, `:preference`, `:decision`, `:relationship`, `:skill`, `:context`. LLM path when Ollama is available; regex fallback otherwise. Filters below 0.7 confidence. Caps at 20 memories per call. |

**Public API**

```elixir
MemoryExtractor.extract(session_text)
  # {:ok, [%{category: atom, content: str, confidence: float, entities: [str]}]}
```

**Dependencies:** `Ollama`, `Topology`

---

### SessionCompressor

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/session_compressor.ex` |
| **Type** | Stateless module |
| **What** | Compresses session transcripts preserving maximum signal. Only compresses when content exceeds 10,000 characters (or `:force` is set). LLM path via Ollama; regex fallback keeps high-signal lines (decided, action, $, deal, close, etc.) and truncates to head+tail. |

**Public API**

```elixir
SessionCompressor.compress(text, opts)   # {:ok, compressed_text}
  # opts: :force (default false)
```

**Dependencies:** `Ollama`

---

## Layer 7 — Agent Interface

### Composer

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/composer.ex` |
| **Type** | Stateless module |
| **What** | Re-encodes a Signal for a specific receiver. Looks up the receiver's genre competence from topology and reformats content accordingly. Implements Signal Theory "path of least resistance." |

**Genre reformatting rules**

| Genre | Structure applied |
|---|---|
| `brief` | Objective + Key Messages (3-5 bullets) + Call to Action |
| `spec` | Goal + Requirements + Constraints + Acceptance Criteria |
| `runbook` | Procedure + Steps (numbered) |
| `note` | Raw content with header |
| other | Pass-through with genre header |

**Public API**

```elixir
Composer.render_for(%Signal{}, receiver_id, topology)
  # {:ok, rendered_string} | {:error, :unknown_receiver}

Composer.optimal_genre(%Signal{}, receiver_id, topology)
  # String.t() — the best genre for this receiver
```

**Dependencies:** `Signal`, `Topology`

---

### CortexFeed

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/cortex_feed.ex` |
| **Type** | Stateless module |
| **What** | Feeds `MemoryBridge.Cortex` with live engine data. Queries SQLite directly for recent signals (last 7 days), recent decisions, and active operations. Returns formatted markdown string. |

**Public API**

```elixir
CortexFeed.recall()           # String.t() — recent signals + decisions + active ops
CortexFeed.session_context()  # String.t() — active sessions
```

**Dependencies:** `Store`

---

## Layer 8 — Learning and Feedback

### Bridge.Memory

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/bridge/memory.ex` |
| **Type** | Stateless module |
| **What** | Unified bridge to `MemoryBridge` (Episodic, SICA Learning, Cortex, Injector). All calls are fire-and-forget-safe — rescue guards ensure no errors propagate back to the engine. |

**Public API**

```elixir
Bridge.Memory.record_event(event_type, data, session_id)
  # :ok — event_types: :intake, :search, :mutation, :decision, :error, :tool_call
Bridge.Memory.recall_events(query, opts)          # [map()]
Bridge.Memory.observe_mutation(interaction_map)   # :ok
Bridge.Memory.record_correction(expected, actual) # :ok
Bridge.Memory.record_error(type, msg, context)    # :ok
Bridge.Memory.bulletin()                          # String.t() — Cortex synthesis
Bridge.Memory.inject_context(query, session_id)   # String.t() — relevant memories
Bridge.Memory.learning_metrics()                  # map()
```

**Dependencies:** `MemoryBridge.Episodic`, `MemoryBridge.Cortex`, `MemoryBridge.Learning`

---

### RememberLoop

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/remember_loop.ex` |
| **Type** | Stateless module |
| **What** | Three-mode friction capture. Observations accumulate in the `observations` table. When 3+ observations share a category the category is flagged for escalation to `RethinkEngine`. |

**Observation categories:** `process`, `people`, `tool`, `decision`, `pattern`, `friction`

**Public API**

```elixir
# Mode 1: explicit observation
RememberLoop.remember(text, opts)
  # {:ok, %{category, content, confidence, source, escalation}} | {:error, reason}
  # opts: :category, :confidence, :source

# Mode 2: scan recent sessions for correction signals
RememberLoop.contextual_scan(opts)     # {:ok, [map()]}

# Mode 3: bulk extract from session transcripts
RememberLoop.mine_sessions(opts)       # {:ok, [map()]}

# Query stored observations
RememberLoop.list(opts)                # {:ok, [map()]}
RememberLoop.escalations()             # {:ok, [%{category, count, total_confidence}]}
```

**Dependencies:** `Store`, `MemoryExtractor`, `Ollama`

---

### RethinkEngine

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/rethink_engine.ex` |
| **Type** | Stateless module |
| **What** | Evidence synthesis. When cumulative observation confidence for a topic reaches ≥ 1.5, gathers observations + search results + graph context and generates a structured rethink report with proposed `context.md` updates. Never auto-applies changes. |

**Return status values:** `:insufficient_evidence`, `:synthesized`, `:error`

**Public API**

```elixir
RethinkEngine.rethink(topic, opts)
  # {:ok, %{topic, status, total_confidence, threshold, ...}}
  # opts: :force (bypass threshold), :auto_apply (default false)
```

**Dependencies:** `Store`, `Ollama`

---

## Layer 9 — Operating System

### HealthDiagnostics

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/health_diagnostics.ex` |
| **Type** | Stateless module |
| **What** | 10 diagnostic checks against the SQLite store. All checks are caught individually — a failing check returns a `:warning` result rather than crashing. |

**Checks run**

| Check | What it looks for |
|---|---|
| `orphaned_contexts` | Contexts with no edges |
| `stale_signals` | Signals not modified in 30+ days |
| `missing_cross_refs` | Routes in `routed_to` without a corresponding `cross_ref` edge |
| `fts_drift` | FTS5 row count vs contexts row count mismatch |
| `entity_merge_candidates` | Near-duplicate entity names |
| `node_imbalance` | Nodes with 3× more contexts than the median |
| `duplicate_detection` | Contexts with identical titles |
| `broken_references` | `supersedes` pointers to non-existent contexts |
| `embedding_coverage` | Contexts without a vector embedding |
| `quality_distribution` | More than 20% of contexts below S/N 0.4 |

**Severity levels:** `:ok`, `:warning`, `:critical`

**Public API**

```elixir
HealthDiagnostics.run()            # {:ok, [check_result_map()]}
HealthDiagnostics.summary(results) # %{ok: int, warning: int, critical: int, total: int}
```

**Dependencies:** `Store`

---

### Reweaver

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/reweaver.ex` |
| **Type** | Stateless module |
| **What** | Backward pass: finds contexts related to a topic that may be outdated. Combines FTS search + graph entity matching, scores staleness (0.0 fresh → 1.0 stale), and generates update suggestions via LLM or rule-based flagging. |

**Public API**

```elixir
Reweaver.reweave(topic, opts)
  # {:ok, [%{context_id, title, node, staleness, days_old, suggestion, type}]}
  # type: :llm_suggestion | :flag
  # opts: :max_results (default 10), :staleness_days (default 30)
```

**Dependencies:** `Store`, `Graph`, `Ollama`

---

### VerifyEngine

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/verify_engine.ex` |
| **Type** | Stateless module |
| **What** | Cold-read L0 fidelity test. Samples contexts, takes only title + L0 abstract, and scores how well the L0 represents the full content. LLM prediction scoring when Ollama is available; Jaccard similarity fallback. |

**Grades:** based on aggregate fidelity score (0.0–1.0)

**Public API**

```elixir
VerifyEngine.verify(opts)
  # {:ok, %{scores: [score_map()], aggregate: float, sample_size: int, message: str}}
  # opts: :sample (default 10), :node (filter to one node)
```

**Dependencies:** `Store`, `Ollama`

---

## OTP Supervision Tree

Strategy: `:one_for_one` — each process is independent.

```
OptimalEngine.Supervisor
├── [1] Store              — SQLite + ETS. Must start first.
├── [2] Router             — Routing rules loader.
├── [3] Indexer            — File crawler (long runs in linked Task).
├── [4] SearchEngine       — Query executor.
├── [5] L0Cache            — Always-loaded context generator.
├── [6] Intake             — Signal ingestion pipeline.
├── [7] Simulator          — Scenario planning engine.
├── [8] SessionRegistry    — Registry for active sessions (unique name lookup).
├── [9] SessionSupervisor  — DynamicSupervisor for per-session GenServers.
│                             Sessions use :temporary restart (ephemeral state).
├── [10] MemoryBridge.Episodic
├── [11] MemoryBridge.Cortex
└── [12] MemoryBridge.Learning

Stateless modules (no supervision entry):
  Classifier, URI, Topology, Graph, GraphAnalyzer, Reflector,
  VectorStore, SemanticProcessor, MemoryExtractor, SessionCompressor,
  Composer, CortexFeed, Bridge.Signal, Bridge.Knowledge, Bridge.Memory,
  RememberLoop, RethinkEngine, HealthDiagnostics, Reweaver, VerifyEngine,
  MCTS, MonteCarlo, Ollama
```

---

## Ollama Integration

| | |
|---|---|
| **File** | `engine/lib/optimal_engine/ollama.ex` |
| **Type** | Stateless module (HTTP wrapper via `:httpc`) |
| **What** | Thin wrapper around the local Ollama daemon. Availability cached per-process for 60 seconds. No extra dependencies — uses stdlib `:inets`. |

**Models**

| Purpose | Default model |
|---|---|
| Text generation | `llama3.2` |
| Embeddings | `nomic-embed-text` (768 dims) |

**Public API**

```elixir
Ollama.available?()            # boolean() — cached 60s per process
Ollama.embed(text, opts)       # {:ok, [float()]} | {:error, atom()}
  # opts: :model
Ollama.generate(prompt, opts)  # {:ok, String.t()} | {:error, atom()}
  # opts: :model, :system, :temperature
```

**Graceful degradation:** every module that calls Ollama checks `available?/0` first and falls back to regex or heuristic logic. The pipeline never blocks or fails because Ollama is offline.

---

## Supporting Structs

| Module | File | Purpose |
|---|---|---|
| `Context` | `context.ex` | Universal data struct. All content types (signal, resource, memory, skill). Carries L0/L1/L2 tiers, S=(M,G,T,F,W) dimensions, entities, score. |
| `Signal` | `signal.ex` | Legacy signal struct. Embedded inside `Context` for `:signal` type contexts. Use `Context.to_signal/1` and `Context.from_signal/1` to convert. |
| `Intake.Writer` | `intake/writer.ex` | Writes signal markdown files to `{node}/signals/` directories with YAML frontmatter. |
| `Intake.Skeleton` | `intake/skeleton.ex` | Applies genre-specific skeleton structure to signal content. |
