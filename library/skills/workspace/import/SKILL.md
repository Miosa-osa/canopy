---
name: import
description: >
  Import a workspace template. Supports preview (dry-run), collision handling
  (rename/skip/replace), and secret requirements tracking. Accepts templates from
  local files, URLs, or GitHub repositories. The counterpart to /export.
  Triggers on: "import", "load template", "install workspace"
---

# /import

> Import a workspace template with collision handling and secret tracking.

## Purpose

Stand up a workspace from an exported template. Handles the full import lifecycle: preview what will be created, detect collisions with existing files, resolve conflicts, prompt for required secrets, and provision the workspace. Supports templates from local files, URLs, or GitHub repositories.

## Usage

```bash
# Import from local file
/import templates/research-team.yaml

# Import from URL
/import --url "https://example.com/templates/research-team.yaml"

# Import from GitHub
/import --github "org/repo/templates/research-team.yaml"

# Preview without importing
/import templates/research-team.yaml --dry-run

# Import with variable overrides
/import templates/research-team.yaml --var project_name="MIOSA Analysis"

# Import with collision strategy
/import templates/research-team.yaml --on-collision rename

# Import into specific directory
/import templates/research-team.yaml --target /workspace/new-project
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `<template>` | positional | — | Local file path to template |
| `--url` | string | — | URL to fetch template from |
| `--github` | string | — | GitHub path: `owner/repo/path` (uses default branch) |
| `--dry-run` | flag | false | Preview what would be created |
| `--var` | key=value[] | — | Variable overrides |
| `--on-collision` | enum | `ask` | `ask` (interactive), `rename` (suffix), `skip`, `replace` |
| `--target` | path | `.` | Target directory for workspace |
| `--skip-secrets` | flag | false | Skip secret prompts (use placeholders) |
| `--skip-launch` | flag | false | Import structure only, don't launch agents |

## Workflow

1. **Acquire** — Load template from file, URL, or GitHub. Parse and validate format.
2. **Preview** — Display what will be created: directories, agents, skills, tasks, budget. Show required variables and secrets.
3. **Resolve variables** — Apply `--var` overrides. For unresolved variables without defaults, prompt user.
4. **Resolve secrets** — Check for required secrets. If not in environment, prompt user (or skip with `--skip-secrets`).
5. **Detect collisions** — Compare template structure against target directory. Flag any conflicts:
   - File exists with different content
   - Agent name already in use
   - Skill configuration conflicts
6. **Handle collisions** — Based on `--on-collision`:
   - `ask`: prompt for each collision
   - `rename`: add suffix to conflicting items (e.g., `researcher-2`)
   - `skip`: keep existing, skip conflicting
   - `replace`: overwrite existing with template version
7. **Provision** — Create directory structure, write files, configure agents, set budgets.
8. **Launch** — Unless `--skip-launch`, run `/launch` on the imported workspace.
9. **Report** — Display import summary: created, skipped, renamed, replaced, secrets still needed.

## Output

### Dry-run preview
```markdown
## Import Preview: research-team-v2

**Source:** templates/research-team.yaml
**Target:** /workspace/miosa-analysis/

### Will Create
| Item | Type | Detail |
|------|------|--------|
| SYSTEM.md | file | Workspace system prompt |
| agents/researcher/ | directory + agent | Research Analyst (claude-sonnet, 80K budget) |
| agents/analyst/ | directory + agent | Data Analyst (claude-sonnet, 60K budget) |
| agents/writer/ | directory + agent | Content Writer (claude-haiku, 30K budget) |
| inbox/ | directory | Empty inbox |
| processed/ | directory | Empty output |
| ops/ | directory tree | observations, metrics, budget |

### Variables
| Variable | Value | Source |
|----------|-------|--------|
| project_name | "MIOSA Analysis" | --var override |
| budget | 200000 | template default |

### Secrets Required
| Secret | Status |
|--------|--------|
| ANTHROPIC_API_KEY | found in env |
| OPENAI_API_KEY | MISSING — will prompt |

### Collisions
| Item | Conflict | Resolution |
|------|----------|------------|
| agents/researcher/ | directory exists | will rename → researcher-2 |

Proceed? (y/n)
```

### Import summary
```
Imported: research-team-v2 → /workspace/miosa-analysis/
  Created: 14 items (3 agents, 5 dirs, 6 files)
  Skipped: 0
  Renamed: 1 (researcher → researcher-2)
  Replaced: 0
  Secrets: 1 still needs OPENAI_API_KEY (set env var to enable Codex adapter)
  Status: launched (3 agents running)
```

## Dependencies

- Template parser (YAML/TOML/JSON)
- Web fetch (for `--url` and `--github` sources)
- `/launch` — Workspace activation after import
- `/export` — Sister skill that produces importable templates
- File system write access to target directory
- Environment variable access (for secrets)
