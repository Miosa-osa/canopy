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

## Required compatibility preflight

Before listing commands, reporting readiness, or executing a task, Canopy verifies the workspace Engine checkout against explicit compatibility metadata.
Existing command-only manifests must be upgraded before they can execute.
The checkout must have the canonical repository identity and an explicitly approved full commit revision.
The tracked `engine-contract.json` must match the declared contract version, release range, API version, migration level, and required capabilities.
A failed preflight denies execution; presence of `mix.exs` alone is not readiness.

```yaml
compatibility:
  repository: Miosa-osa/OptimalEngine
  revision: REPLACE_WITH_REVIEWED_FULL_40_CHARACTER_COMMIT
  version: ">= 0.3.1 and < 0.4.0"
  contract_version: 1
  api_version: v1
  expected_migration: 62
  required_capabilities:
    - workspace_mix_tasks
commands:
  health:
    task: optimal.health
    args:
      - --json
```

Obtain the revision from the reviewed Engine release checkout with `git rev-parse HEAD`.
The placeholder above deliberately fails preflight; do not automatically trust whichever clone happens to be present.
Upgrade the pin only after the desired tasks pass against that exact Engine commit.
The release range alone is insufficient because two commits can share a package version.

This bridge executes Mix tasks inside the workspace Engine checkout.
It does not attach to or prove the identity of an independently running HTTP server.
OptimalEngine HTTP health reports build identity, but a separate HTTP integration must explicitly compare that identity with its approved pin before use.
Do not point the task bridge at a live private Engine store; use a dedicated workspace Engine and its own data.
Task execution is privileged local code execution within the selected workspace, not an operating-system sandbox against a malicious local owner.

The superseded `wiring/optimal-engine-integration.md` describes an older proposal, including a possible in-process dependency.
It does not override this runtime contract.
