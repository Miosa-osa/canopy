# Agent Kanban — wiring instructions

The Agent Kanban module ships as a self-contained set of files under
`backend/lib/canopy/tasks/`, `backend/lib/canopy_web/{controllers,schemas}/`,
`desktop/src/lib/design/patterns/mosaic/panes/agent-kanban/`, plus the
parent pane file `AgentKanbanPane.svelte`. The integrations below must
be applied by the agents that own the shared shells — this module never
edits them itself.

## 1. Migration

Run the migration in `backend/priv/repo/migrations/20260501010001_add_agent_kanban_fields_to_tasks.exs`.
It adds four columns to `tasks` plus a partial index on the unclaimed,
auto-assignable hot path.

```bash
mix ecto.migrate
```

Migration timestamp `20260501010001` deliberately follows the workspace
states migration `20260501000001` to avoid collision.

## 2. Router routes (`backend/lib/canopy_web/router.ex`)

Add the five routes inside the existing `scope "/api/v1", CanopyWeb`
block, alongside the Tasks routes. Order by HTTP verb to match the file
convention:

```elixir
# Agent Kanban — auto-pickup queue + manual claim/release/complete
get  "/agent-kanban/board",          AgentKanbanController, :board
get  "/agent-kanban/idle-agents",    AgentKanbanController, :idle_agents
post "/agent-kanban/claim",          AgentKanbanController, :claim
post "/agent-kanban/release/:task_id", AgentKanbanController, :release
post "/agent-kanban/complete/:task_id", AgentKanbanController, :complete
```

No new pipelines — these are public-pipeline routes, same as Tasks.

## 3. Oban cron — auto-pickup loop (`backend/config/config.exs`)

Add one entry to the existing `Oban.Plugins.Cron` `crontab` list:

```elixir
{"* * * * *", Canopy.Tasks.AutoPickup}
```

The list currently holds three entries (Budgets snapshotter, Issues lock
expiry, Routines cron runner). Append the AutoPickup entry — order does
not matter to the plugin. Default queue is `:default` with 10 concurrency,
which is the right shape for this loop (one job per minute, fans out
across hired agents in a single run).

No `application.ex` changes required: Oban itself is already supervised
and the cron plugin reads its crontab on boot. If hot-reloading is desired,
restart the Phoenix endpoint after editing config.

## 4. Pane registration

### 4.1 `desktop/src/lib/stores/mosaic-layout.svelte.ts`

Extend the `PaneKind` union with `"agent_kanban"`:

```ts
export type PaneKind =
  | "session"
  | "issue"
  | "task"
  | "doc"
  | "file"
  | "terminal"
  | "changes"
  | "knowledge"
  | "agent_conversation"
  | "agent_kanban"; // ← NEW
```

### 4.2 `desktop/src/lib/design/patterns/mosaic/PaneContent.svelte`

Add a dispatch branch for the new kind. Mirror the existing
`agent_conversation` branch — lazy import keeps the initial bundle small:

```svelte
{:else if pane.kind === 'agent_kanban'}
  {#await import('$lib/design/patterns/mosaic/panes/AgentKanbanPane.svelte')}
    <div class="pc-stub pc-stub--loading">Loading kanban…</div>
  {:then { default: AgentKanbanPane }}
    {@const cfg = (pane.config ?? {}) as { workspaceSlug?: string }}
    <AgentKanbanPane workspaceSlug={cfg.workspaceSlug ?? 'default'} />
  {:catch}
    <div class="pc-stub">Agent Kanban pane failed to load.</div>
  {/await}
```

### 4.3 `desktop/src/lib/design/patterns/mosaic/PanePicker.svelte`

Two changes:

1. Add a catalog entry so the picker surfaces it (`KANBAN_COLUMNS` order
   is canonical — keep this near the conversation entry):

   ```ts
   { id: 'p11', kind: 'agent_kanban', ref: 'default', title: 'Agent Kanban', description: 'Kanban' },
   ```

2. Extend the `KIND_LABELS` map:

   ```ts
   const KIND_LABELS: Record<PaneKind, string> = {
     // … existing entries …
     agent_kanban: 'Kanban',
   };
   ```

## 5. Cockpit / sidebar entry

Add a SECOND entry under the COCKPIT group in the main sidebar
(`desktop/src/lib/design/patterns/Sidebar.svelte` or wherever the
cockpit list is composed), positioned immediately after the Build entry.
The intent is to make the Agent Kanban a peer module of Build:

```ts
// COCKPIT
{ icon: 'workflow',  label: 'Build',         href: '/build' },
{ icon: 'kanban',    label: 'Agent Kanban',  href: '/build?pane=agent_kanban' }, // ← NEW
```

The kanban does not require its own route — it is a pane that can be
mounted into Build. If a dedicated `/agent-kanban` route is desired, it
should mount `<AgentKanbanPane workspaceSlug="default" />` directly and
share the Build chrome.

## 6. Frontend dependencies

No new packages required — the pane reuses:

- `@tanstack/svelte-query` — already in use throughout `api/queries/`
- `svelte-dnd-action` — already used in `KanbanBoard.svelte` and
  `PinnedPanel.svelte`
- `$lib/stores/toasts.svelte.js` — already in use
- `$lib/api/client.js` — `apiGet` / `apiPost` already imported across
  the codebase

## 7. Auto-pickup configuration

The auto-pickup loop only considers agents with the right config. Wire
agents into the loop by setting two keys on `agent.config`:

```elixir
%{
  "auto_pickup" => true,
  "capabilities" => ["elixir", "phoenix", "ecto"]
}
```

The frontend `IdleAgentsRail` lists exactly these agents. Tasks expose
their `required_skills` array and `auto_assignable` flag — the loop
matches `required_skills ⊆ capabilities` to decide pickups.

## 8. Backend gaps to track (NOT blockers)

The integration ships fully functional with the routes above, but two
follow-ups are worth queueing:

1. **PubSub broadcasts on claim / release / complete.** The Tasks.Dispatcher
   already publishes `tasks:workspace:<slug>` events; extending Kanban
   to publish on the same topic would let the pane refresh on neighbour
   moves without polling. Today the board uses 15-second TanStack
   refetch as a reasonable fallback.
2. **`Canopy.Agents.list_idle/0`.** The controller currently filters
   hired agents by `config["auto_pickup"]` inline. A first-class
   `list_idle/0` that combines the hired filter, the config flag, and
   an active-session count would tidy the controller and let the
   AutoPickup worker share the same query.

## 9. Constraints honoured

- No edits to `PaneContent.svelte`, `MosaicTile.svelte`, `MosaicRoot.svelte`,
  `PanePicker.svelte`, `application.ex`, `router.ex`, or `mosaic-layout.svelte.ts`
  — instructions only.
- No new dependencies.
- No competitor brand names in code or docs — the pane is "Agent Kanban".
- All Tasks API calls go through `Canopy.Tasks` / `Canopy.Tasks.Kanban`.
- Claim atomicity is the load-bearing piece — `claim_task/2` uses
  `SELECT … FOR UPDATE SKIP LOCKED` inside `Repo.transaction`, with a
  100-concurrent-claim test asserting exactly one winner.
