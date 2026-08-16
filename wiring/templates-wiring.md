# Templates super-module — wiring instructions

These changes are required in shared files that the Templates module is forbidden from editing directly. Apply them by hand (or via a follow-up agent that owns the shared files).

## 1. Phoenix router

In `backend/lib/canopy_web/router.ex`, inside the `scope "/api/v1", CanopyWeb` block (the same scope that mounts `analytics`), add:

```elixir
get "/templates", TemplatesController, :index
get "/templates/instantiations", TemplatesController, :instantiations
get "/templates/:slug", TemplatesController, :show
post "/templates", TemplatesController, :create
patch "/templates/:slug", TemplatesController, :update

post "/templates/:slug/preview", TemplatesController, :preview
post "/templates/:slug/instantiate", TemplatesController, :instantiate
post "/templates/:slug/publish", TemplatesController, :publish
post "/templates/:slug/fork", TemplatesController, :fork
get  "/templates/:slug/versions", TemplatesController, :versions
```

Order matters — the bare `/templates/instantiations` route must come **before** `/templates/:slug` so it isn't swallowed as a slug path.

## 2. Tool registration

In `backend/lib/canopy/application.ex` (or wherever `Canopy.Tools.Registry.register_module/1` is called at boot — same place that registers `Canopy.Tools.Analytics`), add:

```elixir
Canopy.Tools.Registry.register_module(Canopy.Tools.Templates)
```

If tool modules are configured via `:canopy, :tool_modules` in `config/config.exs`, append:

```elixir
config :canopy, :tool_modules, [
  Canopy.Tools.BuiltIn,
  Canopy.Tools.Analytics,
  Canopy.Tools.Templates
]
```

## 3. Sidebar navigation

In the desktop sidebar config (e.g. `desktop/src/lib/design/sidebar/config.ts` or wherever the items array lives), the `templates` entry already exists. Update its href if needed and ensure it points at `/templates`:

```ts
{
  href: "/templates",
  label: "Templates",
  icon: LayoutTemplate,
  module: "templates"
}
```

No new entry is required — the route was already in the sidebar before.

## 4. Settings sidebar

In the settings nav config (e.g. `desktop/src/routes/settings/+layout.svelte` or a `settings-nav.ts`), add an item under the same group as `Analytics`:

```ts
{
  href: "/settings/templates",
  label: "Templates",
  description: "Forge agent · publishing · default policies"
}
```

## 5. Supervisor entries

No new supervisor entries are required for this module. Forge's heartbeat is wired through the existing heartbeat scheduler — once the persona at `priv/agents/template-composer/persona.md` is loaded by the agent loader (same path as `analytics-agent`), the cron entry `"0 6 * * *"` is picked up automatically.

If the agent loader is configured in `application.ex` or `priv/agents/index.exs`, append `template-composer` to the loaded-agent list.

## 6. Frontend domain export

If `desktop/src/lib/domain/index.ts` (or equivalent re-export aggregator) exports each domain namespace, add:

```ts
export * as templates from "./templates/types.js";
```

Otherwise, callers import directly from `$lib/domain/templates/types.js`, which already works.

## 7. Migrations

Run after merge:

```bash
cd backend && mix ecto.migrate
```

Three new migrations: `20260428020001_create_templates.exs`, `20260428020002_create_template_instantiations.exs`, `20260428020003_create_template_versions.exs`.

## 8. Seed data (optional)

The four existing starter workspace folders under `backend/priv/workspace_templates/` (sales-engine, dev-shop, content-factory, blank) should be loaded into the new `templates` table as seed data. A follow-up `priv/repo/seeds/templates.exs` should iterate the folders, read each `SYSTEM.md` + `company.yaml`, and call `Canopy.Templates.create_template/1` with `kind: "workspace"`, `verified: true`, `source: "local"`.

This seed task is not part of this dispatch — flag it as a follow-up.

## 9. CI

No CI changes required. Existing `backend-test` and `desktop-test` jobs will pick up the new tests automatically.

## Verification

After wiring:

```bash
cd backend && mix test test/canopy/templates_test.exs test/canopy_web/controllers/templates_controller_test.exs
cd desktop && pnpm svelte-check
```

Both should pass with zero new failures.
