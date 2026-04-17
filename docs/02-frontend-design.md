# Canopy v2 — Frontend Design Spec

**Date:** 2026-04-17
**Status:** Draft, companion to `CANOPY-V2-FOUNDATION.md`
**Scope:** Design language, screen inventory, component inventory, flows, keyboard, states

---

## 0. Design Language — The Aesthetic Call

### The Feeling

> **A cockpit for AI operators.** Linear + Cursor + tmux had a baby. Serious, dense, operator-focused. Not cute. Not playful. Not corporate-blue.

### Design Principles (6)

1. **Monochrome base, single accent.** Black → gray → white. Accent: a single signal color (electric green for "running"). No rainbow buttons. No blue primary.
2. **Typography carries the personality.** Serif for editorial moments (home greeting, agent-persona prose). Geometric sans for UI. Monospace for code/terminal/IDs.
3. **Dark mode is default.** Operators work at night. Light mode is a toggle, not the canonical.
4. **Density over whitespace** — when it's working data. Whitespace over density — when it's a landing / empty state.
5. **Motion is functional, never decorative.** Glow pulse = agent running. Fade in = content loaded. No bouncing, no parallax, no scroll-triggered theater.
6. **Information lives where you look.** Runtime state top-left (always). Active session center. Agent avatars always consistent position. No hide-and-seek UI.

### Visual Tone Reference

- **Linear** — density, keyboard, monochrome discipline
- **Cursor** — terminal-adjacent, developer-first, dark default
- **Paperclip** — zero border radius, oklch tokens, shadcn rigor
- **Cabinet** — editorial typography, composer-centric home
- **Avoid:** Notion's roundness, Slack's color chaos, generic shadcn-looking-like-shadcn

---

## 1. Color System (OKLCh)

### Dark mode (canonical)

```css
/* Neutral scale — OKLCh */
--bg:              oklch(0.16 0.005 240);    /* near-black, slight cool */
--bg-elevated:     oklch(0.20 0.005 240);    /* cards, modals */
--bg-inset:        oklch(0.13 0.005 240);    /* inputs, terminal bg */
--sidebar:         oklch(0.14 0.005 240);
--border:          oklch(0.28 0.005 240);
--border-strong:   oklch(0.38 0.005 240);

--fg:              oklch(0.96 0.005 240);    /* primary text */
--fg-muted:        oklch(0.70 0.005 240);    /* secondary */
--fg-subtle:       oklch(0.52 0.005 240);    /* tertiary */

/* Signal colors — used sparingly */
--signal-running:  oklch(0.78 0.18 145);     /* electric green — agent active */
--signal-thinking: oklch(0.72 0.14 265);     /* cool purple — LLM thinking */
--signal-warn:     oklch(0.82 0.14 75);      /* amber */
--signal-error:    oklch(0.68 0.19 25);      /* muted red, not blaring */
--signal-info:     oklch(0.78 0.08 210);     /* steel blue (used rarely) */

/* Accent — used for primary action, focus, progress */
--accent:          oklch(0.78 0.18 145);     /* same as signal-running */
--accent-hover:    oklch(0.82 0.18 145);
--accent-fg:       oklch(0.14 0.005 240);    /* text on accent */
```

### Light mode (derived by L-flip, not re-authored)

```css
--bg:              oklch(0.99 0.002 240);
--bg-elevated:     oklch(0.97 0.002 240);
--bg-inset:        oklch(0.94 0.002 240);
--sidebar:         oklch(0.96 0.002 240);
--border:          oklch(0.88 0.002 240);
--border-strong:   oklch(0.78 0.002 240);
--fg:              oklch(0.16 0.005 240);
--fg-muted:        oklch(0.42 0.005 240);
--fg-subtle:       oklch(0.60 0.005 240);
/* signal + accent stay identical — perceptually balanced in both modes */
```

### Terminal palette (derived via `color-mix`, Cabinet pattern)

```css
--term-bg:       color-mix(in oklch, var(--bg-inset) 96%, black 4%);
--term-fg:       var(--fg);
--term-cursor:   var(--accent);

--term-black:    color-mix(in oklch, var(--bg)        92%, var(--fg) 8%);
--term-red:      color-mix(in oklch, var(--signal-error)    82%, var(--fg) 18%);
--term-green:    color-mix(in oklch, var(--signal-running)  82%, var(--fg) 18%);
--term-yellow:   color-mix(in oklch, var(--signal-warn)     82%, var(--fg) 18%);
--term-blue:     color-mix(in oklch, var(--signal-info)     82%, var(--fg) 18%);
--term-magenta:  color-mix(in oklch, var(--signal-thinking) 82%, var(--fg) 18%);
--term-cyan:     color-mix(in oklch, var(--accent)          68%, var(--fg) 32%);
--term-white:    var(--fg-muted);

/* bright variants: same, L + 0.08 */
```

Zero hardcoded hex. Theme switch → terminal matches instantly.

---

## 2. Typography

### Font stack

```css
--font-serif:  "EB Garamond", "Spectral", Georgia, serif;       /* editorial */
--font-sans:   "Geist", "Inter", ui-sans-serif, system-ui;      /* UI */
--font-mono:   "JetBrains Mono", "Geist Mono", ui-monospace;    /* code */
```

### Scale

| Token | Size | Line height | Tracking | Use |
|-------|------|-------------|----------|-----|
| `--text-3xl` | 36px | 1.1 | -0.03em | Editorial h1, home greeting (serif) |
| `--text-2xl` | 28px | 1.15 | -0.025em | Page h1 |
| `--text-xl` | 22px | 1.25 | -0.02em | Section h2 |
| `--text-lg` | 17px | 1.4 | -0.015em | Subtitle |
| `--text-base` | 15px | 1.55 | -0.011em | Body, editor |
| `--text-sm` | 13px | 1.5 | -0.005em | UI labels, meta |
| `--text-xs` | 11px | 1.4 | 0 | Badges, tags |

Body is **15px** not 16px. Editor feels editorial, not web-default.

### Weight scale

Sans: 400 (body), 500 (labels), 600 (headings), 700 (rare, numerals in dashboards).
Serif: 400 only. Never bold serif.
Mono: 400 and 500 only.

---

## 3. Spacing, Radius, Motion

### Spacing — 4px base

```css
--space-0: 0;
--space-1: 4px;
--space-2: 8px;
--space-3: 12px;
--space-4: 16px;
--space-5: 24px;
--space-6: 32px;
--space-8: 48px;
--space-10: 64px;
--space-12: 96px;
```

### Radius — calc-derived

```css
--radius: 8px;                                  /* canonical */
--radius-sm: calc(var(--radius) * 0.5);         /* 4px — badges, chips */
--radius-md: calc(var(--radius) * 0.75);        /* 6px — buttons, inputs */
--radius-lg: var(--radius);                     /* 8px — cards */
--radius-xl: calc(var(--radius) * 1.5);         /* 12px — modals */
--radius-2xl: calc(var(--radius) * 2);          /* 16px — composer card */
```

Not zero-radius (Paperclip). **Pill for primary CTAs (Foundation migration D1 — finalized 2026-04-17).** Rounded (8px) for inline utility controls, forms, segmented controls. Glass pill for overlay contexts.

### Motion

```css
--ease-out: cubic-bezier(0.16, 1, 0.3, 1);       /* exits, fades in */
--ease-in:  cubic-bezier(0.7, 0, 0.84, 0);       /* enters */
--ease-io:  cubic-bezier(0.65, 0, 0.35, 1);      /* transitions */

--dur-instant: 80ms;    /* hover, focus */
--dur-fast:    160ms;   /* toggles, reveals */
--dur-normal:  240ms;   /* route transitions */
--dur-slow:    400ms;   /* modal enters */
```

### Keyframes

```css
@keyframes agent-pulse {
  0%, 100% { box-shadow: 0 0 0 0 oklch(var(--signal-running) / 0.15); }
  50%      { box-shadow: 0 0 24px 4px oklch(var(--signal-running) / 0.35); }
}
.agent-running { animation: agent-pulse 2s var(--ease-io) infinite; }

@keyframes thinking-shimmer {
  0%, 100% { opacity: 0.5; }
  50%      { opacity: 1; }
}
.thinking { animation: thinking-shimmer 1.4s var(--ease-io) infinite; }

@keyframes fade-in-up {
  from { opacity: 0; transform: translateY(4px); }
  to   { opacity: 1; transform: translateY(0); }
}
.list-item { animation: fade-in-up var(--dur-fast) var(--ease-out) both; }
```

---

## 4. Component Inventory

### L1 — Primitives (MIOSA Foundation, themed to tokens)

**Source:** `src/lib/design/foundation/` — copied from Miosa-osa/foundation at commit a6f26df.
shadcn-svelte has been removed. Foundation provides Bits UI-backed equivalents.

**Button shape decision (D1, finalized 2026-04-17):**
- Primary CTAs: `.btn-pill .btn-pill-primary` (9999px radius)
- Inline utility controls, icon buttons, toolbars: `.btn-rounded .btn-rounded-*` (8px radius) or `.btn-compact .btn-compact-*` (6px, dense)
- Overlay / glass surfaces: `.btn-glass .btn-glass-pill` or `.btn-glass .btn-glass-rounded`

| Component | Source | Notes |
|-----------|--------|-------|
| Button | `foundation/button/Button.svelte` | Use CSS utility classes (`.btn-pill-*`, `.btn-rounded-*`) directly for shape control |
| Input | `foundation/input/Input.svelte` | Bits UI backed |
| Modal | `foundation/modal/Modal.svelte` | Replaces shadcn Dialog (9-file compound) |
| Tooltip | `foundation/tooltip/Tooltip.svelte` | Replaces shadcn Tooltip |
| Separator | `foundation/separator/Separator.svelte` | Direct replacement |
| Tabs | `foundation/tabs/` | TabsList, TabsTrigger, TabsContent |
| Menu / DropdownMenu | `foundation/menu/` | Menu, MenuItem, MenuGroup |
| Toast / Toaster | `foundation/toast/` | `toast()`, Toaster, Toast |
| Select | `foundation/select/Select.svelte` | Bits UI backed |
| Textarea | `foundation/textarea/Textarea.svelte` | Auto-grow capable |
| Popover | `foundation/popover/Popover.svelte` | For inline rich menus |
| PillButton | `foundation/osa/PillButton.svelte` | OSA-specific pill — for onboarding flows |
| GlassCard | `foundation/osa/GlassCard.svelte` | Glassmorphic card surface |
| Checkbox / Switch / Radio | standard |
| Progress | linear bar, circular for quota |
| Badge | `--text-xs`, pill shape (the one pill allowed) |
| Avatar | wrapped by `ActorAvatar` pattern |
| Separator | hairline, respects --border |
| ScrollArea | custom scrollbar, thin |
| Kbd | `<kbd>` styled for shortcut display |
| CommandPalette | headless via cmdk-style |

### L1 — Patterns (Canopy-specific compositions)

| Component | Purpose | Built from |
|-----------|---------|-----------|
| `Composer.svelte` | Input surface: agent picker + runtime picker + `@mention` + textarea | Cabinet pattern |
| `ActorAvatar.svelte` | Unified avatar for humans (initials) + agents (Bot icon) | Multica pattern |
| `LiveTerminal.svelte` | xterm.js + glow-pulse wrapper + TranscriptEntry side panel | Cabinet + Paperclip |
| `TranscriptView.svelte` | Renders `TranscriptEntry` union: assistant/thinking/tool_call/tool_result/diff/stdout/stderr/system | Paperclip pattern |
| `RuntimeCard.svelte` | Card for one runtime: icon, status dot, version, quota, launch btn | Paperclip-inspired |
| `RuntimeConfigForm.svelte` | Declarative form driven by adapter `getConfigSchema()` | Paperclip pattern |
| `PushPanel.svelte` | 340px right-side sibling panel (not overlay) | Core-OSS pattern |
| `DiffReview.svelte` | File tree of changed files, expand → diff, Keep/Discard | SuperHQ pattern (Phase 2) |
| `CommandPalette.svelte` | Global ⌘K overlay, fuzzy search all actions | standard |
| `AgentCard.svelte` | Agent in library grid + roster | custom |
| `SessionRow.svelte` | Row in sessions list: agent, runtime, duration, status, cost | custom |
| `QuotaGauge.svelte` | Circular progress for runtime quota windows | custom |
| `KbdChord.svelte` | Keyboard shortcut display: `⌘⇧K` | custom |
| `StatusDot.svelte` | Small colored dot for running/idle/error states | custom |
| `CopyButton.svelte` | Copy-to-clipboard with 1s confirmation | standard |
| `EmptyState.svelte` | Consistent empty-state card with icon + title + CTA | custom |
| `ErrorBoundary.svelte` | Wraps routes, shows error fallback | custom |

---

## 5. Navigation Architecture

### Global chrome (always present)

```
┌──────────────────────────────────────────────────────────────────┐
│  ◎ Canopy      [ search ]                          ⌘K   ⚙   👤  │  ← TitleBar (Tauri native on mac)
├────────────┬─────────────────────────────────────────────────────┤
│            │                                                     │
│  SIDEBAR   │   MAIN (route outlet)                               │
│  (220px)   │                                                     │
│            │                                                     │
│            │                                                     │
│            │                                                     │
│            │                                                     │
└────────────┴─────────────────────────────────────────────────────┘
```

### Sidebar structure (≤ 4 composed sections, each ≤ 150 lines)

```
SIDEBAR
├── SidebarWorkspace       ← workspace switcher (top, prominent)
│   [◉ sales-engine    ▾]
│
├── SidebarPrimary         ← the 5 core sections
│   ● Home
│   ● Runtimes          (badge: active session count)
│   ● Sessions          (badge: running count, glow if any running)
│   ● Agents
│   ● Workspaces
│
├── SidebarSecondary       ← lower, less-frequent
│   ○ Sandboxes
│   ○ Library
│   ○ Analytics
│
└── SidebarFooter          ← bottom
    [quota bar]           ← monthly spend vs budget
    [⚙ Settings]
```

Collapse to icon-only (48px) on narrow windows. State persisted in Tauri Store.

### Main content shell (Core-OSS inset trick)

```css
/* canonical shell — gives the "premium desktop app" feel */
.shell { background: var(--sidebar); display: flex; height: 100vh; }
.main-container { flex: 1; padding: 8px 8px 8px 0; display: flex; flex-direction: column; gap: 8px; }
main { background: var(--bg); border-radius: var(--radius-lg); overflow: hidden; flex: 1; }
```

Sidebar bg shows through the 8px gap around `main`. Instant polish.

---

## 6. Screen Inventory (every page, annotated)

### 6.1 Home `/`

**Purpose:** The composer. Type what you want, pick who does it, submit.

**Layout:**
```
┌────────────────────────────────────────────────────────┐
│                                                        │
│           [serif, 3xl]                                 │
│     Good evening, Roberto.                             │
│     What are we working on?                            │
│                                                        │
│  ┌──────────────────────────────────────────────────┐ │
│  │                                                  │ │
│  │  [Composer — rounded-2xl, no focus ring]         │ │
│  │   ↳ textarea (autogrow, 13px mono)               │ │
│  │                                                  │ │
│  │  [@agent] [⚙runtime haiku/low]      ⌘↵ Submit  │ │
│  └──────────────────────────────────────────────────┘ │
│                                                        │
│  Recent sessions                                       │
│  ───────────────                                       │
│  ● [SessionRow] Claude Code · sales-engine · 4m ago    │
│  ○ [SessionRow] Gemini · research · 2h ago             │
│  ○ [SessionRow] Codex · canopy · yesterday             │
│                                                        │
│  Pinned agents                                         │
│  ──────────────                                        │
│  [AgentCard] [AgentCard] [AgentCard] [AgentCard]      │
│                                                        │
└────────────────────────────────────────────────────────┘
```

**States:**
- **Empty** (first launch, no sessions, no pinned): serif greeting + composer only + "Tip: ⌘K to open the command palette"
- **Loaded:** as above
- **Error loading recents:** sessions section shows inline retry

**Interactions:**
- `⌘↵` submit
- Focus textarea on route load
- `@` opens agent picker inline
- `/` at start opens page/workspace ref picker
- `esc` on picker dismisses

### 6.2 Runtime Dashboard `/runtimes`

**Purpose:** See every AI runtime available on this machine. Launch, configure, monitor.

**Layout:**
```
┌────────────────────────────────────────────────────────────────┐
│  Runtimes                                    + Add Runtime     │
│  Manage AI execution engines on this machine.                  │
│                                                                │
│  CLI Runtimes                                                  │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐  │
│  │RuntimeCard │ │RuntimeCard │ │RuntimeCard │ │RuntimeCard │  │
│  │●  Claude   │ │●  Codex    │ │○  Gemini   │ │●  Cursor   │  │
│  │   v1.0.24  │ │   v0.12.1  │ │  install → │ │   v0.45    │  │
│  │ [quota bar]│ │ [quota bar]│ │            │ │            │  │
│  │ $12.40/mo  │ │ $3.10/mo   │ │            │ │ $0.00/mo   │  │
│  │ [Launch] ⋯ │ │ [Launch] ⋯ │ │ [Install]  │ │ [Launch] ⋯ │  │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘  │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐  │
│  │ OpenCode   │ │ Aider      │ │ Windsurf   │ │ Pi         │  │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘  │
│                                                                │
│  API Runtimes                                                  │
│  [ Anthropic ] [ OpenAI ] [ Google ] [ DeepSeek ] [ + Add ]    │
│                                                                │
│  MCP Servers                                                   │
│  [ filesystem ] [ github ] [ linear ]         [ + Add MCP ]    │
└────────────────────────────────────────────────────────────────┘
```

**`RuntimeCard.svelte`:** icon, status dot (● installed / ○ missing / ⚠ misconfigured), version, `QuotaGauge`, monthly spend, Launch primary + `⋯` overflow (Settings, Test Environment, Disable, View Logs).

**States per card:**
- Installed + configured → Launch enabled
- Installed + no credentials → "Configure" primary button
- Not installed → "Install" button (opens install guide)
- `testEnvironment()` returned warnings → amber ⚠ badge with tooltip

### 6.3 Runtime Detail `/runtimes/:slug`

**Purpose:** Deep config for one runtime. Credentials, default model, budget, skills mapping.

**Layout:** Tabs: **Overview · Configuration · Models · Skills · Sessions · Logs**
- Overview: current version, detected path, last-used, monthly spend chart, recent sessions
- Configuration: form rendered from `getConfigSchema()`
- Models: list from `listModels()`, set default
- Skills: which `AGENTS.md`/`CLAUDE.md`/etc. gets injected
- Sessions: filtered session history for this runtime
- Logs: raw adapter log stream

### 6.4 Sessions List `/sessions`

**Purpose:** Every session ever. Filter, search, resume.

**Layout:**
```
Sessions                                            [ Filter ▾ ]
                                                    [ Search  ]

│ Status  │ Agent           │ Runtime     │ Duration │ Cost   │
│─────────│─────────────────│─────────────│──────────│────────│
│ ● Running│ Sales Strategist│ Claude Code │ 4m 12s   │ $0.08  │
│ ○ Done  │ Architect       │ Codex       │ 12m 04s  │ $0.24  │
│ ⚠ Error │ Research        │ Gemini      │ 1m 32s   │ $0.01  │
│ ○ Done  │ Copywriter      │ Claude Code │ 8m 51s   │ $0.15  │
│  ...    │                 │             │          │        │
```

Click row → `/sessions/:id`. Keyboard: `j/k` to move, `↵` to open, `r` to resume.

### 6.5 Session Detail `/sessions/:id` — THE LIVE VIEW

**Purpose:** Watch agent work live. Inspect transcript. Resume. Stop.

**Layout:**
```
┌───────────────────────────────────────────────────────────────────┐
│ ← Back      [ActorAvatar] Sales Strategist · Claude Code           │
│             Session #2893 · Running 4m · $0.08                     │
│                                              [⏸ Pause] [■ Stop]    │
├─────────────────────────────────────────┬─────────────────────────┤
│                                         │                         │
│  TRANSCRIPT                             │  CONTEXT                │
│  ┌──────────────────────────────────┐  │  Prompt                 │
│  │ 💬 assistant                     │  │  [editable]             │
│  │ Starting analysis of Q2 pipeline │  │                         │
│  │                                  │  │  Skills injected        │
│  │ 🧠 thinking                      │  │  - AGENTS.md            │
│  │ I should check the CRM data...   │  │  - SOUL.md              │
│  │                                  │  │  - TOOLS.md             │
│  │ 🔧 tool_call: read_crm           │  │                         │
│  │    { filter: "Q2", status: ... } │  │  Sandbox                │
│  │                                  │  │  ◉ MIOSA vm-4k2p        │
│  │ ⬅ tool_result                    │  │  [Open Terminal →]      │
│  │    142 deals, $1.2M pipeline     │  │                         │
│  │                                  │  │  Workspace              │
│  │ 📝 diff: pipeline-analysis.md    │  │  sales-engine           │
│  │    +24 / -0                      │  │                         │
│  │    [Review Changes →]            │  │  Governance             │
│  │                                  │  │  ✓ auto-approved        │
│  │ ●●●●  (glow while running)       │  │                         │
│  └──────────────────────────────────┘  │                         │
│                                         │                         │
│  [LiveTerminal — PTY stream, collapsible under transcript]       │
└─────────────────────────────────────────┴─────────────────────────┘
```

**Running state:** transcript card has `agent-pulse` glow.
**Tool call:** click to expand args/result JSON.
**Diff entry:** click → `DiffReview.svelte` opens in PushPanel.

### 6.6 Agents Library `/agents`

**Purpose:** Browse the 330+ agent library. Hire, edit, create.

**Layout:**
```
Agents                              [ Filter: All ▾ ]  [ + New Agent ]
                                    Categories: Sales · Dev · Research · Content · Ops ...

┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│ AgentCard        │ │ AgentCard        │ │ AgentCard        │
│ [emoji]          │ │                  │ │                  │
│ Sales Strategist │ │ Architect        │ │ Copy Doctor      │
│ Sales · Roberto  │ │ Dev · Nejd       │ │ Content · Bennett│
│ "I analyze deal..│ │ "I design..."    │ │ "I rewrite..."   │
│                  │ │                  │ │                  │
│ ● Hired · 3 runs │ │ ○ Not hired      │ │ ● Hired · 12 runs│
│ [Hire] / [Run]   │ │ [Hire]           │ │ [Run]            │
└──────────────────┘ └──────────────────┘ └──────────────────┘
```

`AgentCard` — persona emoji, name, category + owner, one-line role, status, primary action.

### 6.7 Agent Detail/Editor `/agents/:slug`

**Purpose:** Edit persona markdown. Set default runtime. Configure heartbeat. View runs.

**Layout:** Left: markdown editor (Tiptap) for persona. Right: sidebar with metadata (runtime, heartbeat cron, budget, tools, skills). Tabs: **Persona · Heartbeat · Skills · Runs · Settings**.

### 6.8 Workspaces List `/workspaces`

**Purpose:** All workspaces (markdown folders). Switch, create, import.

Grid of cards per workspace: name, description, agent count, last activity.

### 6.9 Workspace Detail `/workspaces/:slug`

**Purpose:** The workspace itself — file tree + editor + agent activity.

**Layout:**
```
┌─────────────┬───────────────────────────────────┬─────────────┐
│ FILE TREE   │  EDITOR (Tiptap, current file)    │ ACTIVITY    │
│             │                                   │             │
│ ▸ agents/   │  # Pipeline Analysis - Q2         │ 🟢 Sales    │
│ ▸ skills/   │                                   │    Running  │
│ ▾ notes/    │  The Q2 pipeline shows...         │    4m ago   │
│   Q1.md     │                                   │             │
│   Q2.md ●   │                                   │ ✓ Research  │
│ ▸ reports/  │                                   │   Done      │
│ SYSTEM.md   │                                   │   1h ago    │
│ company.yaml│                                   │             │
└─────────────┴───────────────────────────────────┴─────────────┘
```

Sidebar panels collapsible via ⌘B (file tree) and ⌘J (activity).

### 6.10 Sandbox Detail `/sandboxes/:id`

**Purpose:** MIOSA-provisioned VM. Full terminal access. File browser. Port forwards.

**Layout:** LiveTerminal as primary, right drawer with: VM specs, ports exposed, files touched by agent, lifespan/TTL.

### 6.11 Settings `/settings/*`

**Subpages:**
- `/settings` — profile, appearance (theme toggle), keyboard shortcuts viewer
- `/settings/runtimes` — credential vault per runtime
- `/settings/budgets` — monthly cap, per-agent caps, alert thresholds
- `/settings/governance` — approval gate rules
- `/settings/miosa` — MIOSA API endpoint + key
- `/settings/workspace-protocol` — default templates, markdown conventions

### 6.12 Onboarding Flow (first-run wizard)

5 steps, full-screen modal:

1. **Welcome** — one-sentence thesis, "Next" button
2. **Scan runtimes** — auto-detects installed CLIs, shows result card ("Found: Claude Code, Cursor. Missing: Codex, Gemini.")
3. **Connect credentials** — inline `RuntimeConfigForm` for each detected runtime, Keychain-stored
4. **Pick a workspace** — choose starter template (sales-engine / dev-shop / content-factory / blank)
5. **Hire first agent** — pick from 10 curated agents, click Hire, done

Skip-able at any step. "You can do this later in Settings."

---

## 7. Command Palette (⌘K)

### Commands catalog (grouped)

```
Go to…
  ⌘1  Home
  ⌘2  Runtimes
  ⌘3  Sessions
  ⌘4  Agents
  ⌘5  Workspaces

Create…
  ⌘N  New Session
  ⌘⇧N New Agent
  ⌘⇧W New Workspace

Runtimes…
  Launch Claude Code
  Launch Codex
  Launch Gemini
  ... (one per installed runtime)
  Test all runtime environments

Sessions…
  Resume last session
  Stop all running sessions
  Show running sessions only

Theme…
  Toggle dark/light
  Set accent color

System…
  Open Settings
  Restart Daemon
  Show Version / About
  Report Bug
```

Fuzzy search, recent-first, keyboard-only.

---

## 8. Keyboard Shortcuts

### Global
| Key | Action |
|-----|--------|
| `⌘K` | Command palette |
| `⌘/` | Shortcuts cheatsheet overlay |
| `⌘,` | Settings |
| `⌘⇧D` | Toggle theme |
| `⌘⇧L` | Toggle sidebar |
| `esc` | Close modal / blur input |

### Navigation
| Key | Action |
|-----|--------|
| `⌘1–5` | Jump to main sections |
| `j / k` | Down / up in lists |
| `↵` | Open focused row |
| `⌘↵` | Submit composer |

### Session view
| Key | Action |
|-----|--------|
| `⌘⇧S` | Stop running session |
| `⌘⇧R` | Resume / restart |
| `⌘T` | Toggle terminal |
| `⌘D` | Open diff review |

### Workspace
| Key | Action |
|-----|--------|
| `⌘B` | Toggle file tree |
| `⌘J` | Toggle activity panel |
| `⌘P` | Quick file switcher |

All editable in Settings.

---

## 9. States (empty / loading / error — the polish layer)

### Empty states

Never show a blank area. Always show an `EmptyState.svelte`:
- Icon (Lucide, 48px, `--fg-subtle`)
- Headline (h2, sans, `--text-xl`)
- Body (1–2 sentences, `--fg-muted`)
- Primary CTA button

```
┌─────────────────────────────┐
│         [icon 48px]         │
│                             │
│      No sessions yet        │
│                             │
│   Pick an agent, type a     │
│   prompt, and get started.  │
│                             │
│        [ Start one ]        │
└─────────────────────────────┘
```

### Loading states

- Lists: 3–5 skeleton rows, `animate-pulse` at 40% opacity
- Cards: skeleton with real proportions
- **Never a spinner on an empty page.** Skeleton reflects the shape.
- Inline indicators (after 300ms threshold): thin progress bar at top of content area

### Error states

Inline in the surface that errored, with:
- What happened (plain English, not stack trace)
- What to do (retry / check connection / contact support)
- Technical detail in collapsible `<details>` for logs

Global errors → toast, then auto-dismiss.

---

## 10. Motion Catalog

| Trigger | Animation | Duration |
|---------|-----------|----------|
| Route change | fade-in-up on main content | `--dur-normal` |
| Modal open | backdrop fade + modal scale-up | `--dur-slow` |
| Drawer open | slide-in + backdrop fade | `--dur-normal` |
| Toast enter | slide-up from bottom-right | `--dur-fast` |
| Button hover | bg transition + `transform: translateY(-0.5px)` | `--dur-instant` |
| Agent running | `agent-pulse` 2s infinite | — |
| Agent thinking | `thinking-shimmer` on text | — |
| List item enter | `fade-in-up` staggered 30ms | `--dur-fast` |
| Theme switch | 200ms `background-color` transition | — |

No parallax. No scroll-triggered animations. No particles. No gradients that move.

---

## 11. Accessibility

- Focus-visible ring: `outline: 2px solid var(--accent); outline-offset: 2px` on keyboard focus only
- ARIA labels on every icon button
- Min touch target 36px (even on desktop — cursor accuracy varies)
- Color contrast: body text ≥ 7:1 (WCAG AAA), meta ≥ 4.5:1 (AA)
- Motion respects `prefers-reduced-motion: reduce` (kills all animations)
- Full keyboard navigation, no mouse-only paths

---

## 12. Responsive (desktop windows)

Canopy is desktop-first. But Tauri windows resize. Breakpoints (by window width):

| Width | Behavior |
|-------|----------|
| ≥ 1280px | Full layout (sidebar + main + optional push panel) |
| 960–1280px | Push panel collapses to drawer |
| 720–960px | Sidebar collapses to icons |
| < 720px | Sidebar hidden behind `⌘⇧L`, single-column |

Minimum Tauri window: 640×480. Below that, warn user.

---

## 13. Frontend Folder Tree (for reference)

See `CANOPY-V2-FOUNDATION.md` section 5 for full monorepo tree.
Frontend-specific:

```
canopy/desktop/src/
├── app.html
├── app.css                # imports tokens + resets only
├── routes/                # L3 — one folder per screen
│   ├── +layout.svelte     # shell (sidebar + inset main)
│   ├── +page.svelte       # home
│   ├── runtimes/
│   ├── sessions/
│   ├── agents/
│   ├── workspaces/
│   ├── sandboxes/
│   └── settings/
├── lib/
│   ├── design/            # L1 — everything in §4
│   │   ├── tokens/
│   │   ├── primitives/
│   │   └── patterns/
│   ├── domain/            # L2 — business types + logic
│   ├── api/               # L1 — client + realtime + queries
│   ├── stores/            # L0 — ≤ 4 global runes-based stores
│   └── tauri/             # command bindings
└── tests/
```

---

## 14. Build Order (Frontend-Specific, within Weeks 4–6)

### Week 4: Shell + Tokens + Runtime Dashboard

1. Set up tokens.css (all 3 subfiles), verify in Storybook/Playground
2. Install + theme shadcn-svelte primitives
3. Build shell (`+layout.svelte`) with inset trick
4. Build Sidebar sections (4 composed pieces)
5. Runtime Dashboard page + `RuntimeCard` + `QuotaGauge` + `RuntimeConfigForm`
6. Wire to backend API

**Exit:** open app, see real runtime cards, click settings, save credential to Keychain, click verify.

### Week 5: Composer + Sessions + Transcripts

1. `Composer.svelte` with agent/runtime picker + `@mention`
2. Home page with composer + recent sessions
3. Sessions list page
4. Session detail page with `LiveTerminal` + `TranscriptView`
5. sessionStorage reconnect
6. Workspaces list + detail

**Exit:** submit prompt → see live transcript → agent completes → session lands in history → refresh mid-session → reconnects.

### Week 6: Agents + Settings + Polish + Ship

1. Agents library page + `AgentCard`
2. Agent detail page (persona editor)
3. Settings pages (all 6 subpages)
4. Onboarding flow (first-run wizard)
5. Command palette
6. All empty/loading/error states
7. Keyboard shortcuts + cheatsheet overlay
8. Sandboxes view with embedded MIOSA terminal
9. Icon + branding assets
10. DMG build + auto-update

**Exit:** v0.1 DMG ships. Internal users test.

---

## 15. What We Do NOT Build in v0.1

- Virtual pixel-art office (defer)
- Multi-user (defer, Paperclip took this on and regretted the complexity)
- Voice interface (defer — Gradient-bang lessons bookmark)
- Mobile / web version (never — this is desktop-first)
- SuperHQ's VM sandbox (MIOSA handles this externally)
- Plugin marketplace UI (v0.2)
- Skills marketplace (v0.2)
- Billing / subscription UI (v0.2 — open source, self-host is free)
- i18n (v0.2+)
- Advanced analytics dashboards (v0.2)

---

## 16. What Roberto Needs to Look At

Not 15 questions. Just 3.

1. **Does the aesthetic direction feel right?** Cockpit-like, monochrome + green accent, dark-default, editorial serif for moments, dense but structured. Yes / redline / different direction entirely?
2. **Is the screen inventory complete?** Home, Runtimes, Runtime Detail, Sessions, Session Detail (live), Agents, Agent Detail, Workspaces, Workspace Detail, Sandboxes, Settings (6 subpages), Onboarding. Am I missing a surface?
3. **Composer-on-home vs separate "new session" page?** Cabinet does composer-on-home (what I specced). Some operators prefer Home as a dashboard and composer as a dedicated route. Your call.

Approve and I can start Week 4 scaffolding the moment the backend is ready.
