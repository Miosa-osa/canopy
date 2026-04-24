---
name: batch
description: "Execute multi-agent tasks using intelligent batching for token efficiency. Analyzes task complexity, groups required agents into optimal batches, executes batches sequentially with parallel agents within each batch, and synthesizes results. Achieves 60–77% token savings vs naive parallel execution. Use when orchestrating complex tasks that require multiple agents working in coordinated phases."
user-invocable: true
triggers:
  - batch
  - batch agents
  - multi-agent task
  - parallel agents
  - batch execution
  - orchestrate agents
---

# /batch

> Execute multi-agent tasks using intelligent batching for token efficiency.

## Usage

```bash
/batch "<task>" [--max-agents <n>] [--batch-size <n>]
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `"<task>"` | string | required | Task description for the agent swarm |
| `--max-agents` | int | `8` | Maximum agents to involve |
| `--batch-size` | int | `3-5` | Agents per batch (auto-tuned by complexity) |

## Workflow

1. **Analyze task** — detect complexity (1–10), identify required agents.
2. **Plan batches** — group agents into batches of 3–5 (cohesive grouping).
3. **Execute Batch 1** — run first group, write results to `work/batch1-results.md`.
4. **Execute Batch 2** — read Batch 1 results, run second group, write to `work/batch2-results.md`.
5. **Synthesize** — orchestrator reads all batch results, produces final output.

| Complexity | Batch Size | Example |
|------------|------------|---------|
| 1–3 | 1–2 agents | Fix typo, add logging |
| 4–5 | 3 agents | Add API endpoint with tests |
| 6–7 | 5 agents | Build feature with frontend/backend |
| 8–10 | 8 agents | Full system redesign |

## Examples

```bash
# Full-stack feature
/batch "Build user authentication with React frontend, Go backend, and tests"

# Performance work
/batch "Optimize database queries and add caching layer"

# Security audit
/batch "Security assessment of payment processing system"
```

## Output

```markdown
## Batch Execution Complete

- **Task complexity**: 6/10
- **Agents used**: 5 (2 batches)
- **Token savings**: ~68% vs parallel

### Batch 1 (Frontend + API)
- frontend-developer: Built auth components (3 files)
- api-engineer: Created auth endpoints (2 routes)
- schema-designer: Defined User model + migrations

### Batch 2 (Testing + Review)
- test-engineer: 12 tests passing (unit + integration)
- code-reviewer: 2 suggestions applied

### Final Output
Authentication system ready. See `work/synthesis.md` for full details.
```
