---
name: export
description: >
  Export a workspace as a portable template. Captures SYSTEM.md, agent definitions,
  skills, reference files, configuration, seed tasks, and budget defaults. Handles
  secret stripping and collision metadata for clean import elsewhere.
  Triggers on: "export", "save template", "package workspace", "share workspace"
---

# /export

> Export workspace as a portable, shareable template.

## Purpose

Package a running workspace into a reusable template that can be imported elsewhere. Captures the full workspace definition — agents, skills, configuration, seed tasks, budget defaults — while stripping secrets and environment-specific paths. The exported template is self-contained and portable: anyone with `/import` can stand up an identical workspace.

## Usage

```bash
# Export current workspace
/export

# Export to specific file
/export --output templates/my-research-team.yaml

# Export with custom name
/export --name "research-team-v2"

# Export only structure (no tasks, no data)
/export --structure-only

# Export including sample data
/export --include-samples

# Preview what would be exported
/export --dry-run
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--output` | path | `./exported-{name}-{date}.yaml` | Output file path |
| `--name` | string | workspace name | Template name |
| `--description` | string | — | Template description |
| `--structure-only` | flag | false | Export structure without tasks or data |
| `--include-samples` | flag | false | Include sample data for reference |
| `--strip-secrets` | flag | true | Remove API keys, tokens, credentials |
| `--dry-run` | flag | false | Preview export without writing |
| `--format` | enum | `yaml` | `yaml`, `toml`, `json` |

## Workflow

1. **Inventory** — Scan workspace directory structure. Identify: SYSTEM.md, agent definitions, skill configs, reference files, seed tasks, budget configuration, variables.
2. **Classify** — For each item, determine: exportable (include), secret (strip), environment-specific (templatize), data (exclude unless `--include-samples`).
3. **Strip secrets** — Replace API keys, tokens, and credentials with `{{SECRET_NAME}}` placeholders. Log which secrets need to be provided on import.
4. **Templatize paths** — Replace absolute paths with `{{workspace_root}}` variables. Replace project-specific names with `{{project_name}}`.
5. **Capture agents** — For each agent: name, role, adapter, default budget, system prompt (stripped of secrets), capabilities.
6. **Capture skills** — List enabled skills with their configuration overrides.
7. **Capture tasks** — If not `--structure-only`, include seed tasks with priorities and assignments.
8. **Package** — Write to template file in requested format. Include metadata: export date, source workspace, version, required variables, required secrets.
9. **Validate** — Parse the exported template to confirm it's valid and importable.

## Output

### Exported template (YAML)
```yaml
# Workspace Template: research-team-v2
# Exported: 2026-03-20
# Source: /workspace/ai-masters-research

name: research-team-v2
description: "3-agent research team for competitive analysis"
version: "1.0"
exported_at: 2026-03-20T14:30:00Z

variables:
  project_name:
    description: "Name of the project"
    default: "Research Project"
  budget:
    description: "Total token budget"
    default: 200000

secrets_required:
  - ANTHROPIC_API_KEY
  - OPENAI_API_KEY  # for Codex adapter

structure:
  - agents/
  - inbox/
  - processed/
  - ops/observations/
  - ops/metrics/
  - ops/budget/

agents:
  - name: researcher
    role: "Research Analyst"
    adapter: claude-sonnet
    budget: "{{budget * 0.4}}"
    capabilities: [search, read, reduce, reflect]
    system_prompt: |
      You are a research analyst focused on {{project_name}}.
      ...

  - name: analyst
    role: "Data Analyst"
    adapter: claude-sonnet
    budget: "{{budget * 0.3}}"
    capabilities: [read, search, graph, stats]

  - name: writer
    role: "Content Writer"
    adapter: claude-haiku
    budget: "{{budget * 0.15}}"
    capabilities: [write, edit, translate]

skills:
  - processing/reduce
  - processing/reflect
  - analysis/graph
  - analysis/stats
  - learning/remember

seed_tasks:
  - task: "Research {{project_name}} competitive landscape"
    assign: researcher
    priority: high
  - task: "Analyze existing data"
    assign: analyst
    priority: high
    after: [0]

budget:
  total: "{{budget}}"
  alert_threshold: 0.8
  hard_ceiling: 1.0
```

### Export summary
```
Exported: research-team-v2 → templates/my-research-team.yaml
  Agents: 3
  Skills: 5
  Seed tasks: 2
  Variables: 2 (project_name, budget)
  Secrets required: 2 (ANTHROPIC_API_KEY, OPENAI_API_KEY)
  Size: 4.2 KB
```

## Dependencies

- Workspace file system access (read)
- YAML/TOML/JSON serializer
- Secret detection patterns (API key formats, token patterns)
- `/launch` — Exported templates are consumed by launch
- `/import` — Sister skill for importing
