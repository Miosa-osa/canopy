> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Block primitive wiring

Surgical wiring required to bring the **Block primitive** online. All new
files (migration, schema, context, controller, OpenAPI schema, tests, and
all desktop components) are already in place — the integration listed
below is what the main agent owns.

## Files already created (this task)

### Backend

| Path | Change |
|------|--------|
| `backend/priv/repo/migrations/20260429000001_create_session_blocks.exs` | NEW — `session_blocks` table + indexes |
| `backend/lib/canopy/sessions/block.ex` | NEW — Ecto schema + changeset |
| `backend/lib/canopy/sessions/blocks.ex` | NEW — context module: `list/1`, `get/1`, `create/1`, `update_status/2`, `mark_finished/2`, `aggregate_by_kind/1`, `count/1`, `find_pending_approval/1`, `search/1` |
| `backend/lib/canopy_web/controllers/blocks_controller.ex` | NEW — `index`, `show`, `search` |
| `backend/lib/canopy_web/schemas/blocks_schema.ex` | NEW — OpenAPI schemas |
| `backend/test/canopy/sessions/blocks_test.exs` | NEW — context tests |
| `backend/test/canopy_web/controllers/blocks_controller_test.exs` | NEW — controller tests |

### Desktop

| Path | Change |
|------|--------|
| `desktop/src/lib/domain/blocks/types.ts` | NEW — `Block`, `BlockKind`, `BlockStatus`, `BlockListQuery`, `BlockSearchQuery` |
| `desktop/src/lib/api/queries/blocks.ts` | NEW — TanStack factories `blocksListQuery`, `blockQuery`, `blocksSearchQuery`, `blocksKey` |
| `desktop/src/lib/design/patterns/blocks/Block.svelte` | NEW — single-block renderer |
| `desktop/src/lib/design/patterns/blocks/BlockStream.svelte` | NEW — vertical scroll list of blocks |
| `desktop/src/lib/design/patterns/blocks/CommandBlock.svelte` | NEW — `kind=command` body |
| `desktop/src/lib/design/patterns/blocks/AgentMessageBlock.svelte` | NEW — `kind=agent_message` body |
| `desktop/src/lib/design/patterns/blocks/ToolCallBlock.svelte` | NEW — `kind=tool_call` / `tool_result` body |
| `desktop/src/lib/design/patterns/blocks/ApprovalBlock.svelte` | NEW — `kind=approval` body, wired to existing `/api/v1/governance/approvals` via `approveApprovalMutation` / `rejectApprovalMutation` |
| `desktop/src/lib/design/patterns/blocks/SystemEventBlock.svelte` | NEW — `kind=system_event` / `error` / `diff` body |

## Files NOT modified (per task constraints)

- `backend/lib/canopy_web/router.ex` — main agent adds the routes (see below)
- `backend/lib/canopy/application.ex` — no supervision-tree change needed
- `desktop/src/lib/stores/mosaic-layout.svelte.ts` — main agent extends the
  `PaneKind` union
- `desktop/src/lib/design/patterns/mosaic/PaneContent.svelte` — main agent
  adds the dispatch branch
- `desktop/src/lib/design/patterns/mosaic/PanePicker.svelte` — main agent
  adds the picker entry
- `desktop/src/lib/design/patterns/MosaicTile.svelte` — unchanged
- `desktop/src/lib/design/patterns/TranscriptView.svelte` — unchanged. The
  Block stream is **beside** TranscriptView, not a replacement.

## Routes to register in `router.ex`

Add inside the `scope "/api/v1", CanopyWeb do` block, alongside the
existing `sessions/:id/...` routes:

```elixir
# Block primitive — agentic-terminal navigation unit
get "/sessions/:session_id/blocks", BlocksController, :index
get "/sessions/:session_id/blocks/search", BlocksController, :search
get "/sessions/:session_id/blocks/:id", BlocksController, :show
```

Order matters: `search` must be declared **before** `:id` so the literal
path takes precedence over the parameter.

## PaneContent integration (notes only — main agent applies)

Once the main agent introduces a `block_stream` pane kind, the dispatch
branch in `PaneContent.svelte` should look like:

```svelte
{:else if pane.kind === 'block_stream'}
  {@const sessionId = pane.ref}
  <BlockStream {sessionId} />
```

`pane.ref` carries the `session_id` UUID. `BlockStream.svelte` already
fetches and renders. No additional fetcher / store wiring is required —
TanStack handles invalidation through the `["blocks", sessionId]` key
exposed by `blocksKey(sessionId)`.

## Mosaic Pane schema — no migration needed

The current `Pane` shape is:

```ts
{ id: string; kind: PaneKind; ref: string; title: string }
```

The Block stream slots in by extending the `PaneKind` union with
`"block_stream"` and using `pane.ref` for the session UUID. **No new
column** (`content_type` / `content_config`) is required at this stage —
the existing `kind + ref` pair is sufficient. If the Mosaic ever grows
configurable per-pane settings (filters, presets), that is the moment to
add `content_config: jsonb` to the Pane row, not now. Beer's constraint:
add structure when the situation demands variety; keep it minimal until
then.

## Reused primitives (per the no-duplication mandate)

The Block primitive composes existing infrastructure rather than
duplicating it:

- **Governance approvals** — `ApprovalBlock.svelte` calls the existing
  `approveApprovalMutation` / `rejectApprovalMutation` from
  `desktop/src/lib/api/queries/governance.js`. No new endpoint, no new
  mutation surface.
- **Foundation Button** — `ApprovalBlock.svelte` uses `Button` from
  `$lib/design/foundation`. No bespoke button.
- **HTTP client** — `desktop/src/lib/api/queries/blocks.ts` uses the
  existing `apiGet` from `$lib/api/client.js`. Snake/camel conversion
  layer reused unchanged.
- **TanStack Query** — `BlockStream.svelte` and `ApprovalBlock.svelte`
  use `createQuery` / `createMutation` / `useQueryClient` from
  `@tanstack/svelte-query` already in the project.
- **Lucide icons** — same icon set used everywhere else in `patterns/`.
- **Sessions schema** — `Block.session_id` references the existing
  `sessions` table (`on_delete: :delete_all` matches `session_messages`).
- **TranscriptView** stays untouched. The two views coexist.

No new primitives were introduced; no existing primitives were
duplicated.
