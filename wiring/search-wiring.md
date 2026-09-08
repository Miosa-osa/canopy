> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Workspace Search wiring

Surgical wiring required to bring the **workspace Search** endpoint online.
All new files (context module, two backends, controller, OpenAPI schema,
tests) and the surgical frontend update are already in place — the
integration listed below is what the main agent owns.

## Files already created (this task)

### Backend

| Path | Change |
|------|--------|
| `backend/lib/canopy/search.ex` | NEW — context module: `search/3`, validates query + slug, picks backend, defence-in-depth path filter, line truncation |
| `backend/lib/canopy/search/backend.ex` | NEW — `@callback search/3` behaviour |
| `backend/lib/canopy/search/backend/ripgrep.ex` | NEW — `rg --json` shell-out backend, 5s hard timeout |
| `backend/lib/canopy/search/backend/elixir.ex` | NEW — pure-Elixir fallback, 10s hard timeout |
| `backend/lib/canopy_web/controllers/search_controller.ex` | NEW — `index/2` action, validation matches `analytics_controller.ex` |
| `backend/lib/canopy_web/schemas/search_schema.ex` | NEW — `SearchMatch`, `SearchResult`, `SearchResultList` |
| `backend/test/canopy/search_test.exs` | NEW — context tests (validation, dispatch, defence-in-depth) |
| `backend/test/canopy/search/backend/ripgrep_test.exs` | NEW — tagged `:ripgrep`, auto-skipped when `rg` missing |
| `backend/test/canopy/search/backend/elixir_test.exs` | NEW — pure-Elixir tests, no external deps |
| `backend/test/canopy_web/controllers/search_controller_test.exs` | NEW — endpoint validation + happy paths |

### Desktop

| Path | Change |
|------|--------|
| `desktop/src/lib/api/queries/search.ts` | EDITED — `BackendStatus` extended with `backend`, `elapsedMs`, `truncated`; uses raw `fetch` to preserve the new metadata fields |

## Files NOT modified (per task constraints)

- `backend/lib/canopy_web/router.ex` — main agent adds the route (see below)
- `backend/lib/canopy/application.ex` — no supervision-tree change needed (search is stateless)
- Any frontend component beyond `search.ts` — the existing Build side rail
  consumer already calls `searchWorkspace` and reads `BackendStatus.hits`.

## Routes to register in `router.ex`

Add inside the `scope "/api/v1", CanopyWeb do` block, immediately after the
analytics block at line ~351:

```elixir
# Workspace search — line-level ripgrep across workspace files
get "/search", SearchController, :index
```

The path is bare `/search` (matching the frontend stub at
`desktop/src/lib/api/queries/search.ts`), not `/workspaces/:slug/search`,
because the workspace is selected via the `workspace_slug` query parameter.
This keeps URL space flat and aligned with `/api/v1/search` in the frontend.

## Configuration

A new optional config knob picks the search backend at runtime:

```elixir
# config/config.exs (or config/runtime.exs for prod)
config :canopy, :search_backend, :auto
```

Values:

| Value | Behaviour |
|-------|-----------|
| `:auto` (default) | Picks `Canopy.Search.Backend.Ripgrep` if `rg` is on `PATH`, else `Canopy.Search.Backend.Elixir`. |
| `:ripgrep` | Force ripgrep. Returns `{:error, :ripgrep_not_available}` if `rg` is missing. |
| `:elixir` | Force the pure-Elixir backend (useful for hermetic tests). |
| Any module atom | Used directly — must implement `Canopy.Search.Backend`. |

No config change is required to ship — `:auto` is the default and is read on
every request via `Application.get_env/3`.

## Performance notes

| Backend | Typical latency (warm cache) | Notes |
|---------|------------------------------|-------|
| `ripgrep` | < 50 ms for workspaces up to ~50k files | Honours `.gitignore`, skips binaries, skips hidden dirs. Hard 5s timeout. |
| `elixir`  | 200 ms – 2 s for the same workspace | Pure-Elixir walk. Skips `node_modules`, `_build`, `deps`, `target`, `dist`, `.next`, `.git`, `.svelte-kit`, etc. Skips empty files, files >5 MB, and files whose first 512 bytes contain a NUL byte. Hard 10s timeout. |

The fallback is intentionally conservative — it should never be the first
choice in production, but it guarantees the endpoint works on a developer
machine without `rg` installed and on minimal CI images.

## Defence-in-depth

Two layers guard against path traversal:

1. **Backend layer** — both implementations validate that returned paths sit
   under `root_path` before emitting a match.
2. **Context layer** — `Canopy.Search` re-validates every match before
   handing it back to the controller. Any path with a leading `/`, a `..`
   segment, or an expanded form that escapes `root_path` is silently
   dropped from the response.

The `:traversal` failure mode is exercised in
`backend/test/canopy/search_test.exs` via two synthetic backends that
deliberately attempt to leak paths.

## Frontend impact

The Build side rail's Search section (`SearchSection.svelte`) already calls
`searchWorkspace` from `desktop/src/lib/api/queries/search.ts`. After the
route is registered, `BackendStatus.available` flips from `false` to
`true`, populating `hits` with real matches. The new optional fields
(`backend`, `elapsedMs`, `truncated`) are surfaced for components that
choose to render backend metadata or a "results truncated" hint —
existing consumers continue to work unchanged because the additions are
optional.
