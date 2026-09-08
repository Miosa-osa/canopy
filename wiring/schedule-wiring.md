> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Schedule super-module — wiring instructions

These edits attach the new Schedule super-module to existing shared files.
The agent that built the module did NOT modify any of these — apply by hand.

---

## 1. `backend/lib/canopy/application.ex`

Add the Dispatcher GenServer to the supervision tree, and register the
Schedule tools at boot.

### Supervisor children — insert after the `Canopy.Analytics.Breadcrumbs` line (around line 54):

```elixir
      # 9aa. Schedule Dispatcher — periodic evaluator that scans active specs,
      #      marks late/missed runs, and emits :canopy.schedule.* telemetry.
      #      Wraps Canopy.Heartbeat.Worker (Oban) — does not replace it.
      Canopy.Schedule.Dispatcher,
```

### Tool registration — extend the boot Task block (around line 88):

The current block calls `Canopy.Tools.register_all_builtins()`. Add a
follow-up call so the Schedule tool surface is registered alongside the
built-ins. Locate this region:

```elixir
        Task.Supervisor.start_child(Canopy.TaskSupervisor, fn ->
          Process.sleep(500)
          HeartbeatRegistrar.register_all_hired()
          Canopy.Tools.register_all_builtins()
        end)
```

Append (inside the same `fn ->` block, after `register_all_builtins()`):

```elixir
          Canopy.Tools.Registry.register_module(Canopy.Tools.Schedule)
```

---

## 2. `backend/lib/canopy_web/router.ex`

Add Schedule routes inside the `/api/v1` scope (the same scope that already
contains `/analytics/*`). Insert immediately after the analytics block
(around line 349, right before the closing `end` of the scope):

```elixir
    # Schedule — specs, runs, overlaps, alerts (Scheduling Agent surface)
    get "/schedule/specs", ScheduleController, :specs_index
    post "/schedule/specs", ScheduleController, :specs_create
    get "/schedule/specs/:slug", ScheduleController, :specs_show
    patch "/schedule/specs/:slug", ScheduleController, :specs_update
    post "/schedule/specs/:slug/pause", ScheduleController, :specs_pause
    post "/schedule/specs/:slug/unpause", ScheduleController, :specs_unpause
    delete "/schedule/specs/:slug", ScheduleController, :specs_archive

    get "/schedule/runs", ScheduleController, :runs_index
    get "/schedule/runs/aggregate", ScheduleController, :runs_aggregate

    get "/schedule/overlaps", ScheduleController, :overlaps_index

    get "/schedule/alerts", ScheduleController, :alerts_index
    post "/schedule/alerts", ScheduleController, :alerts_create
    post "/schedule/alerts/:slug/close", ScheduleController, :alerts_close
    post "/schedule/alerts/:slug/ack", ScheduleController, :alerts_acknowledge
```

If `ScheduleController` is not aliased near the top of the router, also
add it (look for the `alias CanopyWeb.AnalyticsController` line — if there
isn't one, the router likely uses fully-qualified names; either approach
works, just stay consistent with adjacent controllers).

---

## 3. `desktop/src/lib/stores/sidebar-config.svelte.ts`

The sidebar already has a `/schedule` entry under the `WORKSPACE` section
(verified at lines 97–102). No change required for the main nav. If you
want a badge for open incidents, extend the existing entry:

```ts
{
  path: "/schedule",
  label: "Schedule",
  icon: "Calendar",
  // Badge for open incidents — wire to Schedule alerts query
  // badge: openIncidentCount,
  hidden: false,
},
```

The badge wiring belongs in the sidebar component that consumes this
config, not in the config file itself.

---

## 4. `desktop/src/routes/settings/+layout.svelte`

Add a Schedule entry to `NAV_ITEMS` (around line 19). Insert after the
`/settings/governance` line:

```ts
{ path: '/settings/schedule', label: 'Schedule', icon: 'schedule' },
```

Then add an SVG icon block in the icon switch (around line 75, alongside
the existing `analytics` icon block):

```svelte
{:else if item.icon === 'schedule'}
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
```

---

## Verification checklist

After applying all four wiring edits:

- [ ] `cd backend && mix ecto.migrate` runs the four schedule migrations
      (timestamps `20260428010001` through `20260428010004`).
- [ ] `cd backend && mix compile --warnings-as-errors` is clean.
- [ ] `cd backend && mix test test/canopy/schedule_test.exs` passes (~25 tests).
- [ ] `cd backend && mix test test/canopy_web/controllers/schedule_controller_test.exs` passes (~25 tests).
- [ ] Visit `/schedule` in the desktop app — empty state renders without 404.
- [ ] Visit `/settings/schedule` — settings nav item is visible and the
      page loads with the Scheduling Agent status card.
- [ ] `curl http://localhost:9190/api/v1/schedule/specs` returns
      `{"data": []}`.
- [ ] OpenAPI spec at `/api/v1/openapi` contains the new `schedule.*` paths.
