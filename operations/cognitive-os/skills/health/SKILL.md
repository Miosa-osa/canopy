# /health

Run system health diagnostics on the knowledge base.

## What It Does
10 diagnostic checks with severity levels (:ok, :warning, :critical):

1. Orphaned contexts — zero graph edges
2. Stale signals — modified_at > 30 days
3. Missing cross-refs — multi-node contexts with incomplete routing
4. FTS/index drift — count mismatch contexts vs contexts_fts
5. Entity merge candidates — duplicate names (case-insensitive)
6. Node imbalance — nodes with >3x mean context count
7. Duplicate detection — identical titles within same node
8. Broken references — supersedes pointing to nonexistent IDs
9. Embedding coverage — ratio of vectors to total contexts
10. Quality distribution — flag if >20% have sn_ratio < 0.4

## Usage
```
/health                              # Run all 10 checks
/health --check orphaned_contexts    # Run specific check
```

## Engine Command
```bash
cd engine && mix optimal.health
```

## When to Use
- Friday review sessions
- After large batch ingestion
- When search quality feels degraded
- Monthly maintenance
