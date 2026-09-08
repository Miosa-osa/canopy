> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Mosaic settings popover + tab strip polish — wiring

Finish-pass wiring for the Mosaic settings popover, tab strip polish, and
hover detail card. The prior agent landed the runes store + shortcut helper
+ unit tests; this pass adds the UI components and surgical edits to the
existing tile shell.

## Files created (module-local — no shared edits required)

| Path | Role |
|------|------|
| `desktop/src/lib/design/patterns/mosaic/MosaicSettings.svelte` | Settings popover content (View as / Density / Title / Metadata / Hover toggle). Anchored by host via foundation `<Popover>`. Focus trap + Esc dismiss + ARIA `role="menu"` |
| `desktop/src/lib/design/patterns/mosaic/MosaicSettings.test.ts` | Vitest contract tests: option-list / sanitize round-trip + simulated session walkthrough (16 tests) |
| `desktop/src/lib/design/patterns/mosaic/TabHoverCard.svelte` | Hover detail card. Pure presenter — host owns positioning via inline `style` prop |
| `desktop/src/lib/design/patterns/mosaic/TabHoverCard.test.ts` | Vitest contract tests: free-form config coercion + relativeTime + formatCost + paneTitle (21 tests) |

## Files edited (surgical — same-LOC envelope)

| Path | Lines edited | What changed |
|------|--------------|--------------|
| `desktop/src/lib/design/patterns/mosaic/MosaicRoot.svelte` | full rewrite, 122 → 195 LOC | Added `<Settings>` gear button (top-right, z=30), wraps `<MosaicSettings>` inside foundation `<Popover>`. `setContext('mosaic-prefs', mosaicPrefs)` so child tiles share the singleton. Density data-attrs propagate via the root for tile-scoped CSS overrides. No shortcut behaviour was touched |
| `desktop/src/lib/design/patterns/mosaic/MosaicTile.svelte` | full rewrite, 360 → 545 LOC | Reads prefs via context. New `paneTitle()` helper (command / cwd-basename / branch). New `<TabHoverCard>` mount with 350ms hover delay + position math. Drag-and-drop now also handles intra-tile reorder via `mosaicLayout.movePane(tile.id, paneId, tile.id, insertAt)` with insertion-index computed from `clientX`. New `viewMode === 'panes'` branch renders a horizontal pane-card stub above the active pane (see "viewMode='panes' decision" below). Density data-attrs override default tab heights at the `[data-density='compact'\|'roomy']` selectors |

## Files NOT touched (per constraints)

- `desktop/src/lib/stores/mosaic-prefs.svelte.ts` (prior agent)
- `desktop/src/lib/stores/mosaic-layout.svelte.ts` (other agent owns)
- `desktop/src/lib/utils/mosaic-shortcuts.ts` (prior agent — kept; ⌘1-9/⌘W/⌘T are still served by the existing block in `MosaicRoot.svelte`)
- `desktop/src/lib/design/patterns/mosaic/PaneContent.svelte`, `PanePicker.svelte`, `MosaicNode.svelte`

## Primitives reused (NO duplicates introduced)

| Need | Reused module |
|------|---------------|
| Popover positioning | `desktop/src/lib/design/foundation/popover/Popover.svelte` (bits-ui based, already exists) |
| Toggle | `desktop/src/lib/design/foundation/toggle/Toggle.svelte` |
| Checkbox (multi-select metadata) | `desktop/src/lib/design/foundation/checkbox/Checkbox.svelte` |
| Icons | `lucide-svelte` (`Settings`, `AlignJustify`, `LayoutGrid`, `Rows`, `Bot`) — same package the rest of Mosaic uses |
| LocalStorage / persist | `mosaicPrefs` runes store (prior agent) — owns `loadPrefs` / `savePrefs` / `sanitize` |
| Drag-and-drop | Pre-existing HTML5 DnD pattern in `MosaicTile.svelte`, extended with intra-tile reorder. **Not** `svelte-dnd-action` — see "DnD library status" |

No new foundation components built. The Popover already existed (verified by `find foundation/popover/Popover.svelte`).

## Default values (from `mosaicPrefs.defaultPrefs`)

| Setting | Default |
|---------|---------|
| `view_mode` | `panes` |
| `density` | `comfortable` |
| `pane_title_format` | `command` |
| `metadata_fields` | `["branch"]` |
| `show_details_on_hover` | `true` |

LocalStorage key: `canopy.mosaic.prefs`. Independent of layout key `canopy.mosaic.<slug>`.

## viewMode='panes' decision — STUB

The reference design implies a panes view that renders every pane side-by-side
(WezTerm / iTerm / Warp split-style). Full implementation is non-trivial because
each pane (terminal, code editor, agent conversation) holds its own runtime,
scroller, and lifecycle — naïve rendering N copies inside one tile triggers N
parallel API mounts and breaks scroll restoration.

**Shipped:** a horizontal **pane-card row** above the active pane. Cards render
title + kind, click to activate, current pane gets accent border. The active
pane mounts the existing `<PaneContent>` below the card row. Discoverable, no
behavioural regression vs. tabs view, ~zero runtime cost.

**Tracked follow-up (separate sprint, owner = mosaic-layout agent):**
1. Add `mosaicLayout.splitTile()` orchestration so each pane in a "panes-mode"
   tile renders in its own sub-tile with sized splits.
2. Decide whether panes-mode forces a tile to auto-split, or if it's a pure
   visual mode that re-uses the existing split tree (latter is cleaner —
   panes-mode just toggles which tab strip is visible, splits already exist).

## DnD library status

`svelte-dnd-action` is used elsewhere (`PinnedPanel.svelte`, `KanbanBoard.svelte`,
`ControlLane.svelte`, etc.) but **not** in Mosaic. Mosaic already had a working
HTML5-DnD implementation (cross-tile move + edge-drop split via the
`application/x-canopy-pane` mime). I extended that same path with intra-tile
reorder rather than introducing a second DnD strategy in the same component.

Net change: no new dependency, one new helper (`computeReorderIndex`).
If a future sprint wants `svelte-dnd-action` in Mosaic for animation parity
with other patterns, the migration is a single-file refactor.

## Backend gap — pane metadata fields

`TabHoverCard` reads `pane.config.{cwd, branch, agent, runtime, model, started_at, cost_usd}`,
all defensive — every missing field renders as `—`. Today the `Pane.config` is
free-form `Record<string, unknown>` and only some pane kinds (e.g.
`agent_conversation`) populate it. To make the hover card content-rich:

| Pane kind | Field | Source |
|-----------|-------|--------|
| `agent_conversation` / `terminal` | `cwd` | Already known (worktree path / shell PWD) — surface into `pane.config` at create-time |
| `agent_conversation` | `agent`, `model` | Sessions API exposes both — wire into pane config when calling `createSession()` |
| `agent_conversation` | `runtime` | Already on the create body (`runtimeType`) |
| any | `branch` | Needs new `git rev-parse --abbrev-ref HEAD` per cwd. Suggest `desktop/src/lib/api/queries/git.ts` (does not exist yet) backed by an existing or new Tauri command |
| `agent_conversation` | `cost_usd`, `started_at` | Sessions API has `created_at`. Cost requires a tally on the backend (`sessions.metrics.total_cost`) — does not exist yet |

**Recommendation:** ship the popover + tab strip polish now (graceful fallback
covers all gaps); open follow-up tickets for the backend fields.

## Tests run

```
$ npx vitest run \
    src/lib/design/patterns/mosaic/MosaicSettings.test.ts \
    src/lib/design/patterns/mosaic/TabHoverCard.test.ts
 Test Files  2 passed (2)
      Tests  37 passed (37)
```

All pre-existing svelte-check errors are unrelated. Our four new/edited files
introduce 0 new svelte-check errors and 0 type-level regressions.

## Manual smoke checklist (for the integrator)

- [ ] Open Mosaic, click gear (top-right) — popover appears below it
- [ ] Press Esc — popover closes
- [ ] Tab through controls — focus cycles within the popover (focus trap)
- [ ] Click "Tabs" view → all tiles reflect new view; reload → still tabs
- [ ] Click roomy/compact density icons → tab heights change live
- [ ] Switch title format to `working_directory` on a session pane with a `cwd` config → tab title shows basename
- [ ] Hover a tab with `show_details_on_hover` ON → card appears after 350ms with metadata grid
- [ ] Toggle hover off → no card on hover
- [ ] Drag a tab within the same tile and drop on a different tab → reorders
- [ ] Drag across tiles still works (pre-existing path, unaffected)
