---
name: prompt-cache-optimizer
description: "Optimize token usage through prompt caching and compression"
trigger: "auto"
priority: 2
---

# Prompt Cache Optimizer Skill

Reduces token costs by 50-90% through intelligent caching and compression.

## When to Activate

- Large context windows (>50K tokens)
- Repeated similar queries
- Long-running sessions
- Cost-conscious operations

## Optimization Layers

### Layer 1: Semantic Caching
```
Query → Embedding → Similarity Search → Cache Hit/Miss
         ↓              ↓
    Vector Store    Return cached or call LLM
```

Cache hits provide 100% token savings with near-instant response.

### Layer 2: Prompt Compression (LLMLingua-2)
- **Light**: 2-3x reduction, <5% accuracy impact
- **Moderate**: 5-7x reduction, 5-15% accuracy impact
- **Aggressive**: 10-20x reduction, requires validation

### Layer 3: Strategic Context Placement
Mitigate "lost in the middle" problem:
- Place most important information at START and END
- Middle content has 30-50% lower retention

### Layer 4: Hierarchical Memory Tiering
```
Working Memory (registers)  → Always in context
FIFO Queue (L1/L2 cache)    → Recent exchanges
Archival Memory (disk)      → Semantic search only
```

## Implementation Workflow

1. **Check semantic cache** before any LLM call
2. **Compress context** using appropriate level
3. **Structure placement** - critical info at boundaries
4. **Tier management** - evict low-importance content
5. **Cache response** for future queries

## Compression Decision Matrix

| Context Size | Latency Need | Accuracy Need | Strategy |
|--------------|--------------|---------------|----------|
| <10K tokens  | Any          | Any           | No compression |
| 10K-50K      | Low          | High          | Light (2-3x) |
| 10K-50K      | High         | Medium        | Moderate (5-7x) |
| 50K-100K     | Any          | Medium        | Aggressive (10-20x) |
| >100K        | Any          | Any           | Hierarchical + Aggressive |

## Key Patterns

### Attention Sink Preservation
For streaming/long sessions, preserve first 4 tokens as attention sinks:
```
[attention_sinks (4 tokens)] + [rolling_window (window - 4)]
```
This maintains model coherence over infinite context.

### Hybrid Search for RAG
```
Hybrid = Dense (semantic) + Sparse (BM25)
Fusion = Reciprocal Rank Fusion (RRF)
```
Achieves 50-100x document reduction with maintained relevance.

## Metrics to Track

- Cache hit rate (target: >60%)
- Compression ratio achieved
- Accuracy impact (sample validation)
- Token savings per session
- Latency impact

## Integration Points

- Pre-prompt: Apply compression
- Post-response: Cache result
- Session start: Load cached context
- Memory pressure: Tier eviction

---

*Based on LLMLingua, GPTCache, MemGPT, and StreamingLLM research*
