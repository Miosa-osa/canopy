# Agent Conversation Pane wiring

This file documents the surgical edits and module-local additions that
bring **AgentConversationPane** online inside the Mosaic shell. The pane
replaces the global per-route Composer that used to sit at the bottom of
`/build` — every conversation now lives inside its own tile, with its
own composer, transcript, chips, and slash palette.

## Files created (module-local)

### Frontend

| Path | Role |
|------|------|
| `desktop/src/lib/design/patterns/mosaic/panes/AgentConversationPane.svelte` | Pane root: transcript area + composer + intro card. Lazy-loaded by `PaneContent`. |
| `desktop/src/lib/design/patterns/mosaic/panes/agent-conversation/ConversationIntroCard.svelte` | Empty-state card. Title, subtitle (with cwd), 4-row shortcut list. |
| `desktop/src/lib/design/patterns/mosaic/panes/agent-conversation/ConversationComposer.svelte` | Wraps existing `Composer.svelte`, adds `ChipRow` + `ShellCommandHint`, owns ⌘\| toggle. |
| `desktop/src/lib/design/patterns/mosaic/panes/agent-conversation/ShellCommandHint.svelte` | "autodetected shell command, ⌘\| to override" affordance. |
| `desktop/src/lib/design/patterns/mosaic/panes/agent-conversation/ComposerChips.svelte` | Chips strip: cwd · model · remote-control · mic · attach. |
| `desktop/src/lib/design/patterns/mosaic/panes/agent-conversation/shell-detect.ts` | Pure helper `looksLikeShellCommand(input)` + `SHELL_COMMANDS` allowlist. Test target. |

### Tests

| Path | Role |
|------|------|
| `desktop/src/lib/design/patterns/mosaic/panes/agent-conversation/ShellCommandHint.test.ts` | Vitest — exhaustive regex / allowlist assertions for shell detection. |
| `desktop/src/lib/design/patterns/mosaic/panes/AgentConversationPane.test.ts` | Vitest — `PaneKind` union, `Pane.config` round-trip, mosaic store integration. |

### Backend

**None** — see "Backend gap" below.

## Reused primitives (no duplicate modules)

| Need | Reused module |
|------|--------------|
| Prompt input + @mention + agent picker + runtime picker | `desktop/src/lib/design/patterns/Composer.svelte` |
| Cross-entity @mention dropdown | `MentionInput.svelte` (already nested in Composer) |
| Slash-command palette | `desktop/src/lib/design/patterns/build/SlashCommands.svelte` |
| Transcript renderer | `desktop/src/lib/design/patterns/blocks/BlockStream.svelte` |
| Block primitive | `Canopy.Sessions.Block` (DB) + `Block.svelte` |
| Conversation persistence | `Canopy.Sessions.Session` (kind="agent_conversation"). **No new table.** |
| Session creation | `createSession()` in `desktop/src/lib/api/queries/sessions.ts` (existing `POST /api/v1/sessions`) |
| Mosaic state | `mosaicLayout` store + `Pane` / `PaneKind` types |
| Icons | `lucide-svelte` (Bot, Folder, Sparkles, Radio, Mic, Plus, ChevronDown, TerminalSquare, SquareArrowOutUpRight) |

## Shared file edits applied

### 1. `desktop/src/lib/stores/mosaic-layout.svelte.ts`

Extends `PaneKind` and adds an optional `config` map on `Pane`:

```diff
 export type PaneKind =
   | "session"
   | "issue"
   | "task"
   | "doc"
   | "file"
   | "terminal"
   | "changes"
-  | "knowledge";
+  | "knowledge"
+  | "agent_conversation";

 export interface Pane {
   id: string;
   kind: PaneKind;
   ref: string;
   title: string;
+  /** Optional pane-kind-specific config. Persisted verbatim through
+   *  localStorage. For agent_conversation: { sessionId?, cwd?, model? }. */
+  config?: Record<string, unknown>;
 }
```

`Pane.config` is JSON-safe so the existing `JSON.stringify` persistence
works unchanged. The Code Editor pane (per `code-editor-wiring.md`) had
already proposed this; this PR is the first to land it.

### 2. `desktop/src/lib/design/patterns/mosaic/PaneContent.svelte`

Adds a lazy-loaded dispatch arm:

```svelte
{:else if pane.kind === 'agent_conversation'}
  {#await import('$lib/design/patterns/mosaic/panes/AgentConversationPane.svelte')}
    <div class="pc-stub pc-stub--loading">Loading conversation…</div>
  {:then { default: AgentConversationPane }}
    {@const cfg = (pane.config ?? {}) as { sessionId?: string; cwd?: string; model?: string }}
    {@const tile = mosaicLayout.allTiles().find((t) => t.panes.some((p) => p.id === pane.id))}
    <AgentConversationPane
      sessionId={cfg.sessionId ?? (pane.ref && pane.ref !== 'new' && pane.ref.length > 8 ? pane.ref : undefined)}
      workspaceSlug="default"
      cwd={cfg.cwd ?? '~'}
      model={cfg.model ?? 'auto (cost-efficient)'}
      paneId={pane.id}
      tileId={tile?.id}
    />
  {:catch}
    <div class="pc-stub">Conversation pane failed to load.</div>
  {/await}
```

### 3. `desktop/src/lib/design/patterns/mosaic/MosaicTile.svelte`

Adds `Bot` icon import and the `agent_conversation` entry in `KIND_ICONS`.

### 4. `desktop/src/lib/design/patterns/mosaic/PanePicker.svelte`

Catalog gains a "New agent conversation" entry at the top, and
`KIND_LABELS` gains `agent_conversation: "Conversation"`.

### 5. `desktop/src/routes/build/+page.svelte`

The global `<Composer/>` and `<SlashCommands/>` rendering have been
**removed** from the route. The grid template drops its `composer` row.
Replaced with an `onMount` hook that seeds an empty
`agent_conversation` pane when the layout has no panes — so a fresh
`/build` lands the user on the prompt surface.

### 6. `desktop/src/lib/design/patterns/build/sections/TabsSection.svelte`

Right-click context menu expanded from a single "Close pane" entry to:

- **Fork in new pane** — calls `mosaicLayout.splitTile(tileId, "vertical", clone)` with a regenerated pane id; preserves `kind`, `ref`, `title`, and a shallow-cloned `config`.
- **Fork in new tab** — calls `mosaicLayout.openPane(clone, tileId)` with a regenerated pane id.
- **Delete** — calls `mosaicLayout.closePane(tileId, paneId)` (renamed from "Close pane"; styled with the danger color).

Both fork actions reuse existing store mutations — no new API.

## Pane manifest

```ts
import type { PaneKind } from "$lib/stores/mosaic-layout.svelte.js";

export const AGENT_CONVERSATION_MANIFEST = {
  paneType: "agent_conversation" satisfies PaneKind,
  label: "Agent Conversation",
  icon: "Bot",
  defaultConfig: {
    cwd: "~",
    model: "auto (cost-efficient)",
  },
  configSchema: {
    sessionId: { type: "string", required: false },
    cwd:       { type: "string", required: false },
    model:     { type: "string", required: false },
  },
};
```

## Default initial pane on `/build`

`+page.svelte` calls `mosaicLayout.load(workspaceSlug)` then opens a
fresh `agent_conversation` pane iff the layout is empty. This guarantees
the very first `/build` visit shows the conversation surface — matching
the reference design's "always land on a prompt" UX.

If a saved layout already contains panes, none are appended; the user's
existing layout is honored verbatim.

## Backend gap

The pane reuses `POST /api/v1/sessions` to create new conversations and
`GET /api/v1/sessions/:id/blocks` (via `BlockStream`) for the
transcript. **No new endpoints are required for the agent path.**

The shell-execute path (when the user accepts a `looksLikeShellCommand`
suggestion or presses ⌘\| to force shell mode) needs to terminate at the
existing PtyBridge:

- **Existing:** `Canopy.PtyBridge` (Tauri-side) handles `claude-local`
  PTY sessions today; that's how the `terminal` pane works.
- **Gap:** The conversation pane currently routes shell-mode submits
  through the same session as agent prompts. To get true shell
  execution we need either:
  1. A `runtimeType: "shell"` variant for `createSession` that the
     backend dispatches to PtyBridge directly (recommended — same
     resource, different runtime), or
  2. A `POST /api/v1/sessions/:id/exec` endpoint that runs a one-shot
     command through the session's already-attached PTY.

Option 1 lines up with how `terminal` panes already work and avoids a
new endpoint surface; tracked as a follow-up.

## TODOs

- [ ] **Wire shell-mode submits to PtyBridge.** Today the pane treats
      shell-mode as a no-op divergence from agent-mode (same submission
      path, mode flag carried through but unused). See "Backend gap"
      above.
- [ ] **`/model` slash command behavior.** The slash palette already
      surfaces `/model` (via existing SlashCommands), but the action
      currently fills the input rather than opening the model picker
      popover. Hook the picker once the model registry exists.
- [ ] **`/remote-control` slash command.** Same shape as `/model` —
      currently the chip is a toggle without backend.
- [ ] **`onCwdOpen` chip action** — needs the Tauri `shell-open` plugin
      bridge to land before it can reveal the cwd in Finder.
- [ ] **`paneId`/`tileId` lookup in PaneContent.** The dispatcher uses a
      linear scan via `mosaicLayout.allTiles()` to find the parent
      tile — fine for the current pane counts but worth indexing if the
      mosaic ever gets very large.
- [ ] **Composer draft mirroring** uses an `oninput` event delegation
      trick to read the inner `MentionInput`'s contenteditable value.
      Promote MentionInput's draft to `bind:`-able to remove the proxy.
- [ ] **Two-way `Pane` mutation in PaneContent** (writing `pane.ref` and
      `pane.config` after session creation) currently bypasses store
      actions. Add a `mosaicLayout.updatePane(...)` mutator for
      symmetry with the rest of the API.

## Constraints honored

- No competitor brand names anywhere in code, copy, or wiring.
- Intro card title is **"New conversation"** (no internal codenames).
- Composer / BlockStream / SlashCommands / Mosaic primitives all
  reused — no parallel implementations.
- Svelte 5 runes (`$state`, `$derived`, `$effect`, `$props`,
  `$bindable`) and TanStack Query throughout.
- All new files stay within their own ownership boundary
  (`desktop/`); shared mosaic edits are surgical and minimal.
