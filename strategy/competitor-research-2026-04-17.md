# Canopy Competitor Research — Gap Analysis & Rebuild Plan

**Date:** 2026-04-17
**Author:** Roberto (via deep-dive of 5 shipping competitors)
**Status:** Draft — needs Roberto's decisions on Phase 1 scope

---

## TL;DR

**Diagnosis:** Canopy is not behind on features. It is 3–5× ahead on scope vs. competitors. The gap is **polish, design system rigor, and UX surface craftsmanship** — not features.

**Rebuild:** Three phases, 5 weeks total. Phase 1 (Design System) unblocks everything else. Most competitor lifts are front-end; our Elixir backend is already more sophisticated than any of theirs.

---

## The 5 Competitors — Thesis Per Repo

| Repo | Stack | Thesis | Relevance |
|------|-------|--------|-----------|
| **Cabinet** | Next.js + Electron + shadcn + Tiptap + xterm + node-pty + SQLite | Markdown KB + agents + cron + PTY terminal | **Design gold.** Direct visual/UX reference. |
| **Multica** | Next.js + Go/Chi + Postgres/pgvector | Agents as teammates on kanban, unified runtime abstraction | **Data-model gold.** `(actor_type, actor_id)` sibling pattern. |
| **Core-OSS** | React 19 + Vite + Tailwind 4 + Supabase | All-in-one Notion+Slack clone | **Shell pattern gold.** Inset card + module lazy loading. |
| **SuperHQ** | Rust + GPUI | Sandboxed agent VMs, zero-knowledge auth gateway | **Defer.** Runtime hardening phase, not polish. |
| **Gradient-bang** | React + Python + Pipecat | Voice+LLM multiplayer universe | **Defer.** Voice layer, future phase. |

---

## The Diagnosis — In Concrete Terms

**Canopy today:**
- 54 controllers, 56 schemas, 67 migrations, ~151 routes (backend)
- 56 pages, 20 component groups, 48 stores (frontend)
- 330+ agents, heartbeat protocol, session chains, governance gates, 5-layer org hierarchy, adapter dispatch, budget enforcement, virtual pixel-art office

**Cabinet today:**
- Single daemon, ~40 API routes
- Composer + file tree + xterm terminal + 13 themes
- Feels polished.

**Competitors ship less and make it feel premium. We ship more and it feels rough.** That's the entire problem.

---

## Phase 1 — Design System Foundation (Week 1)

> **Goal:** Build the token system right. Everything else reskins off this.
> **Unblocks:** All downstream polish work.

### 1.1 Token layer — steal from Cabinet

Cabinet uses **OKLCh-only**, no HSL. Every color is `oklch(L C H / alpha)`. Perceptually uniform — deriving dark variants is `L * 0.15`, not guesswork.

**Decision needed from Roberto:** OKLCh or HSL? Your memory says "HSL CSS vars" for MIOSA artifacts. Cabinet proves OKLCh is technically superior for theme derivation. Flagging this before committing.

**Radius scale via `calc()`:**
```css
--radius: 0.625rem;
--radius-sm: calc(var(--radius) * 0.6);
--radius-md: calc(var(--radius) * 0.8);
--radius-lg: var(--radius);
--radius-xl: calc(var(--radius) * 1.4);
--radius-2xl: calc(var(--radius) * 1.8);
```

**Typography scale (Cabinet editor):**
- Body: 15px, 1.65 line-height, -0.011em tracking
- H1: -0.025em tracking
- H2: -0.02em tracking
- Editorial feel, not UI feel

**Terminal colors via `color-mix()`:**
```css
--terminal-bg: color-mix(in oklch, var(--card) 94%, black 6%);
--terminal-ansi-red: color-mix(in oklch, var(--destructive) 80%, var(--foreground) 20%);
/* ... all 16 ANSI colors derived, never hardcoded */
```
Terminal is always on-brand, instant theme switch, zero config.

### 1.2 Shell pattern — steal from Core-OSS

The premium desktop feel is one CSS trick:
```tsx
// Outer: sidebar bg shows through
<div className="bg-[sidebar-bg] h-screen flex">
  <Sidebar />
  <div className="flex-1 pt-2 pr-2 pb-2 gap-2"> {/* the inset gap */}
    <main className="rounded-lg bg-[main-bg]">
      {/* content */}
    </main>
  </div>
</div>
```
3 lines, instant polish. Canopy's current shell likely doesn't have this.

### 1.3 Motion primitives

**Running agent glow (Cabinet `.cabinet-card-glow`):**
```css
@keyframes agent-pulse {
  0%, 100% { box-shadow: 0 0 0 0 oklch(var(--success) / 0.15); }
  50%      { box-shadow: 0 0 24px 4px oklch(var(--success) / 0.30); }
}
.agent-running { animation: agent-pulse 2s ease-in-out infinite; }
```

Plus: fade-in-up for list items, scale-98→100 on card hover, `transition-colors duration-150` default.

### Phase 1 Deliverables

- [ ] `src/lib/styles/tokens.css` — color + radius + spacing + typography tokens (OKLCh or HSL, decided)
- [ ] `src/lib/styles/motion.css` — keyframes + transition presets
- [ ] `src/lib/styles/terminal.css` — xterm theme derived from tokens
- [ ] `+layout.svelte` — inset shell pattern (Core-OSS trick)
- [ ] Smoke test: swap theme var → everything updates, no breakage

---

## Phase 2 — Agent UX Surface (Weeks 2–3)

> **Goal:** The composer → terminal → conversation flow. The thing Roberto actually uses every day.

### 2.1 Composer (steal from Cabinet)

**Home screen:**
- Serif heading: "Good morning, Roberto. What are we working on today?" (time-aware)
- Composer card: `rounded-2xl border border-border bg-card`, 13px textarea, **no focus ring** (border handles it — crucial subtle detail)
- Bottom-left: agent picker pill (`{emoji} {name} · {role}`)
- Bottom-right: runtime/effort picker (haiku / sonnet / opus, low / medium / high effort)
- `@` mention opens unified dropdown: agents (switches agent silently) + KB pages (adds as injection chip)

### 2.2 Live PTY terminal (Canopy already has xterm.js)

**Current Canopy:** `@xterm/xterm` + `@xterm/addon-fit/search/web-links` already in `canopy/desktop/package.json`.

**Upgrade from Cabinet:**
- Terminal colors from `color-mix()` tokens, not hardcoded
- Running state: green glow pulse on the terminal card
- When agent completes → smooth transition from terminal view to parsed result view

### 2.3 Structured epilogue contract (steal from Cabinet)

Every agent's system prompt appends:
```markdown
End every response with a ```cabinet``` code block containing:
- SUMMARY: one-line summary of what you did
- CONTEXT: bullet list of files/entities you touched
- ARTIFACT: the actual output (diff, doc, answer)
```
Canopy parses this block to track KB touches + surface artifacts. **Forces structure out of unstructured CLI output.** Low-effort, high-leverage. Canopy's equivalent block name: ` ```canopy ` (same vibe).

### 2.4 Shared `ActorAvatar` (steal from Multica)

**The pattern:**
```svelte
<!-- ActorAvatar.svelte -->
<script>
  export let actor; // { type: 'human' | 'agent', id, name, avatar? }
</script>
<div class="avatar">
  {#if actor.type === 'human'}
    <span>{initials(actor.name)}</span>
  {:else}
    <Bot class="size-4" />
  {/if}
</div>
```
Used EVERYWHERE humans and agents coexist: comments, assignees, authors, @mentions. Agent = sibling of human in every join, not a child. Canopy should audit all places that currently only show humans and switch to ActorAvatar.

### 2.5 Push-panel for agent output (steal from Core-OSS)

Agent output panel should be a **sibling to main content, not an overlay**. 340px animated panel toggled by `uiStore.agentPanelOpen`. Pushes content left, doesn't cover it. Premium feel + no z-index wars.

### 2.6 Session reconnect after reload (steal from Cabinet)

Store running session IDs in `sessionStorage` on every mutation. On page reload, `restoreSessionsFromStorage()` re-subscribes to the daemon's WebSocket for each. Live terminals pick up mid-stream. **Canopy already has session chains — just needs the frontend reconnect glue.**

### Phase 2 Deliverables

- [ ] `src/lib/components/chat/Composer.svelte` — composer card with agent/runtime pickers + `@` mention
- [ ] `src/lib/components/shared/ActorAvatar.svelte` — used in ≥ 6 places
- [ ] `src/lib/components/sessions/LiveTerminal.svelte` — xterm + glow pulse + epilogue parse
- [ ] `src/lib/components/layout/AgentPushPanel.svelte` — 340px sibling panel
- [ ] `useSessionReconnect` store + sessionStorage persistence
- [ ] Canopy epilogue spec doc: `protocol/agent-epilogue.md`

---

## Phase 3 — Information Architecture (Weeks 4–5)

> **Goal:** 20 component groups organized so nothing feels cluttered.

### 3.1 Module lazy loading (steal from Core-OSS)

Every module is `lazy()` + route-level: `/workspace/:workspaceId/:moduleType`. Modules don't import each other. Cross-module state → Zustand stores only. **No shared context providers.** This is a discipline fix, not new code — enforce it via code review.

**Canopy equivalent:** each of the 20 component groups (agents, chat, costs, dashboard, dispatch, documents, goals, inbox, issues, library, logs, memory, office, schedules, sessions) gets its own route + its own store. Shared state goes in a tiny set of global stores (workspace, auth, currentAgent).

### 3.2 WS-as-invalidation (steal from Multica)

**Pattern:** WebSocket event with sequence number → write into TanStack Query cache (or Svelte query equivalent) → UI reacts. 100ms debounce on invalidation to prevent storms. **No Zustand store duplication of server data.**

Canopy has Phoenix PubSub + SSE. Same pattern: SSE event → invalidate the right query cache → UI updates. Stop storing server data in Zustand stores.

### 3.3 Runtime adapter interface (already partially in Canopy)

Multica's `Backend` interface:
```go
type Backend interface {
  Execute(ctx, prompt, opts) (*Session, error)
}
type Session struct {
  Messages chan Message  // stream: tool calls, thinking, text
  Result   chan Result   // final outcome
}
```
Canopy already has adapter dispatch. Audit: does every adapter return this two-channel shape? If not, unify.

### 3.4 Sidebar — AVOID Core-OSS's mistake

Core-OSS's `Sidebar.tsx` is 600+ lines — a monolith. Do NOT replicate. Break Canopy's sidebar into composed sections: `<SidebarWorkspace>`, `<SidebarModules>`, `<SidebarAgents>`, `<SidebarFooter>`. Each ≤ 150 lines.

### Phase 3 Deliverables

- [ ] Audit: every module in its own route, own store
- [ ] `src/lib/api/realtime.ts` — SSE → query cache invalidation pattern
- [ ] Adapter audit: confirm all adapters return Session{Messages, Result}
- [ ] Sidebar refactor: ≤ 4 composed sections

---

## What to DEFER

**SuperHQ's auth gateway, JSONL event bus, checkpoint-resume boot:**
- These are "runtime hardening" problems
- Canopy doesn't run agents in VMs yet
- Revisit once the basic agent UX is shipped

**Gradient-bang's Pipecat voice pipeline:**
- Voice is a capability Canopy will want eventually
- Zero value until basic text UX is polished
- The `run_llm=False` + `request_id` correlation pattern is worth bookmarking for future voice tools

---

## Decisions Roberto Needs to Make

1. **OKLCh or HSL?** Cabinet uses OKLCh, your existing memory says HSL for MIOSA artifacts. Pick one for Canopy.
2. **Phase 1 scope:** full token overhaul (1 week) or minimal re-skin (2–3 days)?
3. **Who builds this?** You solo in Svelte, or bring in Pedro/Abdul/Nejd?
4. **Does `canopy/desktop/src 2/` matter?** There's a duplicate `src` folder — is that an abandoned experiment or real?
5. **Merge with existing 48 stores:** Phase 3 says "one store per module." You already have 48 stores — do we rationalize down, or leave as-is and enforce the rule going forward?

---

## Dossier Index (full details on disk)

- `/tmp/competitor-research/analysis/canopy-baseline.md` — what we have today
- `/tmp/competitor-research/analysis/cabinet.md` — design system gold
- `/tmp/competitor-research/analysis/multica.md` — actor-as-sibling pattern
- `/tmp/competitor-research/analysis/core-oss.md` — shell + module pattern
- `/tmp/competitor-research/analysis/superhq.md` — auth gateway (deferred)
- `/tmp/competitor-research/analysis/gradient-bang.md` — voice (deferred)

Cloned repos at `/tmp/competitor-research/{cabinet, multica, core-oss, superhq, gradient-bang}/` — agents can be re-dispatched for deeper dives on specific patterns as needed.
