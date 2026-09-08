> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Conductor bootstrap wiring

This file describes the surgical edits needed in
`backend/lib/canopy/application.ex` to bring **Conductor** (the primary chat
agent + runtime delegator for the Build cockpit) online at boot. The
bootstrap module (`Canopy.Build.Conductor`) and its tests already exist; the
only pending change is hooking three calls into the post-startup Task block —
exactly mirroring the Iris pattern.

Conductor's role: he is the user's chat partner inside the Build cockpit
(`agent_conversation` panes), and he *conducts the platform* by delegating
to runtime adapters (Claude Code, Codex, Gemini, Cursor, ...) when the user
asks for one specifically. Both modes — chatting with Conductor, and
launching a runtime directly — are first-class.

## Files already created / edited

| Path | Change |
|------|--------|
| `backend/lib/canopy/build/conductor.ex` | NEW — `hire_if_missing/0`, `register_tools/0`, `announce_online/0` |
| `backend/test/canopy/build/conductor_test.exs` | NEW — coverage for the three public functions + persona-edit preservation + first-only announce |
| `backend/priv/agents/conductor/persona.md` | EDITED — body now reflects the "primary chat agent + runtime delegator" role; tools list adds `runtimes.list` and `runtimes.suggest_for_task`; flags missing `runtime.spawn` |

## Files NOT modified (per task constraints)

- `backend/lib/canopy/application.ex` — the integration is described in this
  file rather than applied directly. The main agent owns this file.
- `backend/lib/canopy/analytics/iris.ex` — Conductor is **parallel** to Iris,
  not a refactor of it. Iris stays untouched.
- `backend/lib/canopy/build.ex` — Build context is unchanged.
- `backend/lib/canopy/heartbeat/registrar.ex` — no special wiring needed.
  Once `Conductor.hire_if_missing/0` flips `hired: true`, the existing
  `register_all_hired/0` call (already invoked from the same post-startup
  Task) picks up Conductor's `heartbeat_cron` (`0 */6 * * *`) and inserts
  an Oban job on the `:heartbeats` queue.
- `backend/lib/canopy/tools/runtime_adapter.ex` — the persona references a
  `runtime.spawn` tool that does not yet exist; only `runtimes.list`,
  `runtimes.detect_installed`, `runtimes.suggest_for_task`, etc. are present
  today. **This is a flagged gap (see "Runtime spawn gap" below).**

## Wiring lines to add

In `backend/lib/canopy/application.ex`, the post-startup Task block currently
looks like this (lines ~92–125):

```elixir
unless Application.get_env(:canopy, :env, :prod) == :test do
  Task.Supervisor.start_child(Canopy.TaskSupervisor, fn ->
    Process.sleep(500)

    case Canopy.Analytics.Iris.hire_if_missing() do
      {:ok, _agent} -> :ok
      {:error, reason} ->
        require Logger
        Logger.warning(
          "[Canopy.Application] Iris hire_if_missing failed (non-fatal): " <>
            inspect(reason)
        )
    end

    HeartbeatRegistrar.register_all_hired()
    Canopy.Tools.register_all_builtins()

    Canopy.Tools.Registry.register_module(Canopy.Tools.Analytics)
    Canopy.Tools.Registry.register_module(Canopy.Tools.Sandboxes)
    Canopy.Tools.Registry.register_module(Canopy.Tools.Schedule)
    Canopy.Tools.Registry.register_module(Canopy.Tools.Templates)
    Canopy.Tools.Registry.register_module(Canopy.Tools.SkillCurator)
    Canopy.Tools.Registry.register_module(Canopy.Tools.RuntimeAdapter)

    Canopy.Analytics.Iris.register_tools()
    Canopy.Analytics.Iris.announce_online()
  end)
end
```

Replace it with:

```elixir
unless Application.get_env(:canopy, :env, :prod) == :test do
  Task.Supervisor.start_child(Canopy.TaskSupervisor, fn ->
    Process.sleep(500)

    # Hire Iris before HeartbeatRegistrar runs so her cron is picked up
    # in the same boot pass.
    case Canopy.Analytics.Iris.hire_if_missing() do
      {:ok, _agent} -> :ok
      {:error, reason} ->
        require Logger
        Logger.warning(
          "[Canopy.Application] Iris hire_if_missing failed (non-fatal): " <>
            inspect(reason)
        )
    end

    # Hire Conductor before HeartbeatRegistrar runs so his cron is picked up
    # in the same boot pass. Conductor is the Build cockpit's primary chat
    # agent and a peer of Iris.
    case Canopy.Build.Conductor.hire_if_missing() do
      {:ok, _agent} -> :ok
      {:error, reason} ->
        require Logger
        Logger.warning(
          "[Canopy.Application] Conductor hire_if_missing failed (non-fatal): " <>
            inspect(reason)
        )
    end

    HeartbeatRegistrar.register_all_hired()
    Canopy.Tools.register_all_builtins()

    # Register the super-module tool surfaces alongside the built-ins.
    Canopy.Tools.Registry.register_module(Canopy.Tools.Analytics)
    Canopy.Tools.Registry.register_module(Canopy.Tools.Sandboxes)
    Canopy.Tools.Registry.register_module(Canopy.Tools.Schedule)
    Canopy.Tools.Registry.register_module(Canopy.Tools.Templates)
    Canopy.Tools.Registry.register_module(Canopy.Tools.SkillCurator)
    Canopy.Tools.Registry.register_module(Canopy.Tools.RuntimeAdapter)

    Canopy.Analytics.Iris.register_tools()
    Canopy.Build.Conductor.register_tools()

    Canopy.Analytics.Iris.announce_online()
    Canopy.Build.Conductor.announce_online()
  end)
end
```

### Why this ordering

1. `Iris.hire_if_missing/0` runs first (existing behavior).
2. **`Conductor.hire_if_missing/0` runs next — BEFORE
   `HeartbeatRegistrar.register_all_hired/0`.** Order is critical: the
   registrar queries `agents` with `hired: true` and would otherwise miss
   Conductor on the very first boot.
3. `register_all_hired/0` runs third — picks up Conductor's
   `heartbeat_cron` (`0 */6 * * *`) and inserts the next Oban job. Conductor
   is event-driven; the cron is a low-frequency safety net.
4. `register_all_builtins/0` runs fourth — populates the standard
   `Canopy.Tools.BuiltIn` surface.
5. The super-module `register_module` calls run fifth — Analytics, Sandboxes,
   Schedule, Templates, SkillCurator, RuntimeAdapter (existing).
6. **`Iris.register_tools/0` and `Conductor.register_tools/0` run sixth.**
   `Conductor.register_tools/0` is added directly AFTER `Iris.register_tools/0`
   (per task spec). Both are equivalent to a `register_module(Canopy.Tools.X)`
   call but flow through the agent's own bootstrap surface — keeps the
   "agent owns its tools" boundary clear.
7. **`Iris.announce_online/0` and `Conductor.announce_online/0` run last.**
   `Conductor.announce_online/0` is added directly AFTER
   `Iris.announce_online/0` (per task spec). Each posts to its own channel
   on the very first hire only.

Note: the existing wiring file `wiring/build-wiring.md` shows a single
`Canopy.Tools.Registry.register_module(Canopy.Tools.Build)` line being added
to the same block. **That single line is now superseded by
`Canopy.Build.Conductor.register_tools/0`** — they have identical effect
(both call `register_module(Canopy.Tools.Build)`), but the Conductor path
keeps tool registration with the agent that owns it. Drop the old standalone
line; do not register `Canopy.Tools.Build` twice.

### Channel `#build-feed` may not exist on first boot

`announce_online/0` is defensive: if `Channels.get("build-feed")` returns
`{:error, :not_found}` it logs an `info` line and returns `:ok`. The
`announced_online` flag is **not** set in that case, so the next boot (after
the operator creates the channel) will still post. This mirrors Iris's
treatment of `#analytics-feed` exactly.

Channel creation is the operator's responsibility — Conductor does not create
channels on his own.

### Test environment

The `unless ... :test` guard already in place keeps all calls out of the test
suite. The `conductor_test.exs` file invokes `hire_if_missing/0`,
`register_tools/0`, and `announce_online/0` directly inside the SQL Sandbox,
so no boot-time wiring is exercised in tests.

## Smoke verification (post-integration)

After applying the wiring, run these checks against a development boot:

1. **Conductor hired:**
   ```elixir
   {:ok, %{slug: "conductor", hired: true}} =
     Canopy.Agents.get_by_slug("conductor")
   ```
2. **All 12 build tools registered:**
   ```elixir
   for name <- ~w(build.open_pane build.split_pane build.close_pane
                  build.focus_pane build.suggest_layout build.save_layout
                  build.load_layout build.open_file build.open_block
                  build.run_command build.set_density build.list_layouts) do
     {:ok, _} = Canopy.Tools.Registry.lookup(name)
   end
   ```
3. **Heartbeat scheduled:**
   ```elixir
   import Ecto.Query
   from(j in Oban.Job,
     where: fragment("?->>'agent_slug' = ?", j.args, "conductor"))
   |> Canopy.Repo.one()
   ```
   Should return a scheduled job with `state == "scheduled"` and
   `scheduled_at` set to the next `0 */6 * * *` tick.
4. **Online announcement:**
   First boot (with `#build-feed` present) posts a message authored by
   Conductor to that channel. Second boot is a no-op (verified by
   `agents.config["announced_online"] == true`).

## Edge cases

- **Persona-edit preservation.** `hire_if_missing/0` deliberately does NOT
  overwrite `persona_markdown` on a re-hire if the existing row already has
  non-empty content. This protects runtime edits made via
  `Canopy.Agents.update_persona/2` from being clobbered on every boot.
  Covered by the `preserves runtime-edited persona_markdown on re-hire` test.
- **`#build-feed` channel may not exist.** `announce_online/0` logs and
  returns `:ok` if the channel is missing, and does NOT mark the agent as
  announced — the next boot will retry once the channel exists. Covered by
  the `is a clean no-op when the #build-feed channel is missing` test.
- **Test-env Oban Sandbox isolation.** The post-startup Task is suppressed
  in `:test` (existing behavior). Conductor's tests therefore call the three
  public functions directly rather than exercising the boot path.
- **Seeder collision.** `mix canopy.seed.agents` walks
  `priv/agents/conductor/persona.md` and would insert the same slug. Both
  paths are upserts keyed by `slug`, so running them in any order is safe.
- **Iris is not modified.** Conductor sits beside Iris. Both are bootstrapped
  by parallel modules with identical shape; they share nothing but the
  pattern.

## Runtime spawn gap (FLAGGED)

The persona's "Process / Methodology" section says Conductor will, when the
user asks for a specific runtime, spawn it as an embedded session inside the
active pane via `runtime.spawn`. **That tool does not yet exist.** Today
`Canopy.Tools.RuntimeAdapter` exposes only:

- `runtimes.list`, `runtimes.detect_installed`
- `runtimes.test_environment`, `runtimes.swap_adapter`
- `runtimes.update_credentials`, `runtimes.fetch_quota`
- `runtimes.suggest_for_task`, `runtimes.set_default_for_role`
- `runtimes.list_models`, `runtimes.add_alias`
- `runtimes.create_checkpoint`, `runtimes.restore_checkpoint`
- `mcp.list_servers`, `mcp.add_server`, `mcp.test_server`
- `skills.list`, `skills.attach`, `skills.fire`, `skills.audit_log`

Until `runtime.spawn` is added, Conductor falls back to `build.run_command`
to launch the runtime's CLI inside a Terminal pane. The persona body
documents this fallback explicitly. Adding `runtime.spawn` is a follow-up
ticket; it should:

1. Accept `runtime_slug`, optional `pane_id` (default: active pane), and
   optional `prompt` to seed the embedded session.
2. Route to the existing session/PTY supervisors (`Canopy.Sessions.Supervisor`,
   `Canopy.Sessions.PtySupervisor`).
3. Return an `open_pane`-shaped action so the frontend BuildDispatcher can
   honor it without a new code path.

---

## Frontend wiring — `desktop/src/routes/build/+page.svelte`

Another agent owns `+page.svelte` (it is being edited concurrently to remove
the global composer). This wiring is therefore captured here as instructions
rather than applied directly.

### Files already created

| Path | Purpose |
|------|---------|
| `desktop/src/lib/domain/conductor/types.ts` | Discriminated union for every `ConductorAction` |
| `desktop/src/lib/stores/build-dispatcher.svelte.ts` | Translates Conductor actions → `mosaicLayout` mutations |
| `desktop/src/lib/stores/build-dispatcher.test.ts` | Vitest coverage |
| `desktop/src/lib/api/queries/conductor.ts` | `subscribeToConductor(sessionId, onResult)` SSE wrapper |

### Wiring lines to add

In `desktop/src/routes/build/+page.svelte`, inside `<script lang="ts">` after
the existing imports:

```ts
import { onDestroy, onMount } from 'svelte';
import { buildDispatcher } from '$lib/stores/build-dispatcher.svelte.js';
import { subscribeToConductor } from '$lib/api/queries/conductor.js';
```

Then attach the subscription alongside the existing `defaultLayout` derivation:

```ts
let unsubscribe: (() => void) | null = null;

onMount(() => {
  // TODO: replace with the live Conductor session id once the page plumbs
  // it from the orchestrator. For now this is a no-op until a session id is
  // available — `subscribeToConductor` is safe to skip when sessionId is empty.
  const conductorSessionId = '';
  if (!conductorSessionId) return;

  unsubscribe = subscribeToConductor(conductorSessionId, (toolResult) => {
    buildDispatcher.dispatch(toolResult);
  });
});

onDestroy(() => {
  unsubscribe?.();
});
```

The edit is ~10 lines. The dispatcher is safe to import at any point — the
class instance is a plain TS singleton (no runes) with no side effects until
`dispatch` is called.

### SSE / realtime gap (FLAGGED)

The current SSE infrastructure exposes `/api/v1/sessions/:id/events` —
session-scoped, generic. There is **no Conductor-specific topic** yet. The
helper in `lib/api/queries/conductor.ts` therefore wraps `subscribeToSession`
and filters its transcript entries for Conductor-shaped tool results. Two
follow-ups are appropriate when the orchestrator tool-call path solidifies:

1. **Define the canonical wire shape.** Today the dispatcher's `normalize/1`
   accepts both a raw `ConductorAction` and a `{ tool, run_id, result }`
   wrapper. Pick one and lock it via OpenAPI.
2. **Consider a dedicated Conductor SSE topic.** A
   `/api/v1/conductor/:session_id/events` endpoint that emits ONLY tool
   results would let the frontend skip transcript filtering. Iris does not
   need this because she posts to channels, not the cockpit.
