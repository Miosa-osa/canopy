---
name: spawn
description: >
  Launch a specialized agent for a subtask. Assigns identity, workspace scope,
  available commands, and communication protocol. Supports tmux-based (visual) or
  subprocess (headless) execution backends. The primary way to parallelize work.
  Triggers on: "spawn", "launch agent", "start worker", "parallelize"
---

# /spawn

> Launch a specialized agent for a focused subtask.

## Purpose

Create and start an agent runtime dedicated to a specific subtask. Each spawned agent gets its own identity, scoped workspace access, command allowlist, and communication channel back to the orchestrator. Use this to parallelize work, isolate concerns, or assign specialized tasks to purpose-built agents.

## Usage

```bash
# Spawn an agent from the library
/spawn researcher --task "Find pricing benchmarks for AI SaaS"

# Spawn with explicit backend
/spawn coder --backend tmux --task "Implement the search endpoint"

# Spawn with scoped workspace access
/spawn analyst --scope node:money-revenue --task "Generate Q1 revenue report"

# Spawn with budget limit
/spawn writer --budget 50000 --task "Draft the pitch deck content"

# Spawn with custom identity
/spawn --name "pricing-researcher" --role "Market Analyst" --task "Compare competitor pricing"

# Spawn multiple agents
/spawn researcher analyst writer --parallel --tasks-from plan.md
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `<agent>` | positional | required | Agent name from library, or custom with `--name` |
| `--task` | string | required | The specific task to assign |
| `--name` | string | auto | Custom agent name (overrides library name) |
| `--role` | string | from library | Role description for the agent's identity |
| `--backend` | enum | `subprocess` | `subprocess` (headless), `tmux` (visual), `docker` (isolated) |
| `--scope` | string | `full` | Workspace scope: `full`, `node:<name>`, `read-only`, glob pattern |
| `--commands` | string[] | all | Allowlisted commands (e.g., `search,read,write`) |
| `--budget` | int | from workspace | Token budget for this agent |
| `--timeout` | duration | `30m` | Maximum runtime before auto-terminate |
| `--adapter` | enum | `claude` | LLM backend: `claude`, `codex`, `gemini`, `ollama` |
| `--parallel` | flag | false | Spawn multiple agents simultaneously |
| `--tasks-from` | path | — | Read task assignments from a file |
| `--quiet` | flag | false | Suppress spawn confirmation output |

## Workflow

1. **Resolve identity** — Look up agent in library. If custom (`--name`), build identity from flags. Load agent's system prompt, capabilities, and default configuration.
2. **Configure scope** — Set workspace access boundaries. Copy or symlink allowed directories. Set file system permissions.
3. **Set budget** — Allocate token budget from workspace pool. Register with `/budget` tracker.
4. **Prepare communication** — Create inbox directory for the agent. Register message channels. Set up heartbeat monitoring.
5. **Launch runtime** — Start agent process using selected backend:
   - `subprocess`: headless process, output captured to log file
   - `tmux`: named tmux pane, visible in `/board`
   - `docker`: isolated container with mounted workspace
6. **Deliver task** — Send initial task message to agent's inbox. Include: task description, available commands, scope boundaries, budget, and expected output format.
7. **Monitor** — Register agent with heartbeat system. Log spawn event. Return agent ID and status.

## Output

```markdown
## Agent Spawned

| Field | Value |
|-------|-------|
| ID | agent-pricing-researcher-a1b2 |
| Name | pricing-researcher |
| Role | Market Analyst |
| Backend | subprocess |
| Scope | node:money-revenue, node:ai-masters (read-only) |
| Budget | 50,000 tokens |
| Timeout | 30m |
| Status | running |
| Inbox | .workspace/agents/pricing-researcher/inbox/ |
| Log | .workspace/agents/pricing-researcher/output.log |

Task delivered. Monitor with `/board` or send messages with `/inbox send pricing-researcher "..."`.
```

## Dependencies

- Agent library (for resolving agent identities)
- `/budget` — Budget allocation and tracking
- `/inbox` — Agent communication
- `/heartbeat` — Agent monitoring
- `/checkout` — Task locking (prevents double-assignment)
- tmux (for visual backend)
- Docker (for isolated backend, optional)
