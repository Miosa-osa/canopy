---
name: hire
description: >
  Add an agent to a workspace from the agent library. Proposes agent configuration
  including name, role, capabilities, adapter, and budget. Requires board approval
  via /approve before onboarding. Completes with identity setup and coordination prompt.
  Triggers on: "hire", "add agent", "onboard agent", "recruit"
---

# /hire

> Add an agent to the workspace from the library — with approval.

## Purpose

Bring a new agent into the workspace by selecting from the agent library, customizing its configuration, getting human approval, and onboarding it with identity and coordination protocols. This is the formal process for adding compute capacity — every hire goes through `/approve` to prevent uncontrolled agent sprawl and budget creep.

## Usage

```bash
# Hire from library
/hire researcher

# Hire with customization
/hire researcher --name "patent-analyst" --budget 80000 --adapter claude-opus

# Browse available agents
/hire --list

# Hire with justification (for approval)
/hire writer --reason "Need pitch deck content for board meeting Friday"

# Hire multiple agents
/hire researcher analyst --parallel

# Preview what would be hired (no approval sent)
/hire researcher --dry-run
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `<agent>` | positional | required | Agent type from library (or `--list` to browse) |
| `--name` | string | from library | Custom name for this instance |
| `--role` | string | from library | Custom role description |
| `--budget` | int | from library | Token budget allocation |
| `--adapter` | enum | from library | `claude-opus`, `claude-sonnet`, `claude-haiku`, `codex`, `gemini`, `ollama` |
| `--scope` | string | from library | Workspace access scope |
| `--reason` | string | — | Justification for hiring (included in approval request) |
| `--list` | flag | false | Browse available agents in library |
| `--dry-run` | flag | false | Preview configuration without creating approval |
| `--parallel` | flag | false | Hire multiple agents simultaneously |
| `--skip-approval` | flag | false | Skip approval (for pre-approved agent types) |
| `--tasks` | string[] | — | Initial tasks to assign after onboarding |

## Workflow

1. **Select** — Look up agent in library. Load default configuration: name, role, system prompt, capabilities, default adapter, default budget, default scope.
2. **Customize** — Apply overrides from flags. Merge custom configuration with library defaults.
3. **Estimate** — Calculate expected cost based on budget allocation and adapter pricing.
4. **Propose** — Create a hire proposal summarizing: who, what they'll do, how much it costs, why they're needed.
5. **Approve** — Submit to `/approve` as `hire_agent` type. Block until resolved. If rejected, report reason and stop. If revision requested, adjust and resubmit.
6. **Provision** — On approval:
   - Create agent workspace directory
   - Write agent identity file (AGENT.md)
   - Set up inbox directory
   - Configure scope permissions
   - Register in agent registry
   - Allocate budget via `/budget`
7. **Onboard** — Spawn agent via `/spawn`. Deliver onboarding message: identity, available commands, scope boundaries, coordination protocols, initial tasks.
8. **Confirm** — Report successful hire with agent ID, status, and next steps.

## Output

### Library listing
```markdown
## Available Agents

| Name | Role | Default Adapter | Default Budget | Capabilities |
|------|------|-----------------|----------------|-------------|
| researcher | Research Analyst | claude-sonnet | 50,000 | search, read, reduce, reflect |
| writer | Content Writer | claude-sonnet | 30,000 | write, edit, translate |
| coder | Software Engineer | claude-sonnet | 100,000 | read, write, build, test, debug |
| analyst | Data Analyst | claude-sonnet | 50,000 | read, search, graph, stats |
| reviewer | Code Reviewer | claude-sonnet | 20,000 | read, review, security-scan |
| orchestrator | Team Lead | claude-opus | 150,000 | all coordination skills |
```

### Hire confirmation
```markdown
## Agent Hired

| Field | Value |
|-------|-------|
| Name | patent-analyst |
| Role | Research Analyst (customized) |
| Agent ID | agent-patent-analyst-a1b2 |
| Adapter | claude-opus |
| Budget | 80,000 tokens (~$12.00) |
| Scope | node:miosa (read-only), processed/ (read-write) |
| Approval | req-c3d4 (approved by Roberto) |
| Status | onboarded, running |
| Initial task | "Research AI patent landscape for MIOSA positioning" |

Agent is live. Monitor with `/board` or message with `/inbox send patent-analyst "..."`.
```

## Dependencies

- Agent library (agent definitions and defaults)
- `/approve` — Approval gate (required unless `--skip-approval`)
- `/spawn` — Agent runtime creation
- `/budget` — Budget allocation
- `/inbox` — Onboarding message delivery
- `/heartbeat` — Post-hire monitoring
