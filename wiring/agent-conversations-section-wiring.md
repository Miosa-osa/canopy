# Agent Conversations Section — wiring instructions

Adds a 5th section to the Build Side Rail (`/build` route) that surfaces
`Canopy.Sessions.Session` records of `kind="agent_conversation"`. The panel
matches the cursor-anchored agent-transcript popover other shells expose
(search box → ACTIVE / RECENT groups → `+ New conversation` button).

This section is **primary** — it lives at the top of the icon column and
binds to `⌘1`, ahead of Tabs / Project Explorer / Search / Drive.

## 1. Section enum extension

`desktop/src/lib/stores/build-rail.svelte.ts` exports the canonical section
list. The enum has grown from 4 → 5 sections:

```ts
export type RailSection =
  | "conversations"   // ⌘1 — primary
  | "tabs"            // ⌘2
  | "explorer"        // ⌘3
  | "search"          // ⌘4
  | "drive";          // ⌘5

export const RAIL_SECTIONS: readonly RailSection[] = [
  "conversations",
  "tabs",
  "explorer",
  "search",
  "drive",
];

export const DEFAULT_RAIL_SECTION: RailSection = "conversations";
```

Persistence key is unchanged: `localStorage["canopy.build.sideRail.section"]`.
Existing values (`"tabs" | "explorer" | "search" | "drive"`) remain valid;
the new `"conversations"` value is back-compat with the `isRailSection`
type guard.

## 2. Keyboard shortcut update

The chord map handled by `BuildSideRail.svelte` is:

| Key  | Action                          |
|------|---------------------------------|
| `Esc`| Collapse                        |
| `⌘1` | Open / focus Conversations      |
| `⌘2` | Open / focus Tabs               |
| `⌘3` | Open / focus Project Explorer   |
| `⌘4` | Open / focus Search             |
| `⌘5` | Open / focus Drive              |

Hosts that previously bound `⌘1..⌘4` for Tabs/Explorer/Search/Drive must
shift one slot down. The rail listens via `<svelte:window onkeydown>`; if the
host page binds these chords first, lift the listener up and call
`buildRail.open(section)` directly.

## 3. Default section on first boot

`BuildRailStore` now seeds `activeSection = "conversations"` on the first
render where `localStorage["canopy.build.sideRail.section"]` is absent.

Behaviour matrix:

| Persisted value | Effect on boot                              |
|-----------------|---------------------------------------------|
| (absent)        | Open Conversations (writes the default in)  |
| `"none"`        | Stay collapsed (user had collapsed manually)|
| `"tabs"` etc.   | Restore that section                        |

To force a different first-boot default, set the localStorage value before
the rail mounts.

## 4. Backend contract

The section reuses the existing sessions endpoint — **do NOT add a parallel
`/conversations` endpoint**. The single source of truth is
`Canopy.Sessions`.

```
GET    /api/v1/sessions?kind=agent_conversation&workspace=<slug>&limit=100
POST   /api/v1/sessions   { kind: "agent_conversation", runtime_type, cwd, workspace_slug }
DELETE /api/v1/sessions/:id
```

Required fields delivered by the parallel `kind`-column dispatch:

- `Canopy.Sessions.Session` schema gains `field :kind, :string,
  default: "terminal"` validated against `~w(terminal agent_conversation)`.
- `Canopy.Sessions.list/1` accepts `:kind` in its filter map and translates
  the `kind` query param via the controller.
- The controller serializes `kind` on the response struct.

Until that lands, the frontend degrades gracefully:
- The `kind` query param is ignored by the backend, so the panel pre-filters
  client-side (`s.kind === "agent_conversation"`). Legacy `null` rows are
  hidden — they appear in TabsSection / scrollback as before.
- `POST /api/v1/sessions` ignores the unknown `kind` body field; new rows
  surface with `kind: null`. This is acceptable for a one-release transition.

## 5. Pane integration

Rows open as `kind: "agent_conversation"` panes. The mosaic dispatcher
(`PaneContent.svelte` → `AgentConversationPane`) already handles this kind
and reads `pane.config.sessionId`, so no changes there are required.

Conversation pane payload shape:

```ts
{
  id: <random>,
  kind: "agent_conversation",
  ref: <session.id>,                     // also stored as sessionId in config
  title: <prompt-or-agentSlug-or-id>,
  config: {
    sessionId: <session.id>,
    cwd:       <session.cwd>,
    model:     <session.modelId | undefined>,
  },
}
```

Right-click actions on a row:

| Action              | Effect on `mosaicLayout`                              |
|---------------------|-------------------------------------------------------|
| Fork in new pane    | `splitTile(activeTileId, "vertical", newPane)`        |
| Fork in new tab     | `openPane(newPane)` (active tile gets a new tab)      |
| Delete              | DELETE /sessions/:id; close any pane bound to it      |

A plain click reuses an open pane bound to the same session
(`activatePane`) before falling back to `openPane`. This avoids duplicate
panes when the user re-clicks a conversation already in the mosaic.

## 6. Reused primitives

This dispatch ships **no new query/mutation pairs against the network**. It
re-exports/wraps:

- `sessionsQuery({ kind: "agent_conversation", ... })` →
  `agentConversationsQuery({ workspaceSlug, status?, limit? })`
- `createSession` (with `kind: "agent_conversation"` injected) →
  `createAgentConversationMutation`
- `cancelSession` → `deleteAgentConversationMutation`

The query key prefix is `["agent-conversations", filters]` so devtools and
cache eviction can target conversations without disturbing the broader
`["sessions", ...]` cache.

## 7. New foundation primitive

`desktop/src/lib/design/foundation/menus/ContextMenu.svelte` is a
**cursor-anchored** menu — distinct from the existing
`foundation/menu/Menu` (a trigger-anchored bits-ui dropdown).

```svelte
<ContextMenu
  items={menuItems}
  anchor={menuAnchor}    {/* { x, y } | null */}
  onclose={() => menuAnchor = null}
  ariaLabel="Conversation actions"
/>
```

Already wired through `foundation/index.ts`:

```ts
export { ContextMenu } from "./menus";
export type { ContextMenuItem, ContextMenuAnchor } from "./menus";
```

Follow-up (out of scope for this dispatch): port the inlined fixed-position
menu inside `TabsSection.svelte` to this primitive.

## 8. Files touched

NEW:
- `desktop/src/lib/design/foundation/menus/ContextMenu.svelte`
- `desktop/src/lib/design/foundation/menus/index.ts`
- `desktop/src/lib/design/foundation/menus/ContextMenu.test.ts`
- `desktop/src/lib/design/patterns/build/sections/AgentConversationsSection.svelte`
- `desktop/src/lib/design/patterns/build/sections/AgentConversationsSection.test.ts`
- `desktop/src/lib/api/queries/conversations.ts`

EDITED (within this module's ownership):
- `desktop/src/lib/design/patterns/build/BuildSideRail.svelte`  (5-section switch)
- `desktop/src/lib/design/patterns/build/BuildSideRail.test.ts` (5-section tests)
- `desktop/src/lib/stores/build-rail.svelte.ts`                 (section enum + default)
- `desktop/src/lib/api/queries/sessions.ts`                     (added optional `kind` filter + body field)
- `desktop/src/lib/domain/sessions/types.ts`                    (added `SessionKind` + `Session.kind` + `CreateSessionBody.kind`)
- `desktop/src/lib/design/foundation/index.ts`                  (re-export `ContextMenu`)

NOT touched (owned by other dispatches):
- `desktop/src/routes/build/+page.svelte`
- Any file under `desktop/src/lib/design/patterns/mosaic/`
- `desktop/src/lib/stores/mosaic-layout.svelte.ts`

## 9. TODOs

- Backend `kind` column rollout — once shipped, remove the client-side
  `s.kind === "agent_conversation"` post-filter in
  `AgentConversationsSection.svelte` (the query param will be authoritative).
- Drag-drop a conversation row onto a mosaic tile (lift the existing
  Drive/Explorer drag payload contract) — out of scope for this section.
- TabsSection refactor onto the new `ContextMenu` primitive — a one-file PR.
