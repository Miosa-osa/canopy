# Workspace OptimalEngine

Each Canopy workspace owns its own OptimalEngine boundary. The backend resolves a workspace slug to its `root_path`, then only runs commands from that workspace's local `engine/` project and local `.canopy/engine.yaml` manifest.

## Workspace Layout

```text
workspace-root/
  .canopy/
    engine.yaml
    agents/
      conductor.md
  engine/
    mix.exs
    lib/
      mix/tasks/optimal.health.ex
      mix/tasks/optimal.impact.ex
```

## Manifest

`.canopy/engine.yaml` is the allowlist. Canopy does not run arbitrary shell commands from the UI, MCP tools, or agents.

```yaml
commands:
  health:
    task: optimal.health
    description: Check engine readiness
    args:
      - --json
  impact:
    task: optimal.impact
    description: Score strategy impact
```

Command names must be lowercase letters, numbers, hyphens, or underscores. Mix tasks must start with `optimal.`.

## API

```text
GET  /api/v1/workspaces/:slug/engine/health
GET  /api/v1/workspaces/:slug/engine/commands
POST /api/v1/workspaces/:slug/engine/run
```

Run body:

```json
{
  "command": "impact",
  "args": ["--target", "growth"],
  "timeout_ms": 60000
}
```

Canopy executes this as:

```text
cd workspace-root/engine
mix optimal.impact --target growth
```

Manifest args are inserted before runtime args.

## Agent Tool Surface

Agents and MCP clients use the same workspace-scoped boundary:

```text
workspace.engine_health
workspace.engine_commands
workspace.engine_run
```

The required input is `workspace_slug`. `workspace.engine_run` also requires `command` and accepts `args` plus `timeout_ms`.
