> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Skill Curator wiring

This file describes the surgical edits required to bring **Atlas** (the
Skill Curator runtime agent) and its surrounding HTTP / settings / tool
surface online. All new code is in place; the changes below are the
only ones outside this dispatch's scope that the integrator must apply.

> Skills already lives in the main sidebar — no main sidebar change.

## Files created (already on disk)

### Backend

| Path | Purpose |
|------|---------|
| `backend/priv/repo/migrations/20260428030001_add_verified_to_skills.exs` | Adds `verified`, `verified_at`, `verified_by` to `skills` table |
| `backend/priv/repo/migrations/20260428030002_create_skill_lockfile_entries.exs` | New `skill_lockfile_entries` table |
| `backend/priv/repo/migrations/20260428030003_create_skill_versions.exs` | New `skill_versions` table |
| `backend/lib/canopy/skills/lockfile_entry.ex` | Schema for lockfile rows |
| `backend/lib/canopy/skills/version.ex` | Schema for version history rows |
| `backend/lib/canopy/skills/curator.ex` | Curator extension context — wraps `Canopy.Skills` |
| `backend/lib/canopy/tools/skill_curator.ex` | 16 tools (13 `skills.*` + 3 `registry.*`) |
| `backend/lib/canopy_web/controllers/skill_curator_controller.ex` | HTTP API under `/api/v1/skill-curator/*` |
| `backend/lib/canopy_web/schemas/skill_curator_schema.ex` | OpenAPISpex schemas |
| `backend/priv/agents/skill-curator/persona.md` | Atlas persona — heartbeat 4h, color amber |

### Frontend

| Path | Purpose |
|------|---------|
| `desktop/src/lib/domain/skill_curator/types.ts` | TS types matching the backend |
| `desktop/src/lib/api/queries/skill_curator.ts` | TanStack Query factories |
| `desktop/src/routes/settings/skills/+page.svelte` | NEW settings page (lockfile + policy + sources) |

### Tests

| Path | Coverage |
|------|----------|
| `backend/test/canopy/skills/curator_test.exs` | Lockfile, versions, verification, diff, install gate |
| `backend/test/canopy_web/controllers/skill_curator_controller_test.exs` | 11 endpoint cases — validation + happy path |

## Files NOT modified (per task constraints)

- `backend/lib/canopy/skills/skill.ex` — base schema untouched. The
  `verified*` columns are read/written by the Curator via parametric SQL
  fragments, not via the Skill changeset.
- `backend/lib/canopy/skills.ex` — base context untouched.
- `desktop/src/routes/skills/+page.svelte` — existing catalog page stays
  as-is. The new Curator settings page lives at `/settings/skills`.
- `backend/lib/canopy_web/controllers/skills_controller.ex` — base CRUD
  controller untouched.

## Required wiring edits

### 1. Router — add the 11 endpoints

In `backend/lib/canopy_web/router.ex`, after the Analytics block (around
line 349, the existing `post "/analytics/alerts"`), add:

```elixir
    # Skill Curator — lockfile, versions, verification, sources (Atlas agent surface)
    get "/skill-curator/lockfile", SkillCuratorController, :lockfile_index
    post "/skill-curator/lockfile", SkillCuratorController, :lockfile_create
    delete "/skill-curator/lockfile/:workspace_slug/:skill_slug",
      SkillCuratorController, :lockfile_delete

    get "/skill-curator/skills/:slug/versions", SkillCuratorController, :versions_index
    get "/skill-curator/skills/:slug/diff", SkillCuratorController, :versions_diff

    post "/skill-curator/skills/:slug/verify", SkillCuratorController, :verify
    delete "/skill-curator/skills/:slug/verify", SkillCuratorController, :unverify
    get "/skill-curator/unverified", SkillCuratorController, :unverified_index

    get "/skill-curator/sources", SkillCuratorController, :sources_index
    post "/skill-curator/sources", SkillCuratorController, :sources_create
    post "/skill-curator/sources/refresh", SkillCuratorController, :sources_refresh
```

### 2. Settings nav — add a Skills item

In `desktop/src/routes/settings/+layout.svelte`, the `NAV_ITEMS` array
already lives near the top of the file. Add a new entry after Analytics:

```ts
  { path: '/settings/skills', label: 'Skills', icon: 'skills' },
```

Then add a matching `{:else if item.icon === 'skills'}` branch in the
icon-switch block. A reasonable Lucide-style inline SVG:

```svelte
{:else if item.icon === 'skills'}
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M3 7l9-4 9 4-9 4-9-4z"/>
    <path d="M3 17l9 4 9-4"/>
    <path d="M3 12l9 4 9-4"/>
  </svg>
```

### 3. Tools registry — pick up the new module

In `backend/config/config.exs`, the existing `:canopy, :tool_modules` list
should append `Canopy.Tools.SkillCurator`:

```elixir
config :canopy, :tool_modules, [
  Canopy.Tools.BuiltIn,
  Canopy.Tools.Analytics,
  Canopy.Tools.SkillCurator   # ← add this
]
```

`Canopy.Tools.register_all_builtins/0` walks the list at boot and
registers all 16 tools without further intervention.

### 4. Optional supervisor entry (heartbeat)

The Atlas persona specifies `cron: "0 */4 * * *"` — every 4 hours. This
is auto-picked-up by the existing `Canopy.Heartbeat.Registrar` once
Atlas is hired, exactly the same way Iris is wired in
`iris-bootstrap-wiring.md`. No new supervisor child is needed.

If a project chooses to hire Atlas at boot (mirroring the Iris pattern),
add a parallel `Canopy.Skills.Curator.Bootstrap` module later. For v0.1
this dispatch leaves Atlas to be hired via the existing
`mix canopy.seed.agents` task that walks `priv/agents/*/persona.md`.

## Verification checklist

1. Migrations apply cleanly (`mix ecto.migrate`).
2. `mix test test/canopy/skills/curator_test.exs` — all green.
3. `mix test test/canopy_web/controllers/skill_curator_controller_test.exs` — all green.
4. Tool registry exposes 16 new tools (`Canopy.Tools.list_all/0` shows
   `skills.*` + `registry.*` entries).
5. `/settings/skills` renders in the desktop app, fetches lockfile, and
   shows the unverified-policy selector.
6. Atlas persona surfaces via `/agents/skill-curator` once seeded.
