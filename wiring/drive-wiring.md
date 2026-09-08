> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Drive super-module — wiring instructions

These changes are required in shared files that the Drive module is forbidden from editing directly. Apply them by hand (or via a follow-up agent that owns the shared files).

## 1. Phoenix router

In `backend/lib/canopy_web/router.ex`, inside the `scope "/api/v1", CanopyWeb` block (the same scope that mounts `analytics`), add:

```elixir
# Drive super-module — typed knowledge entries (folders / workflows /
# prompts / notebooks / env vars / mcp servers / rules) at Personal | Team
# scope. Powered by the Vault curator agent.
get  "/drive",                 DriveController, :index
post "/drive",                 DriveController, :create
get  "/drive/tree",            DriveController, :tree
get  "/drive/search",          DriveController, :search
post "/drive/reorder",         DriveController, :reorder
get  "/drive/:id",             DriveController, :show
patch "/drive/:id",            DriveController, :update
post "/drive/:id/archive",     DriveController, :archive
post "/drive/:id/restore",     DriveController, :restore
post "/drive/:id/move",        DriveController, :move
```

**Order matters** — the bare `/drive/tree`, `/drive/search`, and `/drive/reorder` routes must come **before** `/drive/:id` so they aren't swallowed as `:id` paths.

## 2. Tool registration

In `backend/lib/canopy/application.ex` (right next to where `Canopy.Tools.Analytics` is registered, currently around lines 115-120), append:

```elixir
Canopy.Tools.Registry.register_module(Canopy.Tools.Drive)
```

If tool modules are configured via `:canopy, :tool_modules` in `config/config.exs`, append `Canopy.Tools.Drive` to that list.

## 3. Sidebar navigation — swap Knowledge → Drive

In `desktop/src/lib/stores/sidebar-config.svelte.ts`, find the `SYSTEM` section currently containing the `Knowledge` entry (around line 127):

```ts
{
  path: "/knowledge",
  label: "Knowledge",
  icon: "BookOpen",
  hidden: false,
},
```

Replace it with:

```ts
{
  path: "/drive",
  label: "Drive",
  icon: "FolderTree",
  hidden: false,
},
```

The Drive super-module subsumes the previous Knowledge surface — same slot in the SYSTEM group, just rebranded with a tree-style icon. The `/knowledge` route can stay for now (deep links from old emails will still work) but should be removed in a follow-up sweep.

## 4. Settings sidebar

In the settings nav config (e.g. `desktop/src/routes/settings/+layout.svelte`), add an item under the same group as `Analytics`:

```ts
{
  href: "/settings/drive",
  label: "Drive",
  description: "Default scope · archive retention · sharing · Vault curator"
}
```

## 5. Supervisor entries

No new supervisor entries are required for this module. Vault's heartbeat is wired through the existing heartbeat scheduler — once the persona at `priv/agents/drive-curator/persona.md` is loaded by the agent loader (same path as `analytics-agent`), the cron entry `"0 */6 * * *"` is picked up automatically.

If the agent loader is configured in `application.ex` or `priv/agents/index.exs`, append `drive-curator` to the loaded-agent list.

## 6. Frontend domain export

If `desktop/src/lib/domain/index.ts` (or equivalent re-export aggregator) exports each domain namespace, add:

```ts
export * as drive from "./drive/types.js";
```

Otherwise, callers import directly from `$lib/domain/drive/types.js`, which already works.

## 7. Migrations

Run after merge:

```bash
cd backend && mix ecto.migrate
```

One new migration: `20260430000001_create_drive_entries.exs`.

## 8. Seed data (optional, follow-up)

Phase A ships an empty Drive. Phase B should seed each new workspace with a starter tree:

- `/Personal/Prompts/` (folder)
- `/Personal/Notebooks/` (folder)
- `/Team/Workflows/` (folder)
- `/Team/Rules/` (folder)
- A "Welcome" rule entry pointing at the `orchestrator-agent`

Add as `priv/repo/seeds/drive.exs` or load on first workspace creation in `Canopy.Workspaces`.

## 9. CI

No CI changes required. Existing `backend-test` and `desktop-test` jobs will pick up the new tests automatically.

## Verification

After wiring:

```bash
cd backend && mix test test/canopy/drive_test.exs test/canopy_web/controllers/drive_controller_test.exs
cd desktop && pnpm svelte-check
```

Both should pass with zero new failures.

## Architecture note — primitives reused

Drive is a **shell** over typed primitives. New sub-tables were created **only** for the two kinds that introduce genuinely new content:

| kind         | primitive reused                                      | new table? |
|--------------|-------------------------------------------------------|------------|
| `folder`     | (none — organizational only)                          | no         |
| `workflow`   | `Canopy.Routines.Routine` via `routine_id`            | no         |
| `prompt`     | (new — body lives in `drive_entries.body`)            | **yes**    |
| `notebook`   | `Canopy.Sessions.Block` via `session_id` + `block_ids`| no         |
| `env_vars`   | `Canopy.Vault` via `vault_secret_ids`                 | no         |
| `mcp_server` | MCP registry via `mcp_server_id` (Phase B)            | no         |
| `rule`       | (new — body lives in `drive_entries.body`)            | **yes**    |

`prompt` and `rule` keep their content in the polymorphic `body` jsonb column on `drive_entries`. No parallel tables were created for any of the link kinds.
