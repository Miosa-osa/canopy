---
name: eval-rag
description: >
  Evaluate retrieval and generation quality in RAG pipelines. Separate scoring
  for retrieval (recall, precision, MRR) and generation (faithfulness, relevance,
  completeness). End-to-end pipeline assessment with bottleneck identification.
  Triggers on: "eval rag", "rag evaluation", "retrieval evaluation", "rag quality", "rag metrics"
---

# /eval-rag

> Evaluate retrieval + generation quality in RAG pipelines.

## Purpose

Assess a Retrieval-Augmented Generation pipeline by evaluating retrieval and generation independently, then measuring end-to-end quality. Retrieval scoring checks if the right documents are fetched (recall, precision, MRR, NDCG). Generation scoring checks if the answer is faithful to retrieved context (no hallucination), relevant to the question, and complete. Identifies whether failures originate in retrieval, generation, or both, so you know where to invest improvement effort.

## Usage

```bash
# Full RAG evaluation
/eval-rag --pipeline rag/ --queries eval/queries.jsonl --golden eval/golden.jsonl

# Evaluate retrieval only
/eval-rag --pipeline rag/ --queries eval/queries.jsonl --golden eval/golden.jsonl --stage retrieval

# Evaluate generation only (with pre-fetched contexts)
/eval-rag --contexts retrieved.jsonl --queries eval/queries.jsonl --golden eval/golden.jsonl --stage generation

# Custom retrieval depth
/eval-rag --pipeline rag/ --queries eval/queries.jsonl --golden eval/golden.jsonl --k 10

# Compare two retrieval configurations
/eval-rag --pipeline rag-v1/ --pipeline-b rag-v2/ --queries eval/queries.jsonl --golden eval/golden.jsonl
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--pipeline` | string | required | Path to RAG pipeline configuration or directory |
| `--pipeline-b` | string | — | Second pipeline for A/B comparison |
| `--queries` | string | required | Path to evaluation queries (JSONL) |
| `--golden` | string | required | Path to golden answers with relevant doc IDs (JSONL) |
| `--contexts` | string | — | Pre-retrieved contexts (skips retrieval stage) |
| `--stage` | enum | `both` | Evaluate: `retrieval`, `generation`, `both` |
| `--k` | int | `5` | Retrieval depth (top-K documents) |
| `--output` | string | stdout | Write report to file |
| `--format` | enum | `markdown` | Output format: `markdown`, `json` |
| `--faithfulness-judge` | string | built-in | Custom judge prompt for faithfulness scoring |
| `--sample` | int | all | Sample size from query set |

## Workflow

1. **Load** — Parse pipeline config, queries, and golden answers. Each query should have: question, relevant document IDs (for retrieval scoring), and golden answer (for generation scoring).
2. **Retrieval evaluation** — For each query, run retrieval and compare fetched documents against golden relevant docs. Compute per-query and aggregate metrics:
   - **Recall@K**: fraction of relevant docs retrieved in top K
   - **Precision@K**: fraction of top K that are relevant
   - **MRR**: reciprocal rank of first relevant doc
   - **NDCG@K**: normalized discounted cumulative gain
   - **Hit rate**: fraction of queries with at least one relevant doc in top K
3. **Context analysis** — Examine retrieved contexts for: relevance distribution (how many retrieved docs are actually useful), noise ratio (irrelevant docs that might confuse generation), context ordering (is the most relevant doc first).
4. **Generation evaluation** — For each query + retrieved context, run generation and score the output:
   - **Faithfulness**: Does the answer only use information from retrieved context? (No hallucination)
   - **Relevance**: Does the answer address the query?
   - **Completeness**: Does the answer cover all aspects of the golden answer?
   - **Conciseness**: Is the answer free of unnecessary information?
5. **Bottleneck identification** — Cross-reference retrieval and generation scores. Classify each failure as: retrieval failure (right answer not in context), generation failure (right context but wrong answer), or compound failure (both).
6. **Comparison** — If `--pipeline-b` is provided, run both pipelines and produce a side-by-side comparison with statistical significance tests.
7. **Report** — Produce the full evaluation report with per-stage metrics, bottleneck analysis, and improvement recommendations.

## Examples

### Full RAG evaluation
```
/eval-rag --pipeline rag/ --queries eval/queries.jsonl --golden eval/golden.jsonl --k 5

## RAG Evaluation Report

### Retrieval Metrics (K=5)
| Metric | Score |
|--------|-------|
| Recall@5 | 0.78 |
| Precision@5 | 0.41 |
| MRR | 0.72 |
| NDCG@5 | 0.68 |
| Hit Rate | 0.89 |

### Generation Metrics
| Metric | Score |
|--------|-------|
| Faithfulness | 0.91 |
| Relevance | 0.85 |
| Completeness | 0.67 |
| Conciseness | 0.88 |

### Bottleneck Analysis
| Failure Type | Count | % of Failures |
|-------------|-------|---------------|
| Retrieval failure | 31 | 58.5% |
| Generation failure | 14 | 26.4% |
| Compound failure | 8 | 15.1% |

### Recommendation
Primary bottleneck is retrieval (58.5% of failures). Focus on:
1. Improve chunking strategy — current chunks miss relevant context
2. Add hybrid search (keyword + semantic) — 12 queries failed on keyword-dependent lookups
3. Increase K to 10 for complex queries — recall jumps to 0.89 at K=10
```

## Output

```markdown
## RAG Evaluation Report

### Pipeline: <path>
### Queries: N evaluated

### Retrieval Metrics
| Metric | Score | CI |
|--------|-------|----|

### Generation Metrics
| Metric | Score | CI |
|--------|-------|----|

### Bottleneck Analysis
| Type | Count | % |
|------|-------|----|

### Per-Query Breakdown (worst N)
| Query | Retrieval | Generation | Failure Type |

### Recommendations
1. ...

### Comparison (if --pipeline-b)
| Metric | Pipeline A | Pipeline B | Delta | Significant? |
```

## Dependencies

- RAG pipeline (retrieval + generation components)
- Evaluation queries with golden answers and relevant doc IDs
- `/judge-prompt` — For custom faithfulness judges
- `/eval-audit` — Upstream pipeline health check
- `/error-analysis` — Deep-dive on failure patterns
- LLM access for generation evaluation scoring
