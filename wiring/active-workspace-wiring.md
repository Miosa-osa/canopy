# Active Workspace Context — Wiring

**Status:** Backend + frontend primitives delivered. Module integration is a follow-up.
**Owner:** main agent (integrates), backend + frontend agents (this dispatch wrote primitives only).

This document is the integration manifest. It tells the main agent exactly what
to wire into the rest of the application after the new files merge.

---

## 1. Backend integration

### 1a. Migration

A single new migration:

```
backend/priv/repo/migrations/20260501000001_create_workspace_states.exs
```

Creates table `workspace_states` with `(workspace_slug, key)` unique index,
JSONB `value`, and timestamps. Range reserved: `20260501000001` – `20260501000099`.

Run:
```bash
cd backend && mix ecto.migrate
```

### 1b. Router additions

Add the four state routes to `backend/lib/canopy_web/router.ex`, inside the
existing `scope "/api/v1", CanopyWeb do` block. Recommended placement: directly
after the `delete "/workspaces/:slug"` route at line 154, BEFORE the pins
routes. The placeholder param name MUST be `:workspace_slug` to match the
controller's pattern match (Phoenix uses `:slug` elsewhere — this resource
uses `:workspace_slug` so the controller can validate the format
deterministically).

```elixir
# Per-workspace dictionary store — module-agnostic state for any feature
get    "/workspaces/:workspace_slug/state",       WorkspaceStatesController, :index
get    "/workspaces/:workspace_slug/state/:key",  WorkspaceStatesController, :show
put    "/workspaces/:workspace_slug/state/:key",  WorkspaceStatesController, :put
delete "/workspaces/:workspace_slug/state/:key",  WorkspaceStatesController, :delete
```

### 1c. OpenAPI registration

If `CanopyWeb.ApiSpec` enumerates controllers explicitly, append
`CanopyWeb.WorkspaceStatesController` to its `paths/0` list. If it auto-derives
from the router, no action is needed.

### 1d. Workspace teardown

`Canopy.Workspaces.delete_workspace/1` (newly added) hard-deletes a workspace
and cascades to its state rows. This is for the "remove forever" UI action.
The existing soft-delete (`Canopy.Workspaces.delete/1`) still does NOT touch
state rows on purpose — restoring a workspace should restore its UI.

---

## 2. Frontend integration

### 2a. Tauri dialog plugin

`@tauri-apps/plugin-dialog` is **already in `desktop/package.json`** as a
dependency at `^2`. No `pnpm add` is needed. The Rust side must register the
plugin in `src-tauri/src/lib.rs`:

```rust
// In Tauri's Builder chain (verify if not already present)
.plugin(tauri_plugin_dialog::init())
```

If the Rust registration is missing, add:

```bash
cd src-tauri && cargo add tauri-plugin-dialog
```

This dispatch did NOT modify `src-tauri/`. Verify in a follow-up.

### 2b. Active workspace store

Singleton import:

```ts
import { activeWorkspace } from "$lib/stores/active-workspace.svelte.js";
```

Reactive fields: `slug`, `name`, `rootPath`, `isActive`. Mutations:
`setActive(slug)`, `syncPool(workspaces[])`. Event:
`window.dispatchEvent(new CustomEvent("workspace.changed", {detail}))`
fires on every `setActive()`.

`WorkspaceSwitcher.svelte` already calls `setActive()` and `syncPool()` —
that wiring is in this dispatch.

### 2c. Workspace state hook

```ts
import { useWorkspaceState } from "$lib/api/queries/workspace-states.js";

const layout = useWorkspaceState<MosaicTree>("mosaic.layout", DEFAULT_LAYOUT);
// layout.value is reactive ($state); layout.set(v) is debounced 500ms.
```

### 2d. New workspace dialog

`WorkspaceSwitcher.svelte`'s "+ New workspace" button now opens
`NewWorkspaceDialog`. The dialog:
1. Captures a workspace name (auto-derives slug)
2. Calls Tauri's `open({ directory: true })` for folder selection
3. POSTs to `/api/v1/workspaces` with `name + root_path`
4. Calls `activeWorkspace.setActive(new_slug)` on success

---

## 3. Module integration roadmap (TODO — follow-up dispatch)

These are deliberately NOT in this dispatch (they touch files owned by other
parallel agents). The primitives above make each integration a 5-line change.

| Module | File | Change |
|--------|------|--------|
| Build cockpit | `desktop/src/routes/build/+page.svelte` | Replace hardcoded `'default'` slug with `activeWorkspace.slug ?? 'default'` |
| Mosaic layout persist | `desktop/src/lib/stores/mosaic-layout.svelte.ts` | Use `useWorkspaceState("mosaic.layout", DEFAULT)` instead of localStorage so layouts auto-scope per workspace |
| Files page | `desktop/src/routes/files/+page.svelte` (or equivalent) | On mount, `goto` workspace's `rootPath`; subscribe to `workspace.changed` to re-route |
| Agent conversation pane | `desktop/src/lib/design/patterns/agent-detail/AgentConversationPane.svelte` | Default `cwd` arg to `activeWorkspace.rootPath ?? '~'` |
| Terminal pane | wherever portable-pty spawns | Use `activeWorkspace.rootPath` as cwd; respawn on `workspace.changed` |
| Build side rail | `desktop/src/lib/design/patterns/build/BuildSideRail.svelte` | Persist current section via `useWorkspaceState("build.sideRail.section", "code")` |

---

## 4. Per-workspace state caps — rationale

Two limits enforced in `Canopy.Workspaces.States`:

| Limit | Value | Why |
|-------|-------|-----|
| Max value bytes | 1 MB | A serialised Mosaic tree with 50 panes + per-pane prefs is < 50 KB. 1 MB gives 20× headroom for future modules (recent files, scrollback snippets) without letting a single key dominate the row. Postgres JSONB pages stay efficient. |
| Max keys per workspace | 100 | Forces module authors to namespace and consolidate (e.g. `build.density` + `build.sideRail.section` as siblings, not 50 fragmented keys). 100 is enough for every current module + 5× future growth without enabling drift. |

Both surfaces are violations as `:value_too_large` / `:too_many_keys` and the
controller maps them to HTTP 422 with the cap value in the error message.

---

## 5. API surface (4 routes)

| Method | Path | Action | Notes |
|--------|------|--------|-------|
| GET    | `/api/v1/workspaces/:workspace_slug/state` | `:index` | Returns `{workspace_slug, data: {...}}` |
| GET    | `/api/v1/workspaces/:workspace_slug/state/:key` | `:show` | Returns `{key, value}` or 404 |
| PUT    | `/api/v1/workspaces/:workspace_slug/state/:key` | `:put` | Body `{value}`. 422 on cap violations |
| DELETE | `/api/v1/workspaces/:workspace_slug/state/:key` | `:delete` | Returns `{deleted, workspace_slug, key}` |

All routes validate slug + key against the analytics-style regex
(`[a-z0-9][a-z0-9._-]{0,127}` for keys; standard slug for workspaces).
Path-traversal via `key` is impossible — slashes are rejected by the regex.

---

## 6. Files created / edited in this dispatch

### Created (backend)
- `backend/priv/repo/migrations/20260501000001_create_workspace_states.exs`
- `backend/lib/canopy/workspaces/state.ex`
- `backend/lib/canopy/workspaces/states.ex`
- `backend/lib/canopy_web/controllers/workspace_states_controller.ex`
- `backend/lib/canopy_web/schemas/workspace_states_schema.ex`
- `backend/test/canopy/workspaces/states_test.exs`
- `backend/test/canopy_web/controllers/workspace_states_controller_test.exs`

### Edited (backend)
- `backend/lib/canopy/workspaces.ex` — added `delete_workspace/1` cascade

### Created (frontend)
- `desktop/src/lib/stores/active-workspace.svelte.ts`
- `desktop/src/lib/api/queries/workspace-states.ts`
- `desktop/src/lib/design/patterns/workspace/NewWorkspaceDialog.svelte`
- `desktop/src/lib/stores/active-workspace.test.ts`
- `desktop/src/lib/api/queries/workspace-states.test.ts`
- `desktop/src/lib/design/patterns/workspace/NewWorkspaceDialog.test.ts`

### Edited (frontend)
- `desktop/src/lib/design/patterns/WorkspaceSwitcher.svelte` — wired
  `+ New workspace` button to `NewWorkspaceDialog`, kept `activeWorkspace`
  in sync via `syncPool()` and `setActive()` on selection.
