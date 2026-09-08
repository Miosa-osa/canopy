> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Iris bootstrap wiring

This file describes the surgical edits needed in
`backend/lib/canopy/application.ex` to bring **Iris** (the Analytics Agent)
online at boot. The bootstrap module
(`Canopy.Analytics.Iris`) and its tests already exist; the only pending change
is hooking three calls into the post-startup Task block.

## Files already created / edited

| Path | Change |
|------|--------|
| `backend/lib/canopy/analytics/iris.ex` | NEW — `hire_if_missing/0`, `register_tools/0`, `announce_online/0` |
| `backend/test/canopy/analytics/iris_test.exs` | NEW — coverage for the three public functions |

## Files NOT modified (per task constraints)

- `backend/lib/canopy/application.ex` — the integration is described in this
  file rather than applied directly. The main agent owns this file.
- `backend/priv/repo/seeds.exs` — Iris is seeded by the existing
  `mix canopy.seed.agents` Mix task (it already walks
  `priv/agents/analytics-agent/persona.md`). Boot-time `hire_if_missing/0`
  ensures `hired: true` in the absence of a manual seed run, so no edit is
  required.
- `backend/lib/canopy/heartbeat/registrar.ex` — no special wiring needed.
  Once `Canopy.Analytics.Iris.hire_if_missing/0` flips `hired: true` on the
  agent row, the existing `register_all_hired/0` call (already invoked from
  the same post-startup Task) picks up Iris's `heartbeat_cron`
  (`0 */4 * * *`) and inserts an Oban job on the `:heartbeats` queue. From
  there the existing `Canopy.Heartbeat.Worker` self-rescheduling chain
  takes over.
- `backend/lib/canopy/tools.ex` — the analytics tools live in their own
  module (`Canopy.Tools.Analytics`) and are registered via
  `Canopy.Analytics.Iris.register_tools/0`. The `Canopy.Tools.BuiltIn`
  surface stays untouched.

## Wiring lines to add

In `backend/lib/canopy/application.ex`, locate the post-startup Task block
(currently around line 87–92):

```elixir
unless Application.get_env(:canopy, :env, :prod) == :test do
  Task.Supervisor.start_child(Canopy.TaskSupervisor, fn ->
    Process.sleep(500)
    HeartbeatRegistrar.register_all_hired()
    Canopy.Tools.register_all_builtins()
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
      {:ok, _agent} ->
        :ok

      {:error, reason} ->
        require Logger

        Logger.warning(
          "[Canopy.Application] Iris hire_if_missing failed (non-fatal): " <>
            inspect(reason)
        )
    end

    HeartbeatRegistrar.register_all_hired()
    Canopy.Tools.register_all_builtins()

    # Register Iris's analytics tool surface alongside the built-ins.
    Canopy.Analytics.Iris.register_tools()

    # Best-effort online announcement to #analytics-feed.
    # Idempotent: only posts on the very first hire.
    Canopy.Analytics.Iris.announce_online()
  end)
end
```

### Why this ordering

1. `hire_if_missing/0` runs **first** — it must complete before
   `HeartbeatRegistrar.register_all_hired/0` so the new `hired: true` row is
   visible to the registrar's query.
2. `register_all_hired/0` runs **second** — picks up Iris's
   `heartbeat_cron` and inserts the next Oban job.
3. `register_all_builtins/0` runs **third** — populates the standard
   `Canopy.Tools.BuiltIn` surface.
4. `Iris.register_tools/0` runs **fourth** — adds the six
   `analytics.*` tools to the same in-memory registry.
5. `Iris.announce_online/0` runs **last** — posts to `#analytics-feed`
   only on the first hire (state tracked via
   `agents.config["announced_online"]`).

### Test environment

The `unless ... :test` guard already in place keeps all five calls out of
the test suite, matching the existing pattern. The `iris_test.exs` test
file invokes `hire_if_missing/0` and `register_tools/0` directly inside
the SQL Sandbox, so no boot-time wiring is exercised in tests.

## Smoke verification (post-integration)

After applying the wiring, run these checks against a development boot:

1. **Iris hired:**
   ```elixir
   {:ok, %{slug: "analytics-agent", hired: true}} =
     Canopy.Agents.get_by_slug("analytics-agent")
   ```
2. **Tools registered:**
   ```elixir
   {:ok, _} = Canopy.Tools.Registry.lookup("analytics.query_telemetry")
   ```
3. **Heartbeat scheduled:**
   ```elixir
   import Ecto.Query
   from(j in Oban.Job,
     where: fragment("?->>'agent_slug' = ?", j.args, "analytics-agent"))
   |> Canopy.Repo.one()
   ```
   Should return a scheduled job with `state == "scheduled"` and
   `scheduled_at` set to the next `0 */4 * * *` tick.
4. **Online announcement:**
   First boot posts a message authored by Iris to `#analytics-feed`. Second
   boot is a no-op (verified by `agents.config["announced_online"] == true`).

## Edge cases discovered

- **Persona-edit preservation.** `hire_if_missing/0` deliberately does NOT
  overwrite `persona_markdown` on a re-hire if the existing row already has
  non-empty content. This protects runtime edits made via
  `Canopy.Agents.update_persona/2` from being clobbered on every boot.
- **`#analytics-feed` channel may not exist.** `announce_online/0` logs and
  returns `:ok` if the channel is missing. Channel creation is the
  operator's responsibility — Iris does not create channels on her own.
- **Test-env Oban Sandbox isolation.** The post-startup Task is suppressed
  in `:test` (existing behavior). Iris's tests therefore call
  `hire_if_missing/0` and `register_tools/0` directly rather than
  exercising the boot path.
- **Seeder collision.** `mix canopy.seed.agents` walks
  `priv/agents/analytics-agent/persona.md` and inserts the same slug. Both
  paths are upserts keyed by `slug`, so running them in any order is safe.
