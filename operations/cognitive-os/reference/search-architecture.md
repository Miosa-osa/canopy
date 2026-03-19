# Search Architecture

A reference for how OptimalOS retrieves context. Covers the hybrid search pipeline, scoring formula, temporal decay, tiered loading strategy, graph boost, and graceful degradation when Ollama is unavailable.

---

## Hybrid Search Pipeline

```
Query
  → IntentAnalyzer        (query expansion, entity extraction, type detection)
  → [FTS5 BM25]           (keyword matching via SQLite contexts_fts)
    + [Vector Similarity]  (semantic matching via nomic-embed-text embeddings)
  → RRF Fusion            (Reciprocal Rank Fusion, α=0.6 weighting)
  → Temporal Decay        (e^(-λ * hours_old), genre-specific half-lives)
  → S/N Boost             (signals with higher signal-to-noise ratio rank higher)
  → Graph Boost           (entities with strong graph connections to query entities rank higher)
  → Results               (ranked list with L0 abstracts)
```

---

## Search Modalities

| Modality | Engine | When to Use | Strengths |
|----------|--------|-------------|-----------|
| FTS5 BM25 | SQLite `contexts_fts` | Keyword-heavy queries, exact names, dates | Fast, exact matching, no external dependencies, always available |
| Vector Similarity | Ollama `nomic-embed-text` + SQLite vectors | Semantic and conceptual queries | Finds related concepts even without keyword match; handles synonyms and paraphrasing |
| Hybrid (RRF) | Both merged via α=0.6 weighting | Default when Ollama is available | Best precision + recall; combines exact and semantic |

**Rule**: Always use hybrid when Ollama is available. Fall back to FTS5 when it is not. The engine detects availability automatically — no manual switching required.

---

## Scoring Formula

### FTS5 Only (without Ollama)

```
final_score = bm25_score * temporal_factor * sn_ratio_boost
```

Where:
- `bm25_score` — SQLite FTS5 BM25 relevance score (higher = more keyword matches)
- `temporal_factor` — `e^(-λ * hours_old)` — exponential decay based on signal age
- `sn_ratio_boost` — multiplier based on the signal's stored S/N ratio (0.0 to 1.0)

### Hybrid (with Ollama)

```
hybrid_score = α * normalized_fts + (1-α) * vector_similarity
```

Then:
```
final_score = hybrid_score * temporal_factor * sn_ratio_boost * graph_boost
```

Where:
- `α = 0.6` — weighting that favors FTS precision (configurable in `config/config.exs`)
- `normalized_fts` — BM25 score normalized to [0, 1] range
- `vector_similarity` — cosine similarity between query embedding and document embedding
- `graph_boost` — multiplier applied when query entities have strong graph connections to result entities

---

## Temporal Decay

All signals decay over time. Recent signals rank higher than old ones with otherwise equal relevance. The decay rate is genre-specific — some signal types remain valuable much longer than others.

### Decay Formula

```
temporal_factor = e^(-λ * hours_old)
```

Where `λ = ln(2) / half_life_in_hours`

At `t = half_life`: the score is multiplied by 0.5. At `t = 2 * half_life`: multiplied by 0.25.

### Genre-Specific Half-Lives

Defined in `topology.yaml`:

| Genre | Half-Life | Rationale |
|-------|-----------|-----------|
| `decision-log` | 2160 hours (90 days) | Decisions stay relevant for quarters |
| `spec` | 4320 hours (180 days) | Specs are long-lived; architecture doesn't change weekly |
| `note` | 720 hours (30 days) | General notes have medium relevance lifespan |
| `transcript` | 168 hours (7 days) | Conversations decay fast; context shifts |
| `signal` | 336 hours (14 days) | Weekly state; relevant for two cycles |
| `brief` | 168 hours (7 days) | Point-in-time communications |

**Implication for search**: A 90-day-old `decision-log` still scores at 50% of its original relevance. A 7-day-old `transcript` scores at 50%. Use `mix optimal.reweave` to surface contexts that are approaching staleness.

---

## Tiered Loading

Search results are returned as L0 abstracts. Loading more detail is explicit and intentional.

| Tier | Token Budget | Contents | When to Use |
|------|-------------|----------|-------------|
| L0 | ~100 tokens | Title, one-sentence summary, key entities, S/N score | Default for search results; always load first |
| L1 | ~2K tokens | Full summary, key points, decisions, action items | When L0 indicates the signal is relevant |
| L2 (full) | ~10K+ tokens | Complete signal content | Only when L1 is insufficient; rare |

**The tiered loading discipline**:
1. Search returns L0 — scan for relevance
2. `mix optimal.read --tier l1` for anything that looks relevant — decide if full read is needed
3. `mix optimal.read --tier full` only when L1 confirms full content is necessary
4. Never read full when L1 suffices

**Why this matters**: Reading 10 full signals instead of using tiered loading wastes ~95K tokens per session. Over a week, this is the difference between a context window that stays clean and one that requires constant compaction.

---

## Graph Boost

After the base scoring (BM25 + vector + decay + S/N), a graph boost is applied based on entity relationship strength.

**How it works**:
1. IntentAnalyzer extracts entities from the query (people, domains, projects)
2. The knowledge graph is traversed to find strongly connected entities
3. Results whose entities share strong graph edges with the query entities receive a score multiplier
4. Results with isolated entities (weak graph connections) receive no boost

**Effect**: Well-connected, cross-referenced signals rank higher than isolated ones. A signal about "Ed Honour + AI Masters pricing" ranks higher in an Ed Honour query than a signal that only mentions Ed once in passing, because the graph knows Ed is a hub for the AI Masters node.

**Commands to inspect graph state**:
```bash
cd engine && mix optimal.graph hubs       # most-connected entities (>2σ degree)
cd engine && mix optimal.graph triangles  # synthesis opportunities (A→B, A→C but not B→C)
cd engine && mix optimal.reflect          # entities co-occurring without edges
```

---

## Commands

```bash
# Default hybrid search — returns L0 abstracts ranked by final_score
cd engine && mix optimal.search "pricing decision"

# Filter by signal type
cd engine && mix optimal.search "revenue" --type signal

# Filter by node
cd engine && mix optimal.search "Ed Honour" --node ai-masters

# Filter by genre
cd engine && mix optimal.search "revenue" --genre decision-log

# Increase result count (default: 5)
cd engine && mix optimal.search "query" --limit 20

# Build a tiered context bundle for a topic (L0 + L1 + L2 with token counts)
cd engine && mix optimal.assemble "AI Masters pricing"

# Read a specific signal at a specific tier
cd engine && mix optimal.read "optimal://nodes/ai-masters/signals/2026-03-18-ed-call.md" --tier l0
cd engine && mix optimal.read "optimal://nodes/ai-masters/signals/2026-03-18-ed-call.md" --tier l1
cd engine && mix optimal.read "optimal://nodes/ai-masters/signals/2026-03-18-ed-call.md" --tier full
```

---

## IntentAnalyzer

The IntentAnalyzer runs before search to improve query quality. When Ollama is available, it:

1. **Expands the query** — adds synonyms and related terms (e.g., "revenue" → also searches "income", "ARR", "pipeline", "deal")
2. **Extracts entities** — identifies people, domains, and projects in the query
3. **Detects type** — infers whether the query is seeking a decision, a person, a project status, or a temporal signal
4. **Adjusts weighting** — applies node-level and genre-level filters based on detected intent

Without Ollama: query is passed through unchanged. FTS5 handles matching directly.

---

## Graceful Degradation

The engine is designed to function fully without Ollama. All search, ingest, and retrieval operations work in FTS5-only mode.

| Component | With Ollama | Without Ollama |
|-----------|-------------|----------------|
| Search modality | Hybrid (FTS5 + vector similarity) | FTS5 only |
| Intent analysis | LLM query expansion + entity extraction | Pass-through (query used as-is) |
| Embeddings | `nomic-embed-text` vectors stored in SQLite | Skipped; no vectors generated |
| Scoring | Full hybrid formula (BM25 + vector + decay + S/N + graph) | BM25 + decay + S/N (no vector term) |
| Ingest classification | LLM classifies S=(M,G,T,F,W) dimensions | Rule-based classification (lower accuracy) |
| S/N scoring | LLM estimates signal-to-noise ratio | Heuristic scoring |

**Detection**: The engine checks Ollama availability at startup and on each operation. No configuration change is needed to switch modes — it degrades automatically.

**When to run with Ollama**: For LEARN and SYNTHESIZE sessions where semantic search matters. For EXTRACT sessions after high-information calls.

**When FTS5 suffices**: For known-item retrieval where you know the keywords. For OPERATE sessions clearing a queue of ingested signals with known entity names.

---

## Search vs Assemble vs Browse

These three retrieval patterns serve different purposes:

| Command | Pattern | When to Use |
|---------|---------|-------------|
| `mix optimal.search` | Query → ranked results | You have a question; don't know which file has the answer |
| `mix optimal.assemble` | Topic → context bundle | You're starting a work session on a known topic; need comprehensive context |
| `mix optimal.read --tier l1` | File → summary | You know the file; need to verify its contents without loading full text |
| `mix optimal.ls` | Browse node | You want to see what exists in a node before querying |
| `mix optimal.l0` | Always-loaded context | Session start; load the baseline context every session needs |

**Rule**: Search before reading. Never `Read` a file directly if you don't know which file contains what you need. `mix optimal.search` costs a few hundred tokens; guessing the wrong file and reading it costs thousands.

---

## See Also

- `reference/failure-modes.md` — Mode 9 (Decay Failure) and Mode 8 (Herniation Failure) for what happens when search surfaces stale or incoherent content
- `reference/session-lifecycle.md` — Context budget and tiered loading strategy per session type
- `config/config.exs` — Search weighting (α), decay parameters, Ollama configuration
- `engine/lib/optimal_engine/search_engine.ex` — Search pipeline implementation
- `engine/lib/optimal_engine/intent_analyzer.ex` — Query expansion and entity extraction
