# Engine Layer Architecture

> The engine is the invisible infrastructure underneath the workspace. It powers
> search, memory, knowledge graphs, classification, and integrations — but never
> enters the agent's context window directly. Skills call the engine. The engine
> returns results. Zero tokens consumed by infrastructure.
>
> There is no single "right" engine. Different workspaces need different backends.
> This document defines what the engine DOES, then shows the options for HOW.

---

## What the Engine Does

The engine serves 7 functions. Every workspace needs some combination of these.
No workspace needs all of them.

| Function | What It Does | Which Skills Use It |
|----------|-------------|-------------------|
| **Text Search** | Full-text keyword search across all workspace content | /search, /assemble, /reweave |
| **Semantic Search** | Vector similarity search (find conceptually related content) | /search, /reflect, /assemble |
| **Knowledge Graph** | Entity extraction, relationship edges, triangle detection | /graph, /reflect, /reweave |
| **Memory Store** | Episodic, semantic, and procedural memory persistence | /remember, /rethink, session resume |
| **Classification** | Signal Theory auto-classification S=(M,G,T,F,W) and routing | /ingest, S/N quality gate |
| **Context Assembly** | Tiered loading — build the right context for the current task | /assemble, boot sequence |
| **Integrations** | External API connections (CRM, email, payments, webhooks) | /pay, /delegate, custom skills |

---

## Engine Backends: The Options

The engine is pluggable. Different data types need different storage. Different
scales need different backends. Here are the options for each function:

### Text Search

| Backend | Best For | How It Works | Trade-offs |
|---------|---------|-------------|-----------|
| **SQLite FTS5** | Local workspaces, single-user, <100K docs | Virtual table with BM25 ranking. Ships with SQLite. Zero setup. | Fast, embedded, no server. Limited to keyword matching. |
| **Tantivy** (Rust) | High-performance local search | Rust-based Lucene alternative. Embedded. | Fastest local option. Requires compilation. |
| **Typesense** | Multi-user, hosted workspaces | Lightweight search server. Typo-tolerant. | Easy to host, fast, but requires a server. |
| **Meilisearch** | User-facing search UIs | Instant search with facets and filters. | Great UX, but heavier than needed for agent-only use. |
| **Elasticsearch** | Enterprise, millions of docs | The standard. Scales horizontally. | Overkill for most workspaces. Java dependency. |
| **Flat grep** | Tiny workspaces, <1K files | ripgrep on the filesystem. No index needed. | No ranking, no relevance scoring. Sufficient for small workspaces. |

**Recommendation**: Start with **SQLite FTS5**. It's embedded, zero-config, and handles
everything up to ~100K documents. Move to Typesense or Tantivy if you need multi-user
or performance at scale.

### Semantic Search (Vector Store)

| Backend | Best For | How It Works | Trade-offs |
|---------|---------|-------------|-----------|
| **SQLite + manual cosine** | Simple workspaces, <10K vectors | Store embeddings as BLOBs, compute cosine similarity in queries. | No dependencies. Slow at scale (linear scan). |
| **sqlite-vec** | Local workspaces, <100K vectors | SQLite extension for vector operations. ANN search. | Embedded, fast, no server. Requires extension install. |
| **Qdrant** | Production semantic search | Purpose-built vector DB. Filtering + search combined. | Best standalone vector DB. Requires server. |
| **ChromaDB** | Python-heavy workflows | Embedded vector DB with Python API. | Easy Python integration. Less mature than Qdrant. |
| **Pinecone** | Serverless, managed | Hosted vector DB. Zero ops. | No self-hosting option. Vendor lock-in. Pay per query. |
| **pgvector** | Already running Postgres | PostgreSQL extension for vector ops. | Reuse existing DB. Performance depends on Postgres tuning. |
| **LanceDB** | Embedded, Rust-based | Zero-copy columnar vector store. | New but promising. Embedded like SQLite. |
| **None** | Text search is sufficient | Skip vectors entirely. FTS5 handles it. | No semantic similarity. Works fine for many workspaces. |

**Recommendation**: Most workspaces don't need vectors at all — FTS5 keyword search
is sufficient. If you need semantic search, start with **sqlite-vec** (embedded) or
**Qdrant** (server). Only use hosted services (Pinecone) if you need serverless scale.

### Embeddings (for vector search)

| Provider | Model | Dimensions | Best For |
|----------|-------|-----------|---------|
| **Ollama** (local) | nomic-embed-text, mxbai-embed-large | 768-1024 | Privacy, offline, no API costs |
| **OpenAI** | text-embedding-3-small/large | 1536-3072 | Highest quality, cloud-only |
| **Google Gemini** | gemini-embedding-001 | 768-3072 | Native multimodal (text+images+video), flexible output dims, free tier |
| **Cohere** | embed-v4 | 1024 | Multilingual, good quality, binary quantization |
| **Voyage AI** | voyage-3, voyage-code-3 | 1024 | Code-aware embeddings, best for dev workspaces |
| **Jina AI** | jina-embeddings-v3 | 1024 | Late interaction, multilingual, task-specific adapters |
| **Local ONNX** | BGE, GTE, E5, Snowflake Arctic | 384-1024 | Fastest local, no GPU needed |
| **Mixedbread** | mxbai-embed-large-v2 | 1024 | High quality open-source, Matryoshka dimensionality |

**Recommendation**: **Ollama** with nomic-embed-text for local/private workspaces.
**Google Gemini** gemini-embedding-001 for workspaces that handle mixed content (text + images).
**OpenAI** text-embedding-3-small for cloud workspaces where quality matters most.
All three support flexible output dimensions — embed at 256 dims for speed, 1024+ for quality.

### Knowledge Graph

| Backend | Best For | How It Works | Trade-offs |
|---------|---------|-------------|-----------|
| **SQLite edges table** | Most workspaces | Simple table: source, target, relation_type, weight. 3-way indexing (SPO/POS/OSP) for O(1) lookups. | Embedded, simple, handles ~100K edges fine. |
| **ETS** (Erlang/Elixir) | BEAM systems, hot-path reads | In-memory ordered_set tables with 3-way indexing. Sub-microsecond reads. | Lost on restart. Restore from SQLite/files on boot. |
| **RocksDB** | Persistent graph, >100K edges | LSM-tree key-value store. Prefix scans as trie iterators. Empty values (key IS the triple). Dictionary encoding for compression. | C NIF dependency. Best for large knowledge bases that don't fit in memory. |
| **Neo4j** | Large-scale graph analysis | Native graph DB. Cypher query language. | Powerful traversals. Requires JVM + server. |
| **NetworkX** (Python) | Analysis + visualization | In-memory graph library. Export to Graphviz/D3. | Great for analysis. Not a persistent store. |
| **Apache AGE** | Graph on Postgres | PostgreSQL extension adding Cypher support. | Reuse Postgres. Newer, less mature. |
| **DuckDB** | Analytics on graph data | Embedded OLAP. Great for aggregate queries over edges. | Not a graph DB, but handles graph analytics well. |
| **Filesystem** | Tiny workspaces | Markdown files with YAML frontmatter linking to each other. Backlinks as frontmatter arrays. | Zero infrastructure. No traversal queries. Works for <500 entities. |

**Advanced graph techniques** (for engines that need them):
- **Dictionary encoding** — Map RDF terms to 64-bit IDs with 4-bit type tags. Inline integers/dates in the low 60 bits to skip dictionary lookups entirely. Reduces storage and speeds up joins.
- **Leapfrog Triejoin** — Worst-case optimal multi-way join for complex graph patterns with 4+ shared variables. Uses sorted iterators (prefix scans on RocksDB, sorted ETS tables) as tries.
- **Cost-based query optimization** — Predicate histograms + cardinality estimation + DPccp join enumeration. Automatically reorder triple patterns for minimum intermediate result size.
- **Semi-naive reasoning** — OWL 2 RL forward-chaining that only processes NEW triples each iteration. Delta computation avoids reprocessing the entire graph on small additions.
- **TBox caching** — Cache schema hierarchies (class/property inheritance) in `:persistent_term` for zero-copy cross-process access.

**Triple vs Quad store**: A triple store holds `(subject, predicate, object)`. A quad
store adds a fourth element: `(graph, subject, predicate, object)` — this lets you
isolate knowledge by workspace section, agent, or domain. Use 4 indices (GSPO/GPOS/SPOG/POSG)
instead of 3. The MIOSA Knowledge engine supports both modes.

**Recommendation**: **SQLite edges table** for most workspaces. Self-join queries
handle triangle detection, cluster analysis, and hub identification up to ~100K edges.
Add **RocksDB** for persistent graphs that don't fit in memory. Move to Neo4j only
if you need complex multi-hop traversals at scale.

### Memory Store

Different memory types need different storage strategies:

| Memory Type | Recommended Backend | Why | Schema |
|-------------|-------------------|-----|--------|
| **Working** | LLM context window | It IS the context window. Not stored externally. | N/A |
| **Episodic** | SQLite + compressed JSON | Time-indexed, queryable, compressed. Full transcripts go to cold storage (filesystem or S3). | `episodic_records` table |
| **Semantic** | SQLite + FTS5 | Fact statements need full-text search. Entity graph in separate edges table. | `semantic_records` + `semantic_fts` + `entity_edges` tables |
| **Procedural** | YAML files (version controlled) | Procedures are like skills — they should be auditable, diffable, human-editable. Indexed in SQLite for trigger matching. | `.canopy/procedural/*.yaml` + SQLite index |
| **Foresight** | SQLite | Forward-looking predictions with time bounds. Surfaced during daily boot to catch upcoming deadlines and dependencies. | `foresight` table: `{prediction, confidence, start_time, end_time, source}` |

**Alternative memory backends:**

| Backend | When to Use | Trade-offs |
|---------|-----------|-----------|
| **Mem0** | Managed memory service | API-based. Handles dedup, conflict resolution, decay automatically. Vendor dependency. |
| **Zep** | Long-term conversation memory | Designed for chat memory. Auto-summarization. Good for episodic. |
| **Redis** | High-speed session state | Sub-ms reads. Good for working memory spillover. Volatile. |
| **PostgreSQL** | Multi-user, shared memory | Full SQL, great for team workspaces. Requires server. |
| **Filesystem only** | Simplest option | JSON/YAML files in `.canopy/`. No DB needed. Slow at scale. |

**Recommendation**: **SQLite** for everything persistent. It's embedded, reliable, and
handles all 4 memory types in one file. Use **filesystem YAML** for procedural memory
(it should be version-controlled). Only add Redis/Postgres if multi-user or performance
demands it.

### Classification Engine

| Backend | How It Works | Best For |
|---------|-------------|---------|
| **LLM-based** (Ollama/OpenAI/Claude) | Send content to LLM, get S=(M,G,T,F,W) back | Highest quality classification. Costs tokens per classification. |
| **Rule-based** | Regex + keyword matching for genre/type detection | Zero cost. Fast. Handles 80% of cases. |
| **Hybrid** | Rules first, LLM fallback for ambiguous cases | Best balance. Rules handle obvious cases, LLM handles edge cases. |
| **Fine-tuned local model** | Small model trained on your workspace's classification patterns | Fast + accurate after training. Requires training data + GPU. |

**Recommendation**: **Hybrid** — rule-based for obvious classifications (file extension
→ format, keyword → genre), LLM for ambiguous cases. This gives you 80% classification
at zero cost, with LLM quality for the hard 20%.

### LLM Providers (for classification, summarization, embedding, generation)

| Provider | Models | Best For | Local? |
|----------|--------|---------|--------|
| **Ollama** | Llama 3.3, Mistral, Gemma 3, Phi-4, Qwen 3 | Privacy, offline, no API costs | Yes |
| **Anthropic** | Claude Opus 4, Sonnet 4, Haiku 3.5 | Highest reasoning quality | No |
| **OpenAI** | GPT-4.1, GPT-4o-mini, o3/o4-mini | Broad capability, reasoning models | No |
| **Google** | Gemini 2.5 Pro/Flash, gemini-embedding-001 | Multimodal (images, video, audio), native embeddings | No |
| **Groq** | Llama 3.3, Mixtral, DeepSeek | Fastest inference (cloud), free tier | No |
| **DeepSeek** | DeepSeek-V3, DeepSeek-R1 | Cheap, strong reasoning, open-weight | No |
| **xAI** | Grok 3, Grok 3 Mini | Fast, large context (131K), real-time data | No |
| **Cerebras** | Llama 3.3, Qwen 3 | Ultra-fast inference (>2K tokens/sec) | No |
| **Local GGUF** | Any quantized model via llama.cpp | Full control, no network | Yes |
| **MLX** (Apple Silicon) | Any model via mlx-lm | Fast local inference on Mac, no GPU needed | Yes |

**Recommendation**: **Ollama** for local workspaces (graceful degradation when offline).
**Claude** for highest quality when API is available. **Gemini** for multimodal workspaces
(analyzing screenshots, images, video). The engine should support **multiple providers** —
use cheap/fast models for classification and summarization, expensive/smart models for
generation and analysis.

**Model tiering pattern** (use different models for different engine functions):

| Function | Cheap/Fast Model | Quality Model | Why |
|----------|-----------------|---------------|-----|
| Classification | Ollama/llama3, Haiku | — | Runs on every ingest. Must be cheap. |
| Summarization | Ollama/llama3, Flash | — | High volume. L0/L1 generation. |
| Embeddings | Ollama/nomic, Gemini | OpenAI text-3-large | Batch operation. Quality matters for search. |
| Entity extraction | Ollama/llama3, Haiku | Sonnet | Moderate volume. Accuracy important. |
| Generation | — | Opus, GPT-4.1, Gemini Pro | User-facing output. Quality is everything. |
| Reasoning/Rethink | — | Opus, o3, DeepSeek-R1 | Complex synthesis. Worth the cost. |

---

## Engine Configurations by Workspace Type

Not every workspace needs the same engine. Here are reference configurations:

### Minimal (Personal Notes / Second Brain)

```yaml
engine:
  text_search: sqlite_fts5
  semantic_search: none           # FTS5 is enough for personal use
  knowledge_graph: sqlite_edges
  memory:
    episodic: sqlite
    semantic: sqlite_fts5
    procedural: yaml_files
  classification: rule_based      # No LLM needed for personal notes
  llm: ollama                     # Local, free, offline
  storage: single_sqlite_file     # Everything in one .db file
```

**Total infrastructure**: 1 SQLite file. That's it.

### Standard (Agency / Business Workspace)

```yaml
engine:
  text_search: sqlite_fts5
  semantic_search: sqlite_vec     # Vectors for finding related content
  knowledge_graph: sqlite_edges
  memory:
    episodic: sqlite
    semantic: sqlite_fts5
    procedural: yaml_files
  classification: hybrid          # Rules + LLM fallback
  embeddings: ollama/nomic-embed-text
  llm:
    classification: ollama/llama3  # Cheap, local
    generation: claude-sonnet      # Quality for output
    summarization: ollama/llama3   # Cheap, local
  storage: sqlite + filesystem
```

**Total infrastructure**: SQLite + Ollama running locally.

### Production (Multi-User / MIOSA Platform)

```yaml
engine:
  text_search: typesense          # Multi-user, hosted
  semantic_search: qdrant         # Production vector search
  knowledge_graph: sqlite_edges   # Still fine at this scale
  memory:
    episodic: postgresql          # Multi-user, shared
    semantic: postgresql + fts    # Shared fact base
    procedural: yaml_files + git  # Version controlled
  classification: hybrid
  embeddings: openai/text-embedding-3-small
  llm:
    classification: claude-haiku   # Fast, cheap
    generation: claude-opus        # Maximum quality
    summarization: claude-haiku    # Fast, cheap
  storage: postgresql + s3
  cache: redis                    # Session state, L0/L1 cache
```

**Total infrastructure**: PostgreSQL + Redis + Typesense + Qdrant + S3.

### Enterprise (Zero-Human Company)

```yaml
engine:
  text_search: elasticsearch      # Millions of docs across workspaces
  semantic_search: qdrant_cluster # Distributed vector search
  knowledge_graph: neo4j          # Complex multi-hop traversals
  memory:
    episodic: postgresql_partitioned  # Partitioned by workspace
    semantic: postgresql + pgvector   # Combined relational + vector
    procedural: yaml_files + git
  classification: fine_tuned_local + llm_fallback
  embeddings: voyage-3            # Code-aware
  llm:
    classification: fine_tuned    # Custom model, fastest
    generation: claude-opus       # Maximum quality
    summarization: claude-haiku
    code: claude-sonnet           # Code generation
  storage: postgresql + s3 + cdn
  cache: redis_cluster
  monitoring: prometheus + grafana
```

---

## Retrieval Patterns

### Single-Pass (Default)

Query → hybrid search (keyword + vector) → RRF fusion → return top N results.
Fast, cheap, handles 80% of queries. Use this as the default.

### Agentic Multi-Round (Complex Queries)

When single-pass results are insufficient, the engine can run multi-round retrieval:

```
Round 1: Query → hybrid search → top N results
  → LLM judges: "Are these results sufficient to answer the query?"
  → If yes: return results. Done.
  → If no: LLM generates 2-3 refined sub-queries

Round 2: Sub-queries → parallel hybrid search → combine all results → deduplicate
  → Return merged, reranked results
```

More expensive (2+ LLM calls per retrieval), but catches complex queries where
the user's phrasing doesn't match the stored content. Use for queries like
"what should I do about the delayed launch?" where no exact keywords match.

### Retrieval Hierarchy

Skills should follow this order, stopping as soon as they have enough:

```
1. Check L0 (already loaded, 0 cost)
2. Check working memory (current session, 0 cost)
3. Search L1 summaries (fast, ~100 tokens per result)
4. Load L2 full content for top matches (~2K tokens each)
5. Engine hybrid search (FTS5 + vector + graph)
6. Agentic multi-round (expensive, last resort)
```

See [`guides/data-architecture.md`](../guides/data-architecture.md) for the full
retrieval strategy with decision criteria.

---

## How the Engine Connects to the System Model

In the [system model](system-model.md), the engine sits at these coordinates:

| Component | Persistence | Attention | Authorship | Space |
|-----------|------------|-----------|------------|-------|
| Search index | Derived | Invisible | Derived | Knowledge |
| Vector store | Derived | Invisible | Derived | Knowledge |
| Knowledge graph | Permanent | Invisible | Derived | Knowledge |
| Memory tables | Various | Invisible | Derived | Operations |
| Classification rules | Permanent | Invisible | Protocol | Capability |
| LLM connections | N/A | Invisible | Protocol | Capability |
| Integration configs | Permanent | Invisible | Protocol | Capability |
| Cache (L0/L1) | Session | Invisible | Derived | Operations |

Everything is **Invisible** on the Attention dimension — the engine never enters
the context window. Skills are the interface. The agent calls `/search "pricing"`,
the skill calls the engine, the engine returns results, the skill formats them
for the context window. The agent never sees SQLite, never sees vectors, never
sees the graph database.

### The Engine Powers All 3 Flows

**Attention Flow**: Engine provides text search, semantic search, and context assembly.
When the agent needs knowledge, it calls a skill that calls the engine.

```
Agent needs info → /search skill → Engine (FTS5 + vectors) → Results → Context window
```

**Production Flow**: Engine provides classification, quality gates, and integrations.
When the agent produces output, the engine classifies it and checks S/N quality.

```
Agent produces output → Engine (classifier) → S=(M,G,T,F,W) → S/N gate → Deliver
```

**Learning Flow**: Engine provides memory storage and pattern detection.
When sessions end, the engine compresses, extracts, and stores.

```
Session ends → Engine (compress) → Episodic → Engine (extract) → Semantic → Engine (detect) → Procedural
```

---

## Filesystem Layout

The engine lives in `engine/` within the workspace:

```
engine/
├── config.yaml              ← Which backends to use (the configs above)
├── db/
│   ├── workspace.db         ← SQLite: search index, memory, graph edges
│   └── vectors.db           ← sqlite-vec: embeddings (if using vectors)
├── cache/
│   ├── l0/                  ← Pre-computed L0 abstracts
│   └── l1/                  ← Cached L1 summaries
├── models/
│   └── classifier.onnx      ← Fine-tuned classification model (if using)
├── integrations/
│   ├── crm.yaml             ← CRM connection config
│   ├── email.yaml           ← Email integration
│   └── payments.yaml        ← Stripe MPP config
└── scripts/
    ├── index.sh             ← Rebuild search index
    ├── migrate.sh           ← Database migrations
    └── health.sh            ← Engine health check
```

### The engine/ Directory Is Gitignored Selectively

```gitignore
# Engine databases are derived — rebuild from workspace files
engine/db/
engine/cache/

# Config and integrations ARE version controlled
!engine/config.yaml
!engine/integrations/
!engine/scripts/
```

The databases are derived data — you can delete `engine/db/` and rebuild from
the workspace files (run `engine/scripts/index.sh`). The config and integration
settings are version-controlled because they define HOW the engine works.

---

## Building Your Own Engine

The engine is not a monolith. It's a set of pluggable functions. You can:

1. **Start with nothing** — Skills just read/write files. No database. Works for
   small workspaces (<100 files).

2. **Add SQLite** — One `.db` file gives you text search (FTS5), memory tables,
   and knowledge graph edges. Handles 90% of workspaces.

3. **Add vectors** — sqlite-vec or Qdrant for semantic search. Only needed if
   keyword search isn't finding what you need.

4. **Add LLM** — Ollama locally or cloud providers. Powers classification,
   summarization, and generation.

5. **Add integrations** — CRM, email, payments, webhooks. Each is a config file
   in `engine/integrations/`.

6. **Scale up** — Replace SQLite with PostgreSQL, add Redis, add Elasticsearch.
   The skills don't change — only the engine config changes.

The key insight: **skills are the API, the engine is the implementation.** A skill
like `/search` works the same whether the engine uses flat grep, SQLite FTS5, or
Elasticsearch. The agent doesn't know or care.

---

## Reference Implementation: OptimalOS Engine

The OptimalOS cognitive workspace (the first Canopy workspace ever built) uses
this engine stack:

| Function | Backend | Why |
|----------|---------|-----|
| Text search | SQLite FTS5 | 269 contexts, fast enough |
| Semantic search | sqlite-vec + Ollama nomic-embed-text | Finds conceptually related content |
| Knowledge graph | SQLite edges table | 1045 edges, triangle detection via self-join |
| Memory | SQLite (episodic + semantic) + YAML (procedural) | Single file, embedded |
| Classification | Hybrid (rules + Ollama llama3 fallback) | Free, offline, good enough |
| Context assembly | Custom Elixir (ContextAssembler) | L0/L1/L2 tiered loading |
| LLM | Ollama (local) with Claude fallback | Privacy + quality when needed |

Built in Elixir/OTP. 25+ modules. 13 Mix tasks. Compiles to a single binary
that runs locally with zero external dependencies (except Ollama for LLM features).

---

## Related

- [system-model.md](system-model.md) — Where the engine sits in the 4-dimensional model
- [tiered-loading.md](tiered-loading.md) — How the engine serves L0/L1/L2 content
- [memory-architecture.md](memory-architecture.md) — Memory types the engine stores
- [signal-integration.md](signal-integration.md) — Classification and S/N gates
- [basement.md](basement.md) — Typed resource system the engine indexes
