# /batch

> Execute multi-agent tasks using intelligent batching for token efficiency.

## Usage
```
/batch "<task>" [--max-agents <n>] [--batch-size <n>]
```

## What It Does
Analyzes task complexity, identifies required agents, groups them into optimal batches, and executes batches sequentially (agents within each batch run in parallel). Each batch gets a dedicated context window. Results are written to files and synthesized by an orchestrator. Achieves 60-77% token savings vs naive parallel execution.

## Implementation
1. **Analyze task** -- detect complexity (1-10), identify required agents.
2. **Plan batches** -- group agents into batches of 3-5 (cohesive grouping).
3. **Execute Batch 1** -- run first group, write results to `work/batch1-results.md`.
4. **Execute Batch 2** -- read Batch 1 results, run second group, write to `work/batch2-results.md`.
5. **Synthesize** -- orchestrator reads all batch results, produces final output.

| Complexity | Batch Size | Example |
|------------|------------|---------|
| 1-3 | 1-2 agents | Fix typo, add logging |
| 4-5 | 3 agents | Add API endpoint with tests |
| 6-7 | 5 agents | Build feature with frontend/backend |
| 8-10 | 8 agents | Full system redesign |

## Examples
```bash
# Full-stack feature
/batch "Build user authentication with React frontend, Go backend, and tests"

# Performance work
/batch "Optimize database queries and add caching layer"

# Security audit
/batch "Security assessment of payment processing system"
```
