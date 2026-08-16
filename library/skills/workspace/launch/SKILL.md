---
name: launch
description: >
  One-command workspace activation from a template. Reads a TOML/YAML workspace
  template, spawns agents, assigns initial tasks, sets budgets, and bootstraps
  the full operating environment. Variable substitution for customization.
  Triggers on: "launch", "start workspace", "activate", "boot workspace"
---

# /launch

> One-command workspace activation from template.

## Purpose

Stand up a fully operational workspace in a single command. A workspace template defines everything: agents to hire, skills to enable, initial tasks, budget allocations, file structure, and configuration. Launch reads the template, provisions all resources, and starts execution. Variable substitution lets you customize templates for different projects without editing them.

## Usage

```bash
# Launch from a template
/launch templates/research-team.yaml

# Launch with variable substitution
/launch templates/project.yaml --var project_name="AI Masters" --var budget=100000

# Launch from the template library
/launch --template content-pipeline

# Preview without launching
/launch templates/research-team.yaml --dry-run

# Launch with custom budget override
/launch templates/research-team.yaml --budget 200000

# Launch and assign initial task
/launch templates/research-team.yaml --task "Research competitor pricing"
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `<template>` | positional | required | Path to template file or library name |
| `--template` | string | — | Template name from the library |
| `--var` | key=value[] | — | Variable substitution (overrides template defaults) |
| `--budget` | int | from template | Override total budget |
| `--task` | string | from template | Override or set initial task |
| `--dry-run` | flag | false | Preview what would be created |
| `--skip-approval` | flag | false | Skip hire approvals (for trusted templates) |
| `--backend` | enum | from template | Override agent backend: `subprocess`, `tmux`, `docker` |
| `--output-dir` | path | `.` | Workspace root directory |

## Workflow

1. **Load template** — Read and parse YAML/TOML template. Validate required fields.
2. **Substitute variables** — Replace `{{variable}}` placeholders with values from `--var` flags or template defaults.
3. **Create structure** — Build workspace directory structure: `agents/`, `inbox/`, `processed/`, `ops/`, `.locks/`, `approvals/`.
4. **Write SYSTEM.md** — Generate workspace system prompt from template configuration.
5. **Set budgets** — Initialize budget tracker with per-agent and project-level allocations.
6. **Hire agents** — For each agent in the template, run `/hire` (with or without approval based on `--skip-approval`).
7. **Configure skills** — Enable skills specified in the template. Copy skill definitions to workspace.
8. **Assign tasks** — Create initial tasks from template. Assign to agents based on capability matching.
9. **Start heartbeats** — Initialize heartbeat monitoring for all spawned agents.
10. **Report** — Display launch summary: what was created, agents running, tasks assigned, budget allocated.

## Output

```markdown
## Workspace Launched

**Template:** research-team
**Directory:** /workspace/ai-masters-research
**Budget:** 200,000 tokens ($15.00)

### Structure Created
```
ai-masters-research/
├── SYSTEM.md
├── agents/
│   ├── researcher/
│   ├── analyst/
│   └── writer/
├── inbox/
├── processed/
├── ops/
│   ├── observations/
│   ├── metrics/
│   └── budget/
├── .locks/
└── approvals/
```

### Agents Hired
| Agent | Role | Adapter | Budget | Status |
|-------|------|---------|--------|--------|
| researcher | Research Analyst | claude-sonnet | 80,000 | running |
| analyst | Data Analyst | claude-sonnet | 60,000 | running |
| writer | Content Writer | claude-haiku | 30,000 | running |
| unallocated | — | — | 30,000 | reserve |

### Initial Tasks
| Task | Assigned To | Priority |
|------|-------------|----------|
| Research competitor pricing | researcher | high |
| Analyze existing revenue data | analyst | high |
| Draft findings report | writer | normal (after research) |

### Ready
Workspace is live. Monitor with `/board`. Send messages with `/inbox`.
```

## Dependencies

- Template library or file system access
- `/hire` — Agent provisioning
- `/budget` — Budget initialization
- `/spawn` — Agent runtime creation
- `/heartbeat` — Monitoring setup
- `/board` — Dashboard activation
- YAML/TOML parser
