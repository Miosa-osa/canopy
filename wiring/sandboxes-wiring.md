> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Sandboxes super-module wiring

This file describes the surgical edits the main agent must apply to
shared files to bring the **Sandboxes super-module** online. All
module-local files (migrations, schemas, context, tools, controller,
OpenAPI schemas, agent persona, frontend types/queries/routes, tests)
have been created. Only shared files remain.

## Files already created (no shared edits)

### Backend
| Path | Role |
|------|------|
| `backend/priv/repo/migrations/20260428000001_create_sandbox_lifecycle_events.exs` | append-only state-transition log |
| `backend/priv/repo/migrations/20260428000002_create_sandbox_snapshots.exs` | snapshot metadata + retention |
| `backend/priv/repo/migrations/20260428000003_create_sandbox_port_forwards.exs` | port forwards with active-uniqueness invariant |
| `backend/priv/repo/migrations/20260428000004_create_sandbox_alerts.exs` | alert rules |
| `backend/lib/canopy/sandboxes_ng/lifecycle_event.ex` | Ecto schema, 8-state taxonomy |
| `backend/lib/canopy/sandboxes_ng/snapshot.ex` | Ecto schema, 3-kind taxonomy |
| `backend/lib/canopy/sandboxes_ng/port_forward.ex` | Ecto schema, visibility tiers |
| `backend/lib/canopy/sandboxes_ng/alert.ex` | Ecto schema |
| `backend/lib/canopy/sandboxes_ng.ex` | context module |
| `backend/lib/canopy/tools/sandboxes.ex` | 13 `sandbox.*` tools |
| `backend/lib/canopy_web/controllers/sandboxes_ng_controller.ex` | 10 endpoints under `/api/v1/sandboxes-ng` |
| `backend/lib/canopy_web/schemas/sandboxes_ng_schema.ex` | OpenAPI schemas |
| `backend/priv/agents/sandbox-operator/persona.md` | Sandbox Operator agent persona |
| `backend/test/canopy/sandboxes_ng_test.exs` | context tests |
| `backend/test/canopy_web/controllers/sandboxes_ng_controller_test.exs` | controller tests |

### Frontend
| Path | Role |
|------|------|
| `desktop/src/lib/domain/sandboxes_ng/types.ts` | TS types (camelCased) |
| `desktop/src/lib/api/queries/sandboxes_ng.ts` | TanStack Query factories |
| `desktop/src/routes/sandboxes-ng/+page.svelte` | dashboard with 8-state grid + ports tab + snapshots + activity feed |
| `desktop/src/routes/settings/sandboxes/+page.svelte` | TTL defaults + retention + alert config |

## Namespace note

The existing `CanopyWeb.SandboxesController` reads sandbox data off the
`sessions` table and is left untouched. The new operator surface lives
under the `SandboxesNg` namespace and the `/sandboxes-ng` URL to avoid
colliding with that legacy controller and the existing
`/sandboxes` SvelteKit route.

## Shared file edits required

### 1. `backend/lib/canopy/application.ex`

No new GenServer is added in Phase A — the lifecycle events table, snapshot
table, port-forward table, and alert table are all driven by tool
invocations and controller writes, with no in-memory state to supervise.

**No edits required.** The Sandbox Operator agent's heartbeat is handled
by the existing `Canopy.Heartbeat.Registrar` via the persona's
`heartbeat.cron: "*/2 * * * *"` — once the agent is hired (via the
existing seeder or a future bootstrap module), the registrar enrolls it
automatically on the post-startup Task.

If a Phase B operator GenServer is added later (e.g. to coordinate
heartbeat sweeps in-process rather than via Oban), it should be inserted
in the supervision tree **after** `Canopy.Analytics.Breadcrumbs` (line
~54) and **before** `Canopy.Sessions.Supervisor`:

```elixir
# 9b. Sandbox Operator coordinator (optional, Phase B)
Canopy.SandboxesNg.OperatorServer,
```

### 2. `backend/lib/canopy_web/router.ex`

Add the following block **immediately after** the existing
`# Analytics — telemetry, costs, breadcrumbs, insights, alerts (Iris agent surface)`
block (the analytics routes end at line ~349 today):

```elixir
# Sandboxes (next-gen) — operator surface for Sandbox Operator agent
get "/sandboxes-ng", SandboxesNgController, :index
get "/sandboxes-ng/events", SandboxesNgController, :events
get "/sandboxes-ng/events/:sandbox_id", SandboxesNgController, :events_for_sandbox
get "/sandboxes-ng/snapshots", SandboxesNgController, :snapshots_index
post "/sandboxes-ng/snapshots", SandboxesNgController, :snapshots_create
get "/sandboxes-ng/ports", SandboxesNgController, :ports_index
post "/sandboxes-ng/ports", SandboxesNgController, :ports_create
delete "/sandboxes-ng/ports/:id", SandboxesNgController, :ports_delete
get "/sandboxes-ng/alerts", SandboxesNgController, :alerts_index
post "/sandboxes-ng/alerts", SandboxesNgController, :alerts_create
```

The existing `# MIOSA compute sandboxes` block (`/sandboxes`,
`/sandboxes/:sandbox_id`) is left in place — that controller serves the
legacy session-attached view and is now decoupled from the new operator
surface.

### 3. Tool registration — no shared file edit

The `Canopy.Tools.Sandboxes` module declares 13 tools via
`use Canopy.Tool`. They become callable by adding **one line** to the
post-startup Task in `backend/lib/canopy/application.ex` (the same block
where `Canopy.Tools.register_all_builtins()` is invoked):

```elixir
Canopy.Tools.Registry.register_module(Canopy.Tools.Sandboxes)
```

Insert this line **after** `Canopy.Tools.register_all_builtins()` so the
builtins land first and the sandbox surface is added on top. If the main
agent prefers config-driven registration, add to `:canopy, :tool_modules`
in `config/config.exs`:

```elixir
config :canopy, :tool_modules, [
  Canopy.Tools.Sandboxes
]
```

This second form requires a small addition to
`Canopy.Tools.register_all_builtins/0` to walk the config list — the
manual `Registry.register_module/1` call avoids that change and is the
recommended path for Phase A.

### 4. `desktop/src/lib/stores/sidebar-config.svelte.ts`

Add **one item** to the `COCKPIT` group's `items` array (immediately
after the existing `/sandboxes` entry on line 54). The new item points
to `/sandboxes-ng`:

```typescript
{
  path: "/sandboxes-ng",
  label: "Sandboxes (NG)",
  icon: "Box",
  hidden: false,
},
```

When the legacy `/sandboxes` route is decommissioned, this item should
take over the `Sandboxes` label and the `/sandboxes` path. For now both
appear in the sidebar so the operator surface ships side-by-side with
the existing session-attached view.

### 5. `desktop/src/routes/settings/+layout.svelte`

Add **one item** to the `NAV_ITEMS` array (after the existing
`/settings/miosa` entry on line 26):

```typescript
{ path: '/settings/sandboxes', label: 'Sandboxes', icon: 'sandboxes' },
```

The icon string `'sandboxes'` is new. Add the corresponding `{:else if}`
branch to the inline icon switch in the same file (after the
`'analytics'` branch at line 75–77):

```svelte
{:else if item.icon === 'sandboxes'}
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><polyline points="3.27 6.96 12 12.01 20.73 6.96"/><line x1="12" y1="22.08" x2="12" y2="12"/></svg>
```

## Smoke verification (post-integration)

1. **Migrations applied:**
   ```bash
   cd backend && mix ecto.migrate
   ```
   Expect 4 new tables: `sandbox_lifecycle_events`, `sandbox_snapshots`,
   `sandbox_port_forwards`, `sandbox_alerts`.

2. **Routes mounted:**
   ```bash
   curl -s http://localhost:4000/api/v1/sandboxes-ng | jq
   ```
   Expect `{"data": []}` on a fresh DB.

3. **Tools registered:**
   ```elixir
   {:ok, _} = Canopy.Tools.Registry.lookup("sandbox.list")
   {:ok, _} = Canopy.Tools.Registry.lookup("sandbox.expose_port")
   ```

4. **Agent persona seeded:** the existing `mix canopy.seed.agents` Mix
   task picks up `priv/agents/sandbox-operator/persona.md` automatically.

5. **Frontend route:** visit `/sandboxes-ng` in the desktop app — the
   8-state grid renders with all zeros, the four tabs are clickable,
   and the empty-state copy appears in each tab.

## Phase A scope and what comes next

Phase A (this delivery) ships the **operator data layer** plus the
**Codespaces-grade Ports tab UI** against Canopy's existing 5-method
MIOSA API. The `sandbox.exec`, `sandbox.read_file`, `sandbox.write_file`
tools all route through the existing `Canopy.Miosa.Client.exec/3`.

Phase B (blocked on MIOSA team) extends the surface with native
pause/resume/archive/recover/snapshot/fork/expose_port endpoints. When
those land, the corresponding tool handlers in
`backend/lib/canopy/tools/sandboxes.ex` swap their inline shell
fallbacks for direct API calls. The DB schema, tool surface, controller
routes, and frontend UI are unchanged — only the handler bodies move.

## Edge cases discovered

- **Active-uniqueness on port forwards.** The migration enforces
  `UNIQUE (sandbox_id, internal_port) WHERE closed_at IS NULL`. Two
  open forwards for the same sandbox+port are impossible. Closing a
  forward releases the slot for re-binding.
- **Public exposure is opt-in.** The controller hard-blocks
  `visibility: public` unless `confirm_public: true` is in the body.
  The agent persona's port-forward-safety rule mirrors this — the tool
  handler refuses public exposure without `confirm_public`.
- **Sandbox ID format.** MIOSA returns sandbox IDs as opaque strings;
  the controller validates them against
  `^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$` to allow common formats while
  rejecting paths/spaces/quotes that would be unsafe in subsequent
  shell commands.
- **Snapshot retention defaults.** `directory: 30 days`, `memory: 7
  days`, `filesystem: indefinite`. Set in `Canopy.SandboxesNg` and
  honoured at create-time. Pass an explicit `retention_until` to
  override.
- **Lifecycle states.** The 8-state taxonomy is the user-facing
  vocabulary; MIOSA's internal status strings will need a mapping
  layer when Phase B ships. The `payload` field on each
  `LifecycleEvent` is the place to record raw MIOSA payloads
  alongside the canonical state.
