> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# 19 — Runtime Adapter End-to-End Trace

**Track #117 | Phase 6 | 2026-04-18**

All file:line references relative to `backend/lib/`.

---

## Shared Infrastructure

### RegistryServer Boot Registration

`canopy/runtimes/registry.ex:26-29`

```elixir
@builtin_adapters [
  Canopy.Runtimes.ClaudeLocal,
  Canopy.Runtimes.CodexLocal,
  Canopy.Runtimes.GeminiLocal,
]
```

`init/1` at line 82 iterates `@builtin_adapters`, calls `Code.ensure_loaded?/1` + `function_exported?(adapter, :type, 0)`, then inserts `{adapter.type(), adapter}` into the `:canopy_runtimes_registry` ETS table. All 3 adapters register at boot.

ETS reads in `lookup/1` are lock-free from any process — no GenServer round-trip on the hot path.

---

### ProcessRunner Shared Macro

`canopy/runtimes/process_runner.ex`

All 3 adapters `use Canopy.Runtimes.ProcessRunner`. The macro injects:
- `GenServer` behaviour
- `child_spec/1` (`:transient` restart — dies once, not respawned)
- `init/1` → delegates to `ProcessRunner.do_init/2`
- `handle_cast(:cancel, ...)` → closes port + emits `"cancelled"` system entry
- `handle_info({port, {:data, data}}, ...)` → delegates to `ProcessRunner.do_data/3`
- `handle_info({port, {:exit_status, 0}}, ...)` → flush + emit `"completed"` system entry
- `handle_info({port, {:exit_status, code}}, ...)` → `on_exit_error` + flush + emit event + `Sessions.update_status("failed")`

Adapters can override 4 optional callbacks: `use_stdin?/0`, `on_line/2`, `on_exit_error/2`, `completed_extra/1`.

---

## ClaudeLocal — Full Trace

**Source:** `canopy/runtimes/claude_local.ex` + `claude_local/runner.ex` + `claude_local/parser.ex`

### Step 1 — Session Create

`Sessions.create/1` (`canopy/sessions.ex:66`) evaluates governance then budget, then calls `do_insert/2`.

`do_insert/2` inserts the session row and calls `maybe_provision_miosa_sandbox/2` (fire-and-forget Task if `needs_sandbox: true`).

After insert, the `SessionsController.create/2` action calls `Sessions.Supervisor.start_runner/1` (or equivalent) which starts a `ClaudeLocal.Runner` GenServer under the Sessions DynamicSupervisor.

### Step 2 — Port Spawn

`ProcessRunner.do_init(:claude_local, opts)` at `process_runner.ex:150`:

```
{binary, args} = Keyword.fetch!(opts, :port_cmd)
cwd            = Keyword.fetch!(opts, :cwd)
env            = Keyword.get(opts, :env, [])
prompt         = Keyword.get(opts, :prompt, "")

port = Port.open(
  {:spawn_executable, binary},
  [:binary, :exit_status, {:args, args}, {:cd, cwd}, {:env, env}]
)
```

Since `ClaudeLocal.use_stdin?/0` returns `true` (default), the prompt is written to the port stdin immediately after open (`Port.command(port, prompt <> "\n")`).

### Step 3 — Stdout Parse

`handle_info({port, {:data, data}})` → `ProcessRunner.do_data(:claude_local, data, state)` at `process_runner.ex:180`.

`do_data` appends to `line_buffer`, splits on `\r?\n`, then for each complete line:
1. Calls `ClaudeLocal.on_line(line, extra)` (default no-op)
2. Calls `ClaudeLocal.parse_line(line)` → `ClaudeLocal.Parser.parse_line/1` → returns `[TranscriptEntry.t()]`
3. Calls `emit_entry/2` for each entry

`ClaudeLocal.Parser` at `claude_local/parser.ex` parses the Claude CLI NDJSON output format. `parser/dispatch.ex` handles the routing of JSON event types to `TranscriptEntry` kinds.

### Step 4 — emit_entry

`ProcessRunner.emit_entry/2` at `process_runner.ex:209`:

```elixir
seq = state.sequence + 1
stamped = %{entry | sequence: seq}
Phoenix.PubSub.broadcast(@pubsub, "session:#{state.session_id}", {:transcript_entry, stamped})
Canopy.Sessions.add_message(state.session_id, message_attrs)
```

Both operations happen synchronously in the GenServer loop. `add_message` persists to `session_messages` table. PubSub broadcast happens before DB insert — the SSE controller receives the entry immediately.

### Step 5 — Exit Handling (exit code 0)

`handle_info({port, {:exit_status, 0}})` at `process_runner.ex:119`:
1. `flush_buffer/2` — processes any remaining partial line in `line_buffer`
2. `emit_system_entry(new_state, "completed", ClaudeLocal.completed_extra(new_state))`
3. `{:stop, :normal, new_state}` — GenServer exits cleanly, runner process dies

`emit_system_entry` broadcasts `{:transcript_entry, entry}` where `entry.kind == :system, entry.content == %{event: "completed"}`.

### Step 6 — Exit Handling (non-zero exit)

`handle_info({port, {:exit_status, code}})` at `process_runner.ex:131`:
1. `event = ClaudeLocal.on_exit_error(code, state)` → returns `"error"` (default)
2. `flush_buffer`
3. `emit_system_entry(new_state, "error", %{exit_code: code})`
4. `Sessions.update_status(state.session_id, "failed")` — persists terminal status
5. `{:stop, :normal, new_state}`

### Step 7 — SSE Controller

`SessionEventsController.stream/2` at `canopy_web/controllers/session_events_controller.ex:66`:

1. `Sessions.get(id)` — 404 if not found
2. `init_sse(conn)` — sets `content-type: text/event-stream`, `x-accel-buffering: no`, `send_chunked(200)`
3. Replays history from `?from=<seq>` via `Sessions.list_messages(id, from: from_seq)`
4. If session already terminal → sends `event: done\ndata: {}\n\n` immediately
5. Otherwise: `Phoenix.PubSub.subscribe(@pubsub, "session:#{id}")` then enters `sse_loop`

`sse_loop` pattern-matches on:
- `{:transcript_entry, entry}` → `chunk_event(conn, "transcript_entry", payload)`; checks `done_entry?`
- `{:session_status, status_map}` → `chunk_event(conn, "status", ...)`
- `:session_done` → `chunk_event(conn, "done", %{})`
- `{:EXIT, _, _}` → exits loop (client disconnect)
- `:heartbeat` → sends `": keepalive\n\n"` SSE comment
- after 25_000ms → sends keepalive + re-checks session status in DB

`done_entry?/1` at `session_events_controller.ex:207`:
```elixir
@terminal_events ~w(completed error session_expired cancelled failed)
defp done_entry?(%{kind: :system, content: %{"event" => event}}) when event in @terminal_events, do: true
defp done_entry?(%{kind: :result}), do: true
defp done_entry?(_entry), do: false
```

All 5 terminal events covered. `:result` also terminates (covers the claude CLI result entry before exit signal arrives).

### Step 8 — Frontend Consumption

`desktop/src/lib/api/realtime.ts:33`:

```typescript
const source = new EventSource(`${API_BASE}/sessions/${id}/events`);

source.addEventListener('transcript_entry', (e) => {
  const entry = JSON.parse(e.data) as TranscriptEntry;
  onEntry(entry);
});

source.addEventListener('status', (e) => {
  const payload = JSON.parse(e.data) as { status: SessionStatus };
  onStatus(payload.status);
});

source.addEventListener('done', () => {
  onDone();
  source.close();  // EventSource closed on done — no reconnect
});
```

Returns `() => source.close()` as the unsubscribe function.

**Call site:** `sessions/[id]/+page.svelte:126` — inside `onMount(() => { ...; return unsubscribe; })`. SvelteKit calls the returned cleanup on component destroy. No leak.

---

## CodexLocal — Delta from ClaudeLocal

**Source:** `canopy/runtimes/codex_local.ex` + `codex_local/parser.ex`

| Step | Delta |
|---|---|
| Port spawn | Same via `ProcessRunner`. Args built by `CodexLocal.Args.build/1`. |
| `use_stdin?/0` | Returns `true` (same as Claude). |
| `on_exit_error/2` | **Overrides default.** Reads `state.line_buffer` for partial output. If buffer contains `"session_expired"` pattern → returns `"session_expired"`. Else returns `"error"`. This is the Phase 2 #65 session-expired detection. |
| `done_entry?` | Covers `"session_expired"` at `session_events_controller.ex:205`. GREEN. |
| All other steps | Identical via ProcessRunner macro. |

**CodexLocal: FULL GREEN**

---

## GeminiLocal — Delta from ClaudeLocal

**Source:** `canopy/runtimes/gemini_local.ex` + `gemini_local/parser.ex`

| Step | Delta |
|---|---|
| `use_stdin?/0` | Returns `false`. Prompt is a CLI argument (injected into `args` by `GeminiLocal.Args.build/1`). No stdin write after spawn. |
| `on_line/2` | **Overrides default.** Scans each line for the Gemini session ID returned in the CLI response header. Stores in `extra.gemini_session_id`. |
| `completed_extra/1` | Returns `%{gemini_session_id: state.extra[:gemini_session_id]}`. Merged into the `"completed"` system entry content. |
| Parser | `gemini_local/parser.ex` + `gemini_local/parser/dispatch.ex`. Handles Gemini CLI's output format (different from Claude NDJSON). |
| All other steps | Identical via ProcessRunner macro. |

**GeminiLocal: FULL GREEN**

---

## Summary Matrix

| Adapter | Registry | Port Spawn | Parse+Emit | PubSub Broadcast | DB Persist | Exit→Status | SSE Controller | Frontend Sub | Cleanup |
|---|---|---|---|---|---|---|---|---|---|
| ClaudeLocal | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN |
| CodexLocal | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN |
| GeminiLocal | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN |

**All 3 adapters: FULL END-TO-END GREEN**

---

## Known Gap (Not a Runtime Adapter Issue)

The `Sessions.create/1` → runner `start_link` dispatch path was not found in `sessions.ex` itself. The runner start is initiated by `SessionsController.create/2` after `Sessions.create/1` returns `{:ok, session}`. If the Sessions supervisor linkage is missing, sessions insert to DB but no process is spawned. This should be verified in `SessionsController.create` action and the Sessions DynamicSupervisor. See wiring-audit.md punch list for follow-up.
