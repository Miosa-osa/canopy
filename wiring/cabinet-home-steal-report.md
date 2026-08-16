# Cabinet Home Module Steal Report -- 2026-04-30

## What Their Home Page Does

Two distinct surfaces share "home" duty depending on navigation state:

1. **Root Home (`HomeScreen`)** -- shown when `section.type === "home"`. Vertically centered layout: greeting headline, full composer with agent/runtime pickers, quick-action pill chips, and a horizontally-scrolling registry carousel at the bottom.

2. **Cabinet View (`CabinetView`)** -- shown when a specific cabinet (workspace) is selected. Header bar with cabinet name + count pills (agents/jobs/heartbeats), a greeting composer hero (`CabinetTaskComposer`), a 2/3-column Activity feed, and a 1/3-column Next Up Runs sidebar. Org chart modal accessible from header.

Both surfaces funnel into the same action: composing a message and dispatching it to an agent via `createConversation()`.

---

## Key Components

| Component | What It Does | File Path (theirs) | How We'd Adapt |
|---|---|---|---|
| `HomeScreen` | Root landing -- greeting, composer, quick actions, registry carousel | `src/components/home/home-screen.tsx` | Single entry-point home module with greeting + prompt |
| `CabinetView` | Per-workspace dashboard -- header stats, composer hero, activity feed, schedule sidebar | `src/components/cabinets/cabinet-view.tsx` | Active workspace dashboard with stats + feed |
| `CabinetTaskComposer` | Greeting headline + composer card with agent picker, scoped to a cabinet | `src/components/cabinets/cabinet-task-composer.tsx` | Workspace-scoped composer with agent routing |
| `ComposerInput` | The actual textarea card -- mentions, attachments, drag-drop, keyboard hints | `src/components/composer/composer-input.tsx` | Reusable prompt input with @-mention support |
| `useComposer` | State machine for input, @-mention detection, submission lifecycle | `src/hooks/use-composer.ts` | Hook managing prompt state + mention resolution |
| `ActivityFeed` | Scrolling list of recent conversations with status icons, agent pills, token counts | `src/components/cabinets/activity-feed.tsx` | Recent activity panel for workspace dashboard |
| `NextUpRuns` | Upcoming scheduled agent jobs in a 7-day horizon | `src/components/cabinets/next-up-runs.tsx` | Scheduled tasks sidebar |
| `AppShell` | Root layout -- sidebar + main content router + terminal + panels | `src/components/layout/app-shell.tsx` | Top-level shell with section-based routing |
| `AgentPicker` / `AgentPickerCompact` | Dropdown to select which agent receives the task | `src/components/composer/agent-picker.tsx` | Agent selector dropdown |
| `RegistryCarousel` | Auto-scrolling horizontal strip of importable workspace templates | Inline in `home-screen.tsx` | Template browser for new workspace creation |

---

## Chat Interface Details

This is NOT a persistent chat. It is a **task launcher** -- a one-shot prompt that creates a new agent conversation.

**UX flow:**
1. User types a prompt into `ComposerInput` (a resizable `<textarea>` inside a rounded card)
2. User can `@`-mention agents, skills, or pages -- triggers a dropdown filtered by query
3. An `AgentPicker` (bottom-left of card) selects the target agent (defaults to "editor" or first active)
4. A `TaskRuntimePicker` sets optional runtime overrides (provider, model, effort)
5. A `WhenChip` (top-right overlay) lets user switch from "now" to "schedule" or "recurring"
6. Pressing Enter (or clicking Send) calls `createConversation()` which POSTs to `/api/agents/conversations`
7. On success, navigation jumps to `section.type = "task"` showing the live conversation

**Key API call:**
```
POST /api/agents/conversations
Body: { agentSlug, userMessage, mentionedPaths, mentionedSkills, attachmentPaths, ...runtimeOverrides }
Response: { conversation: { id } }
```

**Attachment support:** drag-drop files onto the composer, paste from clipboard, or use paperclip button. Files upload to a staging path, virtual paths passed to the conversation.

**Keyboard shortcuts:** Enter = submit, Shift+Enter = newline, Cmd+Enter = newline, Escape = close mention dropdown. `@` at word boundary triggers mention dropdown.

---

## Greeting Logic

Two identical functions exist (`getGreeting` in `home-screen.tsx` and `cabinet-utils.ts`):

```typescript
function getGreeting(): string {
  const hour = new Date().getHours();
  if (hour < 12) return "Good morning";
  if (hour < 17) return "Good afternoon";
  return "Good evening";
}
```

**User name source:** fetched from `GET /api/user/profile` on mount. Falls back to no name (just greeting + period). On `CabinetView`, fetched from `GET /api/agents/config` (checks `person.name`, `user.name`, `owner.name`, `company.name` in that order), falls back to "there".

**Display:**
- HomeScreen: `"Good evening, Roberto."` or `"Good evening."` -- centered, `text-3xl md:text-4xl font-semibold tracking-tight`
- CabinetTaskComposer: `"Good evening, Roberto. What are we working on today?"` -- left-aligned, serif font (`font-body-serif`, Source Serif 4), `text-[1.45rem] sm:text-[1.85rem]`

---

## Workspace Summary

**HomeScreen (root):** No workspace stats shown. Just greeting + composer + quick actions + registry carousel.

**CabinetView (per-workspace):** Header bar shows three `CountPill` components:
- **agents** -- total agent count in workspace
- **jobs** -- total scheduled job count
- **heartbeats** -- agents with active heartbeat schedules

Each pill is a tiny rounded badge: `bg-muted/40 px-2 py-0.5 text-[10px]` with bold count + muted label.

Additional stats visible inline in the Activity feed:
- Running conversation count (green pulsing dot + "N running")
- Per-conversation: relative timestamp, provider/model badge, token count (`Xk tok`)

---

## Layout

**HomeScreen layout:**
```
.flex-1.flex.flex-col.items-center.px-4.overflow-hidden
  |
  +-- .flex-1.flex.flex-col.items-center.justify-center.max-w-xl.space-y-8
  |     |-- h1 (greeting, centered)
  |     |-- ComposerInput (full-width card, rounded-2xl)
  |     +-- .flex-wrap.justify-center.gap-1.5.min-h-[8rem] (quick action pills)
  |
  +-- .w-screen.pb-8.pt-4 (registry carousel, edge-to-edge)
```

Vertically centered single-column. Max width 576px (`max-w-xl`). Composer auto-focuses. Quick action chips wrap naturally. Registry carousel bleeds full viewport width at the bottom.

**CabinetView layout:**
```
.flex.min-h-0.flex-1.flex-col.overflow-hidden
  |
  +-- header (border-b, flex-wrap, px-4/6)
  |     |-- cabinet name (h1, 14px semibold)
  |     |-- count pills (agents/jobs/heartbeats)
  |     +-- actions (depth dropdown, org chart, scheduler, version history)
  |
  +-- ScrollArea (flex-1)
        +-- .max-w-6xl.mx-auto.px-4.py-6
              |-- CabinetTaskComposer (greeting + composer, mb-8)
              +-- .grid.gap-8.lg:grid-cols-3
                    |-- ActivityFeed (lg:col-span-2)
                    +-- NextUpRuns + child cabinets (lg:col-span-1)
```

Responsive grid: single column on mobile, 3-column on `lg` breakpoint (activity gets 2 cols, schedule gets 1).

**Breakpoints used:** `sm:` (640px) for padding/font bumps, `md:` (768px) for greeting size, `lg:` (1024px) for grid split.

---

## Recommended Lift for Canopy Home

### Component 1: GreetingHeadline
- Time-of-day greeting (`Good morning/afternoon/evening`)
- Append user's display name from workspace config
- Append contextual prompt: `"What are we working on today?"`
- Use serif font at ~1.8rem for warmth, left-aligned on workspace view, centered on root home
- Single stateless component, receives `userName: string | null`

### Component 2: PromptComposer
- Rounded card (`rounded-2xl border bg-card`) containing a resizable `<textarea>`
- @-mention system: type `@` to trigger filtered dropdown of agents, pages, skills
- Bottom action bar: agent picker (left), runtime picker (left), send button (right)
- Top-right overlay slot: scheduling chip (now/scheduled/recurring)
- Support file attachments via drag-drop and paste
- Enter to submit, Shift/Cmd+Enter for newline
- On submit: create a new conversation/task and navigate to it
- Reuse across root home and per-workspace views

### Component 3: QuickActionChips
- Array of pre-defined prompts rendered as pill buttons (`rounded-full border px-3 py-1 text-xs`)
- Clicking a chip submits that prompt directly to the default agent
- Stagger fade-in animation (50ms per chip)
- Disabled state while a submission is in flight
- Configurable per workspace (different workspaces could have different quick actions)

### Component 4: WorkspaceStatsBar (for per-workspace view only)
- Row of count pills: agents, scheduled jobs, active heartbeats
- Each pill: rounded-full, muted background, bold number + label
- Running indicator: green pulsing dot when conversations are active
- Place in workspace header, not on root home

### Component 5: ActivityFeed (for per-workspace view only)
- Scrolling list of recent conversations
- Each row: status icon (running/done/failed), title, summary preview, relative time, agent pill, model badge, token count
- Auto-refreshes every 6 seconds via polling
- Running conversations sorted to top
- Filter by agent via clickable agent pills

### Component 6: ScheduleSidebar (for per-workspace view only)
- Upcoming 8 events in 7-day window
- Heartbeats (pink) vs scheduled jobs (green)
- Relative time labels ("in 5m", "in 2h", "in 3d")
- Clicking an event opens the job/heartbeat editor

### Layout Assembly
- **Root home:** vertically centered column, max-w-xl, greeting + composer + chips. No stats, no feed.
- **Workspace home:** full header bar with stats, greeting+composer hero section, then responsive 2/3 + 1/3 grid for activity + schedule.
- **Tech:** Tailwind CSS with CSS custom properties for theming (oklch color space). shadcn/ui primitives for buttons, dropdowns, dialogs, scroll areas. Zustand for global state (section routing, sidebar, terminal). No CSS modules, no styled-components.

### Data Flow Summary
```
/api/user/profile          -> user display name
/api/agents/config         -> workspace config (owner name, company)
/api/cabinets/overview     -> agent list, job list, heartbeat counts
/api/agents/conversations  -> POST to create task, GET to list activity
/api/registry              -> importable workspace templates
/api/agents/events         -> SSE stream for live updates (tree changes, conversation status)
```
