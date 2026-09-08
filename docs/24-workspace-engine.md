# Workspace OptimalEngine

Each Canopy workspace owns its own OptimalEngine boundary.
The backend resolves a workspace slug to its `root_path`, then only runs commands from that workspace's local `engine/` project and local `.canopy/engine.yaml` manifest.

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

## Manifest and approved checkout

The local bridge accepts only commands declared in `.canopy/engine.yaml` whose task names begin with `optimal.`.
Command names use lowercase letters, numbers, hyphens, or underscores.
A manifest needs both an explicit compatibility pin and a command allowlist; the complete example appears below.
A command-only manifest fails preflight.
This restriction applies to this bridge, not to every terminal or tool in Canopy.
An allowed Mix task is privileged local Elixir code and can perform actions beyond its command name.

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
The checkout must be a real workspace-local Git repository, with the canonical origin URL and an explicitly approved full commit revision.
Symlinked checkout roots, a parent repository masquerading as the checkout, dirty tracked files, and non-ignored untracked files fail the check.
The tracked `engine-contract.json` must match the declared contract version, release range, API version, migration level, and required capabilities.
The migration comparison is between declared metadata; it is not a live database migration inspection.
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
    args: []
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

The superseded [Engine integration proposal](../wiring/optimal-engine-integration.md) describes an older proposal, including a possible in-process dependency.
It does not override this runtime contract.

The Engine health task returns human-readable diagnostics in stdout.
Canopy wraps stdout, stderr, exit code, and duration in a JSON execution result; task stdout itself is not guaranteed to be JSON.

## Evidence and trust boundaries

[Compatibility preflight](../backend/lib/canopy/workspaces/engine/compatibility.ex) runs before project loading or task execution.
[Workspace tests](../backend/test/canopy/workspaces/engine_test.exs) cover changed revisions, symlink substitution, dirty tracked code, missing pins, API drift, migration mismatch, release mismatch, and missing capabilities.
[Controller tests](../backend/test/canopy_web/controllers/workspace_engine_controller_test.exs) and [tool tests](../backend/test/canopy/tools/workspace_engine_test.exs) exercise the API and agent-facing routes.
Run the commands in [the control-plane retest guide](agent-control-plane.md#retest-commands).

Health exposes `available` and `compatibility_error` in the backend response; the frontend conversion layer presents `compatibilityError`.
The Engine UI displays the preflight reason rather than treating the presence of a manifest and `mix.exs` as sufficient readiness.

The reviewed pin and local workspace configuration are trusted inputs.
Static Git and contract checks do not attest loaded BEAM modules, ignored build artifacts, dependency caches, process environment, or a separately running HTTP service.
They also do not provide an atomic lock against a local owner changing files after preflight.
Runtime identity checks and isolation must be implemented and tested separately if those stronger guarantees are required.
A passed preflight therefore means compatible declared local source, not universal runtime attestation.
