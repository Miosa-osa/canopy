# Build super-super-module — wiring instructions

These edits attach the new **Build super-super-module** to existing shared
files. The agent that built the module did NOT modify any of these — apply
by hand.

Build is the agentic development cockpit at `/build`. It is a **composition
only** layer — it reuses the existing Mosaic, Composer, Block Stream,
Code Editor, File Viewer, Diff, Terminal, and MCP primitives without
reimplementing any of them. The runtime agent is **Conductor**.

---

## 1. `backend/lib/canopy/application.ex`

Register the Conductor's tool surface alongside the other super-module
tool modules. Locate the boot Task block (around line 112–120) that calls
`Canopy.Tools.register_all_builtins/0` and registers Analytics / Sandboxes /
Schedule / Templates / SkillCurator / RuntimeAdapter:

```elixir
          Canopy.Tools.register_all_builtins()

          # Register the super-module tool surfaces alongside the built-ins.
          Canopy.Tools.Registry.register_module(Canopy.Tools.Analytics)
          Canopy.Tools.Registry.register_module(Canopy.Tools.Sandboxes)
          Canopy.Tools.Registry.register_module(Canopy.Tools.Schedule)
          Canopy.Tools.Registry.register_module(Canopy.Tools.Templates)
          Canopy.Tools.Registry.register_module(Canopy.Tools.SkillCurator)
          Canopy.Tools.Registry.register_module(Canopy.Tools.RuntimeAdapter)
```

Append one line to the same `fn ->` block, after the existing `register_module`
calls:

```elixir
          Canopy.Tools.Registry.register_module(Canopy.Tools.Build)
```

No supervisor children to add — Build has no GenServer (it is purely a
context module + tool surface; pane creation runs client-side).

---

## 2. `backend/lib/canopy_web/router.ex`

Add 8 Build routes inside the `/api/v1` scope. Insert after the analytics
block (around line 351, right after `analytics/alerts` is created):

```elixir
    # Build — saved layouts, suggestions, defaults (Conductor agent surface)
    get "/build/layouts", BuildController, :list_layouts
    post "/build/layouts", BuildController, :create_layout
    get "/build/layouts/:slug", BuildController, :show_layout
    patch "/build/layouts/:slug", BuildController, :update_layout
    delete "/build/layouts/:slug", BuildController, :archive_layout
    post "/build/suggest", BuildController, :suggest_layout
    get "/build/default", BuildController, :default_layout
    post "/build/layouts/:slug/set-default", BuildController, :set_default
```

The router uses unqualified controller names everywhere else in the
`scope "/api/v1", CanopyWeb` block — no alias change required.

---

## 3. `desktop/src/lib/stores/sidebar-config.svelte.ts`

Insert Build at the **TOP of the COCKPIT group** — Build is the primary
cockpit. Modify `defaultConfig.groups[0].items` to lead with:

```ts
{ path: "/build", label: "Build", icon: "Wrench", hidden: false },
```

Result (first three entries of COCKPIT, around lines 33–46):

```ts
{
  label: "COCKPIT",
  items: [
    { path: "/build", label: "Build", icon: "Wrench", hidden: false },
    {
      path: "/runtimes",
      label: "Runtimes",
      icon: "Monitor",
      hidden: false,
    },
    // …existing items…
  ],
},
```

`Wrench` is a standard lucide icon. If `Sidebar.svelte`'s local icon map
doesn't yet expose it, add one line to that map next to the existing
`Monitor` entry. (Most lucide icons are already exposed there.)

---

## 4. `desktop/src/routes/settings/+layout.svelte`

Add a Build entry to `NAV_ITEMS` near the top — Build is a cockpit
super-super-module, it deserves prime real estate. Insert as the **second
item** (after the first existing entry, around line 19):

```ts
{ path: '/settings/build', label: 'Build', icon: 'build' },
```

Then add an SVG icon block in the icon switch (around line 75, alongside
the existing `analytics` / `schedule` blocks):

```svelte
{:else if item.icon === 'build'}
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>
```

(Wrench glyph — matches the sidebar icon for visual continuity.)

---

## 5. `BuildSideRail.svelte` integration (separate dispatch)

The Build cockpit page (`desktop/src/routes/build/+page.svelte`) reserves
a slot for the side rail using a placeholder `<aside>` with id
`build-side-rail-slot`. The separate side-rail dispatch should ship a
component named `BuildSideRail.svelte` and import it into the cockpit page
when it lands. The wiring change at that point will be:

```svelte
<!-- Replace the placeholder -->
<aside id="build-side-rail-slot" class="bld-side-rail" …></aside>

<!-- With the imported component -->
<BuildSideRail class="bld-side-rail" workspaceSlug={workspaceSlug} />
```

The CSS grid area `rail` on `.bld-cockpit` already lays it out; the
side-rail component just needs to render inside that area. Width is
controlled by the CSS variable `--bld-rail-width` (default 240px) so the
side-rail component can override it via inline style if needed.

---

## 6. Conductor in Iris's escalation chain — they are PEERS

Conductor is **not** subordinate to Iris. Both report to
`orchestrator-agent`. The escalation rules:

| Question type | Conductor handles? | Escalates to |
|---------------|--------------------|---------|
| Layout / pane / cockpit operations | Yes | user (in `/build`) |
| Observability / cost / anomaly | No — route to Iris | Iris owns this |
| Cross-cockpit decisions | No — route to orchestrator | orchestrator-agent |

Concretely: Conductor's persona file (`backend/priv/agents/conductor/persona.md`)
sets `escalate_to: user` and lists `chat.post_message` as its only
non-`build.*` outbound tool. It never calls Iris directly — if the user
asks Conductor an analytics question, Conductor responds with a brief
"Iris owns this — try @iris in `/analytics`" and stops.

If you have a workspace-wide router that fans agent mentions (orchestrator
agent's job), make sure `@conductor` resolves to `conductor` (the new
persona) and `@iris` continues to resolve to `analytics-agent`. They are
independently mentionable.

---

## Verification checklist

After applying all four wiring edits:

- [ ] `cd backend && mix ecto.migrate` runs the two Build migrations
      (`20260430010001_create_build_layouts`,
      `20260430010002_create_build_layout_uses`).
- [ ] `cd backend && mix compile --warnings-as-errors` is clean.
- [ ] `cd backend && mix test test/canopy/build_test.exs` passes.
- [ ] `cd backend && mix test test/canopy_web/controllers/build_controller_test.exs` passes.
- [ ] Visit `/build` in the desktop app — the cockpit page renders with
      the Mosaic and Composer mounted. The side-rail slot is empty until
      the separate side-rail dispatch lands.
- [ ] Visit `/settings/build` — the settings nav item is visible at the
      top, the page loads with the Conductor status card, and the
      "Reset Build to factory defaults" button works.
- [ ] `curl http://localhost:9190/api/v1/build/layouts` returns
      `{"data": []}`.
- [ ] OpenAPI spec at `/api/v1/openapi` contains the new `build.*` paths.
- [ ] In a tools-enabled runtime, `build.list_layouts` is callable and
      returns an empty layouts list. `build.suggest_layout` returns 0
      suggestions for any intent until layouts are saved.
