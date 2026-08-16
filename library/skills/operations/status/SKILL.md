# /status

> Show current system state -- active nodes, recent signals, pending items.

## Usage
```
/status [--node <name>] [--verbose]
```

## What It Does
Provides a snapshot of the current operating state: active priorities, recent signals, pending action items, and system health. Without arguments, shows a high-level overview. With `--node`, shows detailed status for a specific node.

## Implementation
1. Read `rhythm/today.md` for current priorities.
2. Scan recent signal files (last 7 days) for activity.
3. Check pending action items across all nodes.
4. Run quick health metrics (index size, last reindex time).
5. Report: priorities, recent activity, blockers, system health.

With `--verbose`: include full signal summaries and cross-references.

## Examples
```bash
# System overview
/status

# Status for a specific node
/status --node ai-masters

# Verbose output with full details
/status --verbose
```
