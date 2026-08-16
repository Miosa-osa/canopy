---
name: delegate
description: >
  Assign work to a specific workspace agent or external runtime. Picks the right
  adapter (Claude for reasoning, Codex for bulk changes, Gemini for multimodal).
  Creates tasks with parent chain tracking for full delegation lineage.
  Triggers on: "delegate", "assign", "hand off", "send to agent"
---

# /delegate

> Assign work to a specific agent or runtime with adapter selection.

## Purpose

Route a task to the best available agent or runtime. Unlike `/spawn` (which creates new agents), `/delegate` assigns work to existing agents or selects the optimal adapter for the task type. Maintains a parent chain so every delegated task traces back to its origin. Handles adapter selection automatically: Claude for reasoning, Codex for bulk file changes, Gemini for multimodal inputs.

## Usage

```bash
# Delegate to a specific running agent
/delegate pricing-researcher "Also check competitor free tier limits"

# Delegate with auto-adapter selection
/delegate --auto "Refactor all API endpoints to use new auth middleware"

# Delegate to a specific adapter
/delegate --adapter codex "Update all import statements from v1 to v2 across 47 files"

# Delegate with priority
/delegate analyst "Revenue report needed for board meeting" --priority high

# Delegate with dependencies
/delegate writer "Draft announcement" --after task-123,task-456

# Delegate and wait for result
/delegate researcher "Find the answer" --sync
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `<target>` | positional | — | Agent name or ID to delegate to |
| `<task>` | positional | required | Task description |
| `--auto` | flag | false | Auto-select the best agent/adapter for the task |
| `--adapter` | enum | auto | Force adapter: `claude`, `codex`, `gemini`, `ollama` |
| `--priority` | enum | `normal` | `critical`, `high`, `normal`, `low` |
| `--after` | string[] | — | Task IDs that must complete before this starts |
| `--deadline` | duration | — | Soft deadline for completion |
| `--sync` | flag | false | Block until task completes and return result |
| `--context` | path[] | — | Files to include as context for the delegate |
| `--output-format` | string | — | Expected output format (guides the delegate) |
| `--parent` | string | auto | Parent task ID (auto-set from current context) |

## Workflow

1. **Parse task** — Extract task type, complexity estimate, and required capabilities from the description.
2. **Select target** — If `--auto`, match task requirements against available agents and adapters:
   - Reasoning-heavy → Claude (Opus for complex, Sonnet for standard)
   - Bulk file changes → Codex (parallel file editing)
   - Image/multimodal input → Gemini
   - Local/private → Ollama
   - If a running agent matches the task domain, prefer it over spawning new
3. **Create task record** — Generate task ID. Record parent chain, priority, dependencies, deadline. Write to task store.
4. **Check dependencies** — If `--after` specified, verify prerequisite tasks exist. Queue until they complete.
5. **Deliver** — Send task to target agent's inbox with full context: task description, parent chain, expected output, deadline, available commands.
6. **Track** — Register delegation event. Update `/board` status. Start deadline timer if set.
7. **Return** — In `--sync` mode, poll for completion and return result. Otherwise, return task ID for tracking.

## Output

```markdown
## Task Delegated

| Field | Value |
|-------|-------|
| Task ID | task-2026-03-20-143500-d4e5 |
| Target | pricing-researcher (agent-a1b2) |
| Adapter | claude-sonnet |
| Priority | high |
| Parent | task-2026-03-20-140000-a1b2 |
| Dependencies | none |
| Deadline | 2h |
| Status | delivered |

Track progress: `/board` or `/inbox peek pricing-researcher`
```

## Dependencies

- `/spawn` — May spawn a new agent if no suitable one exists
- `/inbox` — Delivers task messages
- `/checkout` — Locks task to prevent double-work
- `/budget` — Checks budget availability before delegating
- Agent registry (list of running agents and their capabilities)
- Adapter configurations (API keys, endpoints)
