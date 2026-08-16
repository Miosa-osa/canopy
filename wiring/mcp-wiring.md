# MCP Tools pane — wiring instructions

The MCP Tools pane (`McpPane.svelte`) lists every tool registered in
`Canopy.Tools.Registry`, lets the operator dispatch a test invocation through
the existing `AgentToolsController`, and shows a tail of recent tool calls
plus connected MCP servers.

This module owns no shared files. The changes below must be applied by an
agent that owns the corresponding shared file.

## 0. Reuse summary (no new primitives created)

| Surface | Existing primitive | Where it lives |
|---------|--------------------|----------------|
| Tool registry | `Canopy.Tools.Registry.list/1` (ETS-backed) | `backend/lib/canopy/tools/registry.ex` |
| List endpoint | `CanopyWeb.ToolsController.index/2` | `backend/lib/canopy_web/controllers/tools_controller.ex` |
| Test invocation | `POST /api/v1/agents/tools/:tool_name` (governance + audit) | `backend/lib/canopy_web/controllers/agent_tools_controller.ex` |
| Invocation log | `Canopy.Agents.ToolCalls.list/1` (audit table) | `backend/lib/canopy/agents/tool_calls.ex` |
| Schema-driven form | `RuntimeConfigForm.svelte` (`ConfigFieldSchema[]`) | `desktop/src/lib/design/patterns/RuntimeConfigForm.svelte` |
| UI primitives | `Button`, `Input`, `Select`, `Textarea`, `Toggle`, `Alert` | `desktop/src/lib/design/foundation/` |
| Sessions list (for invoker session picker) | `sessionsQuery({ limit })` | `desktop/src/lib/api/queries/sessions.ts` |

Two **new** thin controller actions are added (no parallel registry):

- `GET /api/v1/mcp/servers` — Phase A stub returning `{data: []}`.
- `GET /api/v1/mcp/tool-calls` — global tail of `Canopy.Agents.ToolCalls.list/1`.

Both live in `CanopyWeb.MCPController` (new file, owned by backend).

## 1. Phoenix router

In `backend/lib/canopy_web/router.ex`, inside the `scope "/api/v1", CanopyWeb`
block (the same scope that mounts `tools` and `agents`), add:

```elixir
# MCP read views (desktop MCP Tools pane)
get "/mcp/servers",    MCPController, :servers
get "/mcp/tool-calls", MCPController, :tool_calls
```

No existing routes change. The new path prefix `/mcp/*` does not conflict.

## 2. Pane manifest

The Mosaic registers panes in two shared files. Apply both by hand
(`PaneContent.svelte` and `PanePicker.svelte` are mosaic shells, off-limits to
this module).

### 2a. `desktop/src/lib/stores/mosaic-layout.svelte.ts`

Extend the `PaneKind` union with `"mcp"`:

```ts
export type PaneKind =
  | "session"
  | "issue"
  | "task"
  | "doc"
  | "file"
  | "terminal"
  | "changes"
  | "knowledge"
  | "mcp";
```

### 2b. `desktop/src/lib/design/patterns/mosaic/PaneContent.svelte`

Add a new `{:else if}` branch dispatching to the lazy-loaded `McpPane`:

```svelte
{:else if pane.kind === 'mcp'}
  {#await import('$lib/design/patterns/mosaic/panes/McpPane.svelte')}
    <div class="pc-stub pc-stub--loading">Loading MCP Tools…</div>
  {:then { default: McpPane }}
    <McpPane />
  {:catch}
    <div class="pc-stub">MCP Tools pane failed to load.</div>
  {/await}
```

Also extend `KIND_LABELS` in the same file (if it's defined here — it is in
`PanePicker.svelte`; see 2c).

### 2c. `desktop/src/lib/design/patterns/mosaic/PanePicker.svelte`

Two edits:

1. Import the icon at the top:

   ```ts
   import { X, Plug } from 'lucide-svelte';
   ```

2. Append a catalog entry (and update `KIND_LABELS`):

   ```ts
   const catalog: PickerItem[] = [
     // …existing entries…
     { id: 'p11', kind: 'mcp', ref: 'mcp-root', title: 'MCP Tools', description: 'Tool registry' },
   ];

   const KIND_LABELS: Record<PaneKind, string> = {
     session: 'Session', issue: 'Issue', task: 'Task', doc: 'Doc',
     file: 'File', terminal: 'Terminal', changes: 'Changes', knowledge: 'Knowledge',
     mcp: 'MCP',
   };
   ```

The `Plug` icon lives in `lucide-svelte` and matches the Mosaic icon style.

### Pane manifest (if a registry of pane types is introduced later)

```ts
{
  paneType: "mcp",
  label: "MCP Tools",
  icon: "Plug",
  defaultConfig: { selectedTool: null, autoTail: true }
}
```

## 3. Backend routes added

| Method | Path | Controller | Notes |
|--------|------|------------|-------|
| GET | `/api/v1/mcp/servers` | `MCPController.servers/2` | Phase A: returns `{data: []}` |
| GET | `/api/v1/mcp/tool-calls` | `MCPController.tool_calls/2` | Wraps `Canopy.Agents.ToolCalls.list/1`; supports `status` and `limit` (capped at 1000) |

The existing `GET /api/v1/tools`, `GET /api/v1/tools/:name`, and
`POST /api/v1/agents/tools/:tool_name` are untouched and reused as-is.

## 4. Realtime invocation log (Phase B)

Phase A polls `/api/v1/mcp/tool-calls` every 5s via TanStack Query
(`refetchInterval: 5_000`). When PubSub fan-out is wired in Phase B, broadcast
on the topic:

```
"mcp:tool_calls"
```

Payload mirrors the serialized `ToolCall` row. The pane subscribes via the
existing Phoenix Channel infrastructure (see `analytics-realtime` for prior
art when ready).

## 5. Phase B — server management

`/api/v1/mcp/servers` is a stub today. When Track J ships, replace
`MCPController.servers/2` with a query against the new
`Canopy.MCP.Servers` context and add:

```
POST   /api/v1/mcp/servers           — connect server
PATCH  /api/v1/mcp/servers/:id       — toggle / reconfigure
DELETE /api/v1/mcp/servers/:id       — disconnect
```

The existing pane (`McpServerList.svelte`) already renders a Toggle per row
(disabled in Phase A) so it picks up live servers without UI changes.

## 6. Files added by this module

```
desktop/src/lib/domain/mcp/types.ts
desktop/src/lib/api/queries/mcp.ts
desktop/src/lib/design/patterns/mosaic/panes/McpPane.svelte
desktop/src/lib/design/patterns/mosaic/panes/mcp/ToolList.svelte
desktop/src/lib/design/patterns/mosaic/panes/mcp/ToolDetail.svelte
desktop/src/lib/design/patterns/mosaic/panes/mcp/ToolInvoker.svelte
desktop/src/lib/design/patterns/mosaic/panes/mcp/InvocationLog.svelte
desktop/src/lib/design/patterns/mosaic/panes/mcp/McpServerList.svelte
backend/lib/canopy_web/controllers/mcp_controller.ex
backend/test/canopy_web/controllers/mcp_controller_test.exs
```

No existing files are edited by this module — apply sections 1, 2a, 2b, 2c
manually (or via a follow-up agent that owns the mosaic shells and router).
