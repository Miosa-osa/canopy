> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Build module-integration wiring

These edits attach the new **module-integration layer** to existing shared
files. The agent that built the layer did NOT modify any of these — apply
by hand.

The integration layer composes Canopy's super-modules (Drive, Skills,
Templates, Runtimes, Sandboxes, Schedule) into the Build cockpit. Two
pieces ship:

1. A multi-source **slash-command registry** — `GET /api/v1/build/commands`
   returns commands aggregated from builtin / runtimes / drive / templates /
   skills.
2. **Module-launcher chips** in `ComposerChips.svelte` — quick access
   popovers that read from existing super-module endpoints.

Plus one new tool — `runtime.spawn` — that the BuildDispatcher consumes to
embed a runtime into the active pane.

---

## 1. `backend/lib/canopy_web/router.ex`

Add ONE new Build route inside the `/api/v1` scope. Insert directly after
the existing `set-default` line (~line 359):

```elixir
    # Build — multi-source slash command registry
    get "/build/commands", BuildController, :commands
```

Other Build routes in this scope are unchanged.

---

## 2. `backend/lib/canopy/application.ex`

Register the new `Canopy.Tools.Runtimes` tool module alongside the others.
Locate the boot Task block (~line 112–120) that calls
`Canopy.Tools.register_all_builtins/0` and registers Analytics / Sandboxes /
Schedule / Templates / SkillCurator / RuntimeAdapter / Build:

```elixir
          Canopy.Tools.register_all_builtins()

          # Existing super-module tool surfaces — already wired:
          Canopy.Tools.Registry.register_module(Canopy.Tools.Analytics)
          Canopy.Tools.Registry.register_module(Canopy.Tools.Sandboxes)
          Canopy.Tools.Registry.register_module(Canopy.Tools.Schedule)
          Canopy.Tools.Registry.register_module(Canopy.Tools.Templates)
          Canopy.Tools.Registry.register_module(Canopy.Tools.SkillCurator)
          Canopy.Tools.Registry.register_module(Canopy.Tools.RuntimeAdapter)
          Canopy.Tools.Registry.register_module(Canopy.Tools.Build)
```

Append one line:

```elixir
          Canopy.Tools.Registry.register_module(Canopy.Tools.Runtimes)
```

This activates the single new tool — `runtime.spawn` — that bridges adapter
registry → Sessions.create → BuildDispatcher.

`Canopy.Tools.RuntimeAdapter` is intentionally separate; it owns the
existing 16 runtime/MCP/skills/checkpoint tools. `Canopy.Tools.Runtimes`
owns the single embedding tool the cockpit needs.

---

## 3. BuildController action — `:commands`

Already added to `backend/lib/canopy_web/controllers/build_controller.ex`:

```elixir
operation :commands,
  summary: "List slash commands aggregated across builtin / runtimes / drive / templates / skills",
  parameters: [
    q: [in: :query, type: :string, required: false],
    limit: [in: :query, type: :integer, required: false]
  ],
  responses: [ok: {"Command list", "application/json", BuildSchema.CommandList}]

def commands(conn, params) do
  opts =
    []
    |> maybe_put(:q, params["q"])
    |> maybe_put(:limit, parse_limit(params["limit"]))

  json(conn, %{data: Commands.list(opts)})
end
```

---

## 4. `runtime.spawn` tool contract

Module: `Canopy.Tools.Runtimes` (new file, registered in step 2).

```
runtime.spawn:
  params:
    type            (string, required) — adapter type id, e.g. "claude-local"
    session_id      (string, optional) — embed an existing session if provided
    cwd             (string, optional)
    workspace_slug  (string, optional)
    agent_slug      (string, optional, defaults to "conductor")

  returns (success):
    {
      action: "embed_runtime",
      runtime_type: <type>,
      session_id:   <uuid>,
      embed_into_pane: true,
      cwd: <cwd | nil>
    }

  returns (failure):
    { reason: "unknown_runtime", type: <type> }
    { reason: "validation_failed", errors: [...] }
```

When `session_id` is omitted, the tool calls `Canopy.Sessions.create/1` so
governance + budget gates fire normally. When supplied, the tool trusts the
caller and emits the embed payload directly.

---

## 5. BuildDispatcher action additions

The frontend `BuildDispatcher` (`desktop/src/lib/stores/build-dispatcher.svelte.ts`)
gained three new branches in its `dispatch()` switch:

| Action | Behavior |
|---|---|
| `embed_runtime` | Opens an `agent_conversation` pane with `pane.config.embeddedRuntime` set. The existing AgentConversationPane reads this on mount and switches its body to `<EmbeddedRuntime/>`. |
| `apply_skill` | Emits a `window` CustomEvent `canopy:apply_skill` with `{ skill_slug, session_id }`. Active conversation panes listen for this. |
| `instantiate_template` | Emits a `window` CustomEvent `canopy:instantiate_template` with `{ template_slug, workspace_slug }`. The SvelteKit page listens and navigates to `/templates/[slug]`. |

No mutations to `AgentConversationPane.svelte`, `MosaicTile`, `MosaicRoot`,
or `PaneContent`. All three actions either route through `mosaicLayout.openPane`
(an existing API) or via DOM CustomEvents (zero coupling).

---

## 6. Frontend chip wiring

`ComposerChips.svelte` now exposes seven new prop callbacks:

```ts
onPickDriveEntry?: (reference, entry) => void;
onApplySkill?: (skill) => void;
onPickTemplate?: (template) => void;
onPickSandbox?: (sandboxId) => void;
onNewSandbox?: () => void;
onScheduleConversation?: () => void;
onPickSpec?: (slug) => void;
```

The parent (`ConversationComposer.svelte`) does not need to wire all of
them — unbound callbacks no-op. Suggested wiring:

| Callback | Suggested handler |
|---|---|
| `onPickDriveEntry` | Insert reference into composer textarea (existing `onAttach` style insertion) |
| `onApplySkill` | `buildDispatcher.dispatch({ action: "apply_skill", skill_slug })` |
| `onPickTemplate` | `buildDispatcher.dispatch({ action: "instantiate_template", template_slug })` |
| `onPickSandbox` | Open the sandbox in a new pane (`build.open_pane` with sandbox kind) |
| `onNewSandbox` | Navigate to `/sandboxes/new` or open a creation dialog |
| `onScheduleConversation` | Navigate to `/schedule/specs/new?conversation=...` |
| `onPickSpec` | Navigate to `/schedule/specs/[slug]` |

---

## 7. Constraints honored

- No edits to `application.ex` or `router.ex` directly — instructions only.
- No edits to `AgentConversationPane.svelte`, mosaic shells, or `PaneContent`.
- No new dependencies added.
- No competitor brand names referenced.
- Every popover handles Esc, outside click, focus trap on input, ARIA
  `role="dialog"` / `aria-label`. Loading / empty / error rendered for
  every fetch.
