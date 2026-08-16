# Per-Workspace State — Applied Wiring

**Status:** 4 of 6 surgical edits applied. 2 skipped due to coordination boundaries.
**Owner:** main agent (this dispatch). Consumes primitives shipped by the Active Workspace agent.

This document records the propagation of per-workspace state isolation across
the modules that need to scope state to the active workspace. The primitives
(`activeWorkspace` singleton + `useWorkspaceState` hook + backend `workspace_states`
endpoints) were already in place; this dispatch wired them into the consumers.

---

## Primitives reused (no duplicates)

| Primitive | Location | Used by |
|---|---|---|
| `activeWorkspace` singleton (rune store) | `desktop/src/lib/stores/active-workspace.svelte.ts` | build/+page, build-rail store, runtimes/[type]/+page, mosaic-layout store |
| `WORKSPACE_CHANGED_EVENT` constant + window CustomEvent | `desktop/src/lib/stores/active-workspace.svelte.ts` | mosaic-layout store, build-rail store |
| `getWorkspaceState<T>` / `putWorkspaceState<T>` low-level API | `desktop/src/lib/api/queries/workspace-states.ts` | mosaic-layout store, build-rail store |
| `useWorkspaceState<T>` hook | `desktop/src/lib/api/queries/workspace-states.ts` | (Available; not consumed in this dispatch — see "Why we used the low-level API" below.) |

### Why we used the low-level API in singleton stores

The `useWorkspaceState` hook calls `$effect` at the top of its function body,
which requires a runes-tracked context (i.e. component init or `$effect.root()`).
The two stores that needed per-workspace persistence (`mosaic-layout`, `build-rail`)
are class-based singletons instantiated at module-load. Wrapping the hook in
`$effect.root()` would tie state to a hand-rolled effect tree we'd then own;
calling `getWorkspaceState` / `putWorkspaceState` directly + a small in-store
debounce keeps each singleton self-contained, mirrors the hook's 500 ms debounce,
and avoids leaking effect roots. No parallel state stores were created.

---

## Edit 1 — `desktop/src/routes/build/+page.svelte` (APPLIED)

Replaced the hardcoded `const workspaceSlug = 'default'` with a reactive
`$derived` over `activeWorkspace.slug`. Switched the `defaultLayoutQuery`
hookup to the writable-store pattern (used elsewhere in workspace-scoped
routes) so the query re-fires on workspace switch. Replaced the `onMount`
seed-empty-pane block with a `$effect` so the seed-pane logic re-runs when
the active workspace changes — each workspace lands on its own prompt
surface. Also threaded `activeWorkspace.rootPath` (with `~` fallback) into
the seeded pane's `cwd`.

| Line range | Before | After |
|---|---|---|
| 26–37 | static `'default'` constant + `createQuery(...)` once | imports `activeWorkspace`, `untrack`, `writable`, `CreateQueryOptions`; derived `workspaceSlug` |
| 38–61 | `onMount(() => { mosaicLayout.load('default') ... })` | `$effect(() => { mosaicLayout.load(slug) ... })` with rootPath-aware cwd |

Total touched: ~15 lines added, ~5 lines replaced.

---

## Edit 2 — `desktop/src/lib/stores/mosaic-layout.svelte.ts` (APPLIED)

Switched the persistence layer from "localStorage only" to "localStorage cache
+ backend `workspace_states` source of truth". Kept the existing `Tile` /
`Pane` / `MosaicLayout` shape intact — only the persistence layer changed.

Specifics:
1. New imports: `getWorkspaceState`, `putWorkspaceState`, `WORKSPACE_CHANGED_EVENT`.
2. New exports: `MOSAIC_LAYOUT_STATE_KEY = "mosaic.layout"`, `buildDefaultLayout(slug)`.
3. New private state: `#backendTimer` (debounce), `#listenerWired` (idempotency).
4. New methods:
   - `#wireWorkspaceListener()` — subscribes once to `workspace.changed`. On
     fire, saves current layout (localStorage + flush backend), then loads
     the new slug.
   - `loadAsync(slug)` — async public entry, currently a thin wrapper over
     synchronous `load()` plus the always-fired backend hydrate kicked off
     inside `load()`.
   - `#hydrateFromBackend(slug)` — GETs the workspace's saved layout and
     replaces the in-memory layout if the slug still matches (guards
     against fast re-switches).
   - `#scheduleBackendWrite()` — debounced 500 ms PUT.
   - `#flushBackendNow(slug)` — synchronous flush for the slug being
     swapped away from.
5. Updated `load(slug)` — fires `#hydrateFromBackend(slug)` in the
   background after the synchronous localStorage read.
6. Updated `save()` — writes localStorage, then schedules a debounced
   backend PUT.

Lines added: ~120. Original `Tile` / `Pane` shape unchanged. LOC docstring
target updated from 220 → 320 to reflect the persistence layer.

---

## Edit 3 — `desktop/src/routes/files/+page.svelte` (SKIPPED — coordination)

The file already exists (1305 lines, full bucket-style file browser) and
uses `ui.currentWorkspaceSlug` / `ui.setCurrentWorkspace` — NOT
`activeWorkspace`. Per the dispatch instructions: "if the rebuilt page
doesn't already use `activeWorkspace`, … skip — the rebuild agent owns this
file." The Files explorer rebuild is an in-flight track. Leaving this
edit to the rebuild agent so we don't introduce conflicting wires.

**Follow-up:** when the Files rebuild lands, swap the two `ui.*` calls (line
60 read, line 401 write) to `activeWorkspace.slug` / `activeWorkspace.setActive(...)`.

---

## Edit 4 — `desktop/src/lib/design/patterns/mosaic/panes/AgentConversationPane.svelte` (SKIPPED — conflict)

This file is owned by the embedded-runtime agent (visible in the imports:
`EmbeddedRuntime`, `EmbeddedRuntimeConfig`, runtime-input plumbing). The
file does NOT currently import `activeWorkspace`. Per the dispatch
instructions: "if `activeWorkspace` is already imported, just add the cwd
derivation. Otherwise skip and document in wiring as a follow-up."

The current `cwd = '~'` default at line 80 is fed by the parent
(`PaneContent.svelte` at line 168) which is on the no-touch list. The
build/+page seed-pane edit (Edit 1) DOES already set `cwd: activeWorkspace.rootPath ?? '~'`
at pane-creation time, which is the primary user path. Subsequent panes
opened via `PaneContent`'s default also receive `cwd: cfg.cwd ?? '~'` from
`pane.config`, which honours the workspace rootPath when the pane was
created via the seed.

**Follow-up:** once the embedded-runtime agent merges, add the
`activeWorkspace` import and change the prop default to
`cwd = activeWorkspace.rootPath ?? '~'`. Also update `PaneContent.svelte`'s
fallback from `cfg.cwd ?? '~'` → `cfg.cwd ?? activeWorkspace.rootPath ?? '~'`
once the no-touch list relaxes.

---

## Edit 5 — `desktop/src/lib/stores/build-rail.svelte.ts` (APPLIED)

Wired per-workspace persistence for the active rail section. Pattern
mirrors `mosaic-layout.svelte.ts`:

1. New imports: `getWorkspaceState`, `putWorkspaceState`, `activeWorkspace`,
   `WORKSPACE_CHANGED_EVENT`.
2. New exports: `RAIL_SECTION_STATE_KEY = "build.sideRail.section"`.
3. Constructor now wires the workspace.changed listener and (if a workspace
   is already active at boot) hydrates from backend.
4. New private methods:
   - `#wireWorkspaceListener()` — idempotent, hydrates new workspace's
     saved section on event fire.
   - `#hydrateFromBackend(slug)` — GET; if no value persisted yet, keep
     current localStorage-derived section (don't clobber the user's
     session); else apply.
   - `#scheduleBackendWrite()` — debounced 500 ms PUT keyed on the active
     workspace slug.
5. Public `open()` / `collapse()` now call `#scheduleBackendWrite()` on top
   of the existing `saveActiveSection()` localStorage call.

Lines added: ~80. `BuildSideRail.svelte` itself was NOT touched — the prop
contract (`workspaceSlug` from `/build/+page`) already propagates from the
new `activeWorkspace.slug` derivation in Edit 1.

---

## Edit 6 — Terminal pane spawn site (APPLIED)

**Found at:** `desktop/src/routes/runtimes/[type]/+page.svelte`, function
`autoAttachOrSpawn`, lines 105–143.

The site that spawns a fresh PTY-backed `Session` when the runtime view
mounts. Original:
```ts
const workspaces = await listWorkspaces();
const workspaceSlug = workspaces[0]?.slug ?? undefined;
const body = { runtimeType: ..., cwd: '~', workspaceSlug, ... };
```

After edit:
```ts
let workspaceSlug = activeWorkspace.slug ?? undefined;
let cwd = activeWorkspace.rootPath ?? '~';
if (!workspaceSlug) {
  const workspaces = await listWorkspaces();
  workspaceSlug = workspaces[0]?.slug ?? undefined;
  cwd = workspaces[0]?.rootPath ?? '~';
}
const body = { runtimeType: ..., cwd, workspaceSlug, ... };
```

Lines added: ~7. Lines replaced: ~3.

`PaneContent.svelte` is the OTHER terminal-spawn site (line 47, still spawns
with `cwd: '~'`) — but that file is on the no-touch list. The seeded pane
from Edit 1 already supplies `cwd` via `pane.config.cwd`, so the `'~'`
fallback only fires for panes opened through PanePicker (a separate flow).

**Follow-up TODO — live terminal respawn:** when the user switches
workspaces while a terminal pane is live, the existing PTY keeps running
in the OLD workspace's `rootPath`. Two options:
1. Prompt the user before respawning ("Restart terminal in <new path>?").
2. Send a `cd <new-rootPath>\n` to the PTY (no respawn, but the running
   process won't notice until next prompt).

For v1, neither is wired — only NEW spawns honour the active workspace.
The `workspace.changed` event is now visible globally on `window`, so the
terminal pane can subscribe at its leisure.

---

## Migration note (existing localStorage state)

**Existing localStorage keys are NOT migrated to `workspace_states`.**

After this dispatch deploys:
- Users with saved mosaic layouts in `localStorage` (`canopy.mosaic.<slug>`)
  will continue to see those layouts on first load (the synchronous
  `load(slug)` reads localStorage first). The backend hydrate will then
  fire — but since the backend has no value yet, the localStorage value
  wins.
- The first `save()` after any user edit will PUT the layout to backend,
  so cross-device sync starts at that moment.
- For the build-rail section, the same pattern: localStorage section
  shows on first paint, backend hydrate either matches or replaces.

A one-shot migration helper was NOT built. Effort estimate: ~30 lines
(scan localStorage for `canopy.mosaic.*` keys, PUT each to backend, mark
migrated). Worth doing if user reports of "my layout disappeared" surface;
otherwise the lazy upgrade above is sufficient.

---

## Tests

**File:** `desktop/src/lib/stores/mosaic-layout.test.ts` (new — 180 lines).

Coverage:
- `buildDefaultLayout(slug)` returns a fresh empty tile per slug.
- `MOSAIC_LAYOUT_STATE_KEY` is the canonical `"mosaic.layout"` constant
  and does not collide with the build-rail key.
- Per-workspace localStorage swap: layout saved under slug A is preserved
  when slug B is loaded; loading a brand-new slug returns
  `buildDefaultLayout`.
- Malformed JSON in localStorage falls through to the default layout.
- `workspace.changed` event payload shape matches `WorkspaceChangedDetail`.

The runes class is not instantiated inside tests (per the established
pattern in `mosaic-prefs.test.ts`); pure helpers + a hand-rolled mirror of
the swap logic are exercised. The `$lib/api/queries/workspace-states.js`
module is mocked at the import boundary so no real network calls fire.

---

## Files touched

| File | Lines changed | Status |
|---|---|---|
| `desktop/src/routes/build/+page.svelte` | +20 / −7 | APPLIED |
| `desktop/src/lib/stores/mosaic-layout.svelte.ts` | +120 / −5 | APPLIED |
| `desktop/src/lib/stores/build-rail.svelte.ts` | +85 / −2 | APPLIED |
| `desktop/src/routes/runtimes/[type]/+page.svelte` | +9 / −3 | APPLIED |
| `desktop/src/lib/stores/mosaic-layout.test.ts` | NEW (180 lines) | APPLIED |
| `desktop/src/routes/files/+page.svelte` | — | SKIPPED (coordination) |
| `desktop/src/lib/design/patterns/mosaic/panes/AgentConversationPane.svelte` | — | SKIPPED (conflict) |

5 files modified, 1 new test file, 0 new dependencies, 0 backend touches.

---

## Constraints honoured

- ✓ No edits to `application.ex`, `router.ex`, mosaic shells (`PaneContent`,
  `MosaicTile`, `MosaicRoot`, `PanePicker`), `Composer.svelte`, foundation
  primitives, or any backend file.
- ✓ No new dependencies.
- ✓ No competitor brand names introduced.
- ✓ Svelte 5 runes throughout (`$state`, `$derived`, `$effect`).
- ✓ Every workspace switch is `console.debug`-logged for visibility.
- ✓ Every state read handles `activeWorkspace.slug === null` (treated as
  `'default'` in build/+page; treated as no-op for backend writes in the
  stores).
- ✓ Every persistence write is debounced (500 ms, mirroring
  `useWorkspaceState`).
- ✓ Read-the-file-first protocol: `AgentConversationPane.svelte`,
  `PaneContent.svelte`, and `files/+page.svelte` were all read before the
  decision-to-skip was made.
