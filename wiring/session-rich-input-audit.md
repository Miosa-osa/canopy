> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Session Rich Input + Persistence Audit

## Current State

| Component | What it does | Rich Input? | Prompt injection? | Persistence? |
|---|---|---|---|---|
| `+page.svelte` `/sessions/[id]` | Session detail: header, TerminalHarness left, sidebar right, input bar bottom | No | Fork only (spawns new session via `POST /sessions`) | No — input bar always forks; no in-session injection |
| `TerminalSession.svelte` | xterm.js + Phoenix Channel `terminal:session:<id>`, scrollback replay on mount via `fetchScrollback` | No | `sendInput(data)` exported — writes raw bytes to PTY | Yes — scrollback replay (`lastN: 1000`) on mount |
| `TerminalHarness.svelte` | Toolbar chrome (pause, stop, fork, screenshot, observer) wrapping `TerminalSession`. Captures `onReady` callback to hold `sendInput` ref | No | Toolbar slash cmds write to PTY via `sendInput` | Delegates to `TerminalSession` |
| `RichInputToggle.svelte` | Stateless ⌃G pill chip; fires `onToggle` callback; global `window` keydown listener on mount | Renders the toggle | Parent owns state | No own state — parent persists to `pane.config` |
| `ConversationComposer.svelte` | Wraps `Composer.svelte` + `ComposerChips` + `ShellCommandHint`. Hides textarea when `richInputOn=false` + runtime embedded | Full Rich Input UI | `onSubmit` → parent routes to `runtimeSendInput` or session create | No own state |
| `AgentConversationPane.svelte` | Mosaic tile pane: `EmbeddedRuntime` OR `BlockStream` OR intro card + `ConversationComposer`. Persists `embeddedRuntime.richInputOn` to `mosaicLayout` | Full — toggle wired via `handleRichInputToggle` | `runtimeSendInput` piped to `TerminalSession.sendInput` via `EmbeddedRuntime.onSendInputReady` | Yes — `persistConfig()` writes to mosaic layout store on every change |
| `sessions.ts` (API) | `listSessions`, `getSession`, `createSession`, `cancelSession`, `pauseSession`, `resumeSession`, `stopSession`, `listSessionMessages` (GET only), `cleanupWorktree`, fork via `createSession({parentSessionId})` | n/a | No `POST /sessions/:id/messages` — GET only | `sessionMessagesQuery` factory exists but no write mutation |

## Gaps

1. **No Rich Input on `/sessions/[id]`** — The input bar at the bottom is a plain `<textarea>` that only forks. `RichInputToggle`, `ConversationComposer`, and the ⌃G shortcut exist in `AgentConversationPane` but are not wired into the session detail page at all.

2. **Input bar forks instead of injecting** — Submitting the bottom bar spawns a new session (`POST /sessions` with `parentSessionId`). There is no path to send a follow-up prompt into the *running* session's PTY from this page. The PTY injection path (`sendInput` on `TerminalSession`) exists but is only accessible through `TerminalHarness`, which has no public callback out to the page.

3. **`POST /sessions/:id/messages` write path does not exist** — `sessions.ts` has a read-only `listSessionMessages` / `sessionMessagesQuery` factory. No mutation to POST a message into a running session. Backend endpoint existence is unconfirmed; frontend has zero coverage.

4. **`AgentConversationPane` Rich Input + persistence is Mosaic-only** — The full Rich Input stack (toggle, composer visibility, `pane.config` persistence, `runtimeSendInput` callback chain) is scoped entirely to the Mosaic tile system. `/sessions/[id]` is a standalone route with no `mosaicLayout` integration.

5. **Scrollback replay on `TerminalSession` is fire-and-forget** — `fetchScrollback` runs async after mount and writes to xterm additively. There is no ordering guarantee relative to live channel output; fast-arriving live output can interleave with replayed scrollback. No deduplication or cursor anchoring.

6. **Agent-to-agent prompt injection has no dedicated path** — There is no API call, event bus, or component prop for one agent/session to inject a structured prompt into another. The only injection mechanism is raw PTY stdin via `sendInput(data)`, which is session-local and untyped.

## Recommended Architecture

### Rich Input on `/sessions/[id]`

Replace the bottom `sd-input-bar` `<textarea>` with a full `ConversationComposer` instance. Wire:
- `embeddedRuntimeType={session?.runtimeType}` so the composer knows a runtime is present
- `richInputOn` as local `$state` (default `true`), persisted to `localStorage` keyed by `sessionId`
- `onSubmit` → call `TerminalHarness`'s `sendInput` callback rather than `handleFork`
- Expose `sendInput` out of `TerminalHarness` via a new prop `onSendReady?: (fn) => void` (mirrors `AgentConversationPane`'s `onSendInputReady` pattern already on `EmbeddedRuntime`)
- `RichInputToggle` is embedded inside `ConversationComposer` via `ComposerChips` — no extra wiring needed

### Prompt Injection into Running Session

Two modes needed:
1. **Rich Input ON**: composer `onSubmit` → `sendInput(`${prompt}\n`)` to PTY (same as `AgentConversationPane.handleSubmit`)
2. **Rich Input OFF**: keystrokes flow direct to xterm; composer hidden (already implemented in `ConversationComposer`)

`POST /sessions/:id/messages` should be implemented for structured prompt injection (non-PTY path) — useful for agent-to-agent calls where raw PTY is wrong. Until backend ships, fall back to PTY stdin.

### Agent-to-Agent Prompt Injection

Add `injectPrompt(sessionId: string, prompt: string): Promise<void>` to `sessions.ts` that calls `POST /sessions/:id/messages`. Callers (conductor, Build orchestrator, any pane) call this instead of touching PTY directly. The receiving session's terminal channel broadcasts the injected content as `output` events, keeping xterm in sync automatically.
