# /verify

Cold-read L0 fidelity test — checks if abstracts accurately predict content.

## What It Does
Samples N contexts, takes title + L0 abstract only, scores match against full content.
Dual path: LLM prediction scoring (Ollama) or Jaccard keyword similarity (fallback).
Reports grades: A (≥0.8), B (≥0.6), C (≥0.4), D (≥0.2), F (<0.2).

## Usage
```
/verify                         # Sample 20 contexts
/verify --sample 50             # Larger sample
/verify --node ai-masters       # Specific node only
```

## Options
| Flag | Description | Default |
|------|-------------|---------|
| `--sample` | Number of contexts to test | 20 |
| `--node` | Limit to specific node | All |

## Engine Command
```bash
cd engine && mix optimal.verify
cd engine && mix optimal.verify --sample 50 --node ai-masters
```

## When to Use
- After reindexing (verify L0 quality)
- Monthly maintenance
- When search results feel irrelevant (L0 might be bad)
