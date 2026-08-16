# OSS Deep Steal Report -- 2026-05-01

> 3 repos audited. 187 distinct features cataloged. 53 features we're MISSING. Top 15 build candidates below.

---

## Core-OSS (10xapp/core-oss)

### What It Is
Open-source all-in-one productivity platform: email, calendar, chat (AI), messages, files, projects, dashboard, agents, AI app builder, website builder -- in a single app. Closest thing to a "Google Workspace + AI" monolith.

### Tech Stack
- **Backend:** Python 3.12, FastAPI, Pydantic, Supabase (PostgreSQL + RLS + Realtime), Cloudflare R2 (S3)
- **Frontend:** React 19, Vite 7, TypeScript, Tailwind 4, Zustand (persisted), TanStack Query
- **AI:** OpenAI/Anthropic/Groq via provider factory, tool-use chat with 12 tool definitions
- **Rich Text:** TipTap (ProseMirror) with slash commands, tables, task lists, mentions
- **Monorepo:** `core-api/` (FastAPI), `core-web/` (React SPA), `core-image-proxy/` (CF Worker)

### Routes / Pages

| Route | What It Does | Canopy Equivalent | Gap? |
|-------|-------------|-------------------|------|
| `/chat`, `/chat/:id` | AI chat with tools, streaming, image attachments | Build (composer) | NO |
| `/email` | Full email client: Gmail/Outlook sync, compose, threads, search | -- | YES: no email |
| `/calendar` | Calendar sync: Google Cal + Microsoft 365 | -- | YES: no calendar |
| `/workspace/:id/dashboard` | Bento grid: emails, chat, projects, calendar, agents cards | -- | YES: no dashboard |
| `/workspace/:id/messages/:ch` | Team messaging: channels, threads, reactions, mentions | Chat + Channels | PARTIAL |
| `/workspace/:id/files/:doc` | File manager + rich doc editor + version history | Files + Docs | PARTIAL |
| `/workspace/:id/projects/:b` | Kanban boards + list view with drag-drop | Tasks | PARTIAL |
| `/workspace/:id/agents/:id` | Agent library, chat, config, sandbox, templates | Agents | PARTIAL |
| `/workspace/:id/team` | Team member management | Team | NO |
| `/workspace/:id/members` | Member invites, roles | Team | NO |
| `/builder/:id` | AI app builder: prompt -> full app in sandbox with live preview | -- | YES: no app builder |
| `/sites/:id` | Website/linktree builder (placeholder) | -- | YES: no site builder |
| `/onboarding` | Multi-step workspace setup wizard | -- | YES: no onboarding |
| `/invite/:token` | Invite acceptance flow | -- | YES: no invites |
| `/s/:shareId` | Public share link resolver | -- | YES: no public sharing |
| `/oauth/callback` | OAuth popup handler for Google/Microsoft | -- | YES: no OAuth |

### Components Worth Stealing

| Component | What It Does | How We'd Adapt | Priority |
|-----------|-------------|---------------|----------|
| `ChatView` + `useChatStream` | AI chat with tool use, streaming, image attach, conversation history, suggested prompts | Our composer handles this, but their suggested prompts + regenerate UX is cleaner | LOW |
| `EmailView` | Full email client with thread grouping, keyboard nav (vim j/k), category filtering, search | New module: integrated email per workspace | MED |
| `CalendarView` | Calendar sync with multi-provider support (Google/Microsoft) | New module: workspace calendar | MED |
| `DashboardView` | Bento grid with 5 widget cards (email, chat, projects, calendar, agents) | Home module dashboard widgets | HIGH |
| `AIBuilderView` + `BuilderWorkspace` | Prompt -> app: chat left panel, live preview right, version history, download as ZIP | New pane type or module: AI app scaffolder | MED |
| `BlockEditor` + `SlashCommandMenu` | TipTap rich text editor with slash commands, tables, task lists | Enhance our Docs editor | MED |
| `FilesView` + 7 viewers | File manager with PDF, DOCX, PPTX, XLSX, audio, video viewers + version history | Extend our Files with rich viewers | HIGH |
| `ShareModal` | Permission-based sharing with link slugs, user search, pending requests | New feature: doc/workspace sharing | MED |
| `SearchHeader` | Global search across all content types | Enhance Cmd+K with cross-module search | HIGH |
| `NotificationPanel` | Bell icon + notification list with item types | Enhance our Inbox | LOW |
| `AgentStorageBrowser` | Browse agent sandbox filesystem | Enhance our Sandboxes | LOW |
| `SidebarChat` | Persistent mini-chat in sidebar (separate from main chat) | Side panel AI assistant | MED |

### Data Models

| Entity | Key Fields |
|--------|-----------|
| Workspace | id, name, emoji, icon, apps[], role, isDefault, isShared |
| MiniApp | id, workspaceId, type (chat/email/calendar/...), name, position, isPublic |
| Conversation | id, messages[], workspaceIds[] |
| Email | threads, folders (inbox/starred/sent/drafts/trash), categories, accounts |
| Project/Board | id, name, description, issues/tasks |
| Agent | id, name, status, sandbox_status, template, config |
| Document | with sharing, versions, mentions |
| File | with presigned URLs, R2 storage |
| Builder Project | id, name, fileTree, versions, generationStatus |

### API Endpoints

| Endpoint Area | Key Routes |
|---------------|-----------|
| Auth | OAuth2 (Google/Microsoft), Supabase JWT |
| Chat | CRUD conversations, streaming responses, tool calls |
| Email | Sync, compose, send, folders, search, attachments |
| Calendar | Sync events, CRUD, multi-provider |
| Messages | Channels, threads, reactions, mentions |
| Files | Upload (R2 presigned), preview, share, version |
| Projects | Boards, issues, labels, assignment |
| Agents | CRUD, dispatch, conversations, sandbox, templates |
| Documents | CRUD, share, public access, mentions |
| Builder | Projects, generate, versions, fileTree |
| Users | Profile, preferences, invitations, permissions |
| Webhooks | Event subscriptions |
| Notifications | CRUD, mark read |
| Search | Smart search across entities |

### UX Patterns

1. **Bento dashboard grid** -- 2fr/3fr row ratio, 6-col grid, 5 widget cards
2. **Keyboard navigation** -- Arrow + vim keys across all views, zone-based focus
3. **Workspace-scoped everything** -- Every route nests under `/workspace/:id/`
4. **Session app memory** -- Remembers last-used app per workspace
5. **Drag-drop reordering** -- Sidebar apps, project boards, files
6. **Multi-account email** -- Per-account folder trees, cross-account search
7. **Search with fallback** -- Server search primary, client-side filter during loading
8. **Sandboxed HTML render** -- Email content in iframe sandbox
9. **Agent realtime** -- SSE for agent status, sandbox status, last_active
10. **Share links** -- Public URLs with permission management

---

## Cabinet (hilash/cabinet) -- Full Module Set

### What It Is
Local-first AI workspace: manages AI agents (Claude Code, Codex, Cursor, Gemini, Grok, Copilot, OpenCode, Pi), knowledge base, scheduled jobs, heartbeats, skills, and tasks -- all orchestrated through a Next.js web UI backed by SQLite.

### Routes / Pages (beyond home)

| Route | What It Does | Canopy Equivalent | Gap? |
|-------|-------------|-------------------|------|
| `/` (home) | HomeScreen: greeting, composer, quick actions | -- | YES: no home screen |
| `#agents` | AgentsWorkspace: agent org chart, composer, conversations, settings, heartbeats, routines | Agents + Agent Control | PARTIAL |
| `#tasks` | TasksBoard: kanban (inbox/needs/running/done/archive), list, schedule views with DnD | Tasks | PARTIAL: theirs is agent-task focused |
| `#tasks/:id` | TaskConversationPage: chat, artifacts, diff, logs, transcript, approval panel | Build (conversation view) | PARTIAL |
| `#mission-control` | MissionControl: agent grid by department, pulse metrics, goals, Slack panel, NL agent creation | -- | YES: no mission control |
| `#settings` | 9-tab settings: profile, providers, skills, storage, integrations, notifications, appearance, updates, about | Settings | PARTIAL: theirs is deeper |
| `#search` | SearchPalette: global fuzzy search | Cmd+K | NO |
| `/login` | Auth flow | -- | N/A |
| `/agent-preview` | Agent preview page | -- | LOW |

### Components Worth Stealing

| Component | What It Does | How We'd Adapt | Priority |
|-----------|-------------|---------------|----------|
| `mission-control.tsx` | Agent grid by department, pulse metrics, NL agent creation, scheduler toggle, goal bars, Slack panel | New Home or Mission Control module | HIGH |
| `agents-workspace.tsx` | Org chart with hierarchy, department grouping, activity beacons, heartbeat/routine management | Enhance our Agents module with org chart | HIGH |
| `tasks-board.tsx` | Kanban with 5 lanes + list + schedule views, filter by agent/trigger, DnD with undo, density toggle | Enhance our Tasks with board views | HIGH |
| `task-conversation-page.tsx` | 5-tab view (chat/artifacts/diff/logs/transcript), approval panel, token usage, compaction, wrap-up signal | Enhance Build conversation view | HIGH |
| `skill-library.tsx` | Skill catalog with origins (cabinet/repo/system), upstream stats, import/discover, trust levels | Enhance our Skills module | MED |
| `editor.tsx` | TipTap with wiki-links, folder indexing, embed detection, mermaid, CSV/PDF/PPTX viewers, AI edit button | Enhance our Docs editor | MED |
| `onboarding-wizard.tsx` | 9-step wizard: name, room type, agent selection, provider setup, community | New onboarding flow | HIGH |
| `settings-page.tsx` | 9 tabs with provider verification, accent color, avatar catalog, MCP config, telemetry toggle | Enhance our Settings (18 sub-pages exist but less polished) | MED |
| `search-palette.tsx` | Global fuzzy search across pages/agents/tasks | Already have Cmd+K, could enhance | LOW |
| `terminal-tabs.tsx` + `web-terminal.tsx` | Multi-tab terminal with exited state view | Enhance our terminal pane | MED |
| `version-history.tsx` | Document version timeline with restore | Add to our Docs | MED |
| `schedule-calendar.tsx` + `schedule-list.tsx` | Calendar + list views for scheduled jobs/heartbeats | Enhance our Schedule module | MED |
| `compact-org-chart.tsx` | Visual agent hierarchy with department cards | New component for Agents | MED |
| `conversation-approval-panel.tsx` | Approval flow with pending actions | Enhance our Agent Control / Governance | HIGH |
| `provider-glyph.tsx` + provider registry | 8 provider adapters (Claude/Codex/Cursor/Gemini/Grok/Copilot/OpenCode/Pi) with verify flows | Our Runtimes already does this | LOW |

### Features We Missed Last Time

1. **Agent org chart** -- Hierarchical department-based agent visualization with CEO lead
2. **Natural language agent creation** -- Type description, AI generates agent config JSON
3. **Heartbeat system** -- Agents self-trigger on cron schedule, configurable per-agent
4. **Routine/job library** -- Template library for scheduled agent tasks
5. **Skill origins + trust levels** -- Skills tagged by source with executable trust warnings
6. **Skill upstream stats** -- Star counts and install numbers from skills.sh registry
7. **Task kanban with 5 lanes** -- inbox/needs/running/done/archive (not standard 3-lane)
8. **Task density toggle** -- Compact vs comfortable card spacing
9. **Conversation compaction** -- When token usage > 80%, digest earlier turns into summaries
10. **Wrap-up signal** -- Emerald card prompts task completion when agent reaches natural stop
11. **Approval panel** -- Pending agent actions awaiting user confirmation inline
12. **Wiki-links in editor** -- `#page:slug` navigable internal links with fuzzy matching
13. **Folder indexing** -- Directories auto-display child pages when no index.md exists
14. **Room types for onboarding** -- office/study/lab/family-room/blank with tailored agent suggestions
15. **Provider verification flows** -- Step-by-step CLI setup guides with live status checking
16. **MCP server configuration** -- Add/remove/configure MCP servers per workspace in settings
17. **Accent color personalization** -- 12+ presets or custom hex
18. **Avatar catalog** -- 110+ preset avatars across categories with search
19. **Storage backend config** -- Configurable data directory with env var override
20. **Update system** -- Check/apply updates with backup before deploy

### Data Models

| Entity | Key Fields |
|--------|-----------|
| Agent | slug, name, emoji, role, department, type, provider, adapter, heartbeat cron, workspace, instructions, goals |
| Conversation/Task | id, agentSlug, title, status, triggerType (manual/job/heartbeat/agent), turns, artifacts, token usage |
| Job | id, agentSlug, name, cron, enabled, template |
| Skill | key, name, description, origin (cabinet/repo/system/legacy), trust level, upstream stats |
| Cabinet | path, name, depth, agents, jobs, heartbeats |
| Page | path, content (markdown), frontmatter, versions |
| Tree | hierarchical node structure with cabinets/pages/files |

### API Endpoints (Cabinet)

| Area | Key Routes |
|------|-----------|
| `/api/agents` | CRUD, personas, conversations, events (SSE), config |
| `/api/cabinets` | Overview, tree, discovery |
| `/api/jobs` | CRUD, library, run |
| `/api/schedule` | Cron management |
| `/api/kb` | Knowledge base operations |
| `/api/pages` | CRUD, versions |
| `/api/search` | Global search |
| `/api/terminal` | PTY management |
| `/api/git` | Git operations |
| `/api/github` | GitHub integration |
| `/api/upload` | File upload per page |
| `/api/ai` | AI panel operations |
| `/api/system` | Updates, backup, health |
| `/api/registry` | Template registry |
| `/api/telemetry` | Usage tracking |
| `/api/auth` | Authentication |
| `/api/daemon` | Background daemon health |

---

## Tmux-IDE (wavyrai/tmux-ide)

### What It Is
Terminal-native IDE and multi-agent orchestrator: declarative tmux layout configs (`ide.yml`), agent team management, task/mission/milestone system, file explorer widget, git changes widget, costs widget, mission control widget, tunnels, remote machine registry, and a Next.js dashboard. Think "tmux on steroids with AI agent orchestration."

### Tech Stack
- **CLI:** TypeScript, Bun, Zod schemas, js-yaml
- **TUI Widgets:** Solid.js + OpenTUI (terminal UI framework), node-pty
- **Dashboard:** Next.js, React, TanStack Query, @dnd-kit
- **IPC:** WebSocket v3 protocol, Unix socket, mDNS discovery
- **Orchestration:** Background polling loop with dependency resolution, retry, stall detection

### Routes / Pages (Dashboard)

| Route | What It Does | Canopy Equivalent | Gap? |
|-------|-------------|-------------------|------|
| `/` | Dashboard home: kanban board, agent cards, activity feed, goals, mission header | -- | YES |
| `/project/:id` | Project detail view | Projects | PARTIAL |

### Components Worth Stealing

| Component | What It Does | How We'd Adapt | Priority |
|-----------|-------------|---------------|----------|
| Orchestrator | Multi-agent task dispatch: dependency resolution, priority, specialty matching, stall detection, retry with backoff, milestone gating, validation contracts | Backend: agent orchestration engine | HIGH |
| Mission/Milestone system | Hierarchical work: mission -> milestones -> tasks with gating + validation assertions | Enhance Tasks/Projects with mission structure | HIGH |
| Session monitor | Real-time tmux pane state tracking: port detection, agent busy/idle, title drift correction | Adapt for our terminal pane management | MED |
| Explorer widget | File tree with git status overlay, vim nav, search, send-to-agent | Enhance our Files module | MED |
| Changes widget | Git staged/unstaged/untracked with inline diff preview, stage/unstage ops | New component for Review module | HIGH |
| Costs widget | Per-agent session metrics: task count, elapsed time, avg time/task | New analytics widget | MED |
| Mission control widget | Tabbed TUI: agents (busy/idle), tasks (in-progress/todo/done), goals (milestone bars), activity (color-coded events) | Adapt for our Activity/Home module | MED |
| KanbanBoard (dashboard) | 4-column DnD board (TODO/DOING/REVIEW/DONE) with task cards, priority sorting | Already have similar in Tasks | LOW |
| Research system | Auto-dispatches research agents on triggers (mission start, stall, retry cluster, milestone progress) | New feature for background agents | MED |
| Tunnel manager | Expose local services via Cloudflare/ngrok/Tailscale tunnels | New Sandboxes feature | LOW |
| Remote/HQ registry | Register/discover machines via mDNS, heartbeat to central HQ | Future distributed agents | LOW |
| Agent team templates | Pre-configured multi-agent layouts (default, nextjs, convex, monorepo) | Enhance our Templates | MED |
| Stack detection | Auto-detect project type (language, framework, package manager) with reasoning | Workspace auto-config | MED |
| Validation contracts | Testable assertions (ASSERT01: endpoint returns 200) verified before milestone advancement | New Governance/QA feature | MED |
| Event log | Append-only log of all orchestrator events (dispatch, completion, stall, retry) with metrics | Enhance our Activity module | MED |

### Data Models

| Entity | Key Fields |
|--------|-----------|
| Task | id, title, description, status, assignee, priority (P1-P5), dependencies, milestone, specialty, assertions, proof, retries, discoveredIssues |
| Mission | id, title, milestones[], branch, status (planning/active/complete) |
| Milestone | id, title, sequence, status (locked/active/validating/done), tasks[], assertions[] |
| Goal | id, title, acceptanceCriteria, status, tasks[] |
| Validation | assertionId, claim, status (pass/fail), evidence, verifier |
| Session | name, panes[], config, theme |
| Pane | id, command, workDir, envVars, focus, title, role (lead/teammate) |
| Agent (Pane) | title, specialty, busy/idle, lastActivity |
| Research | type, trigger, cooldown, findings, learnings |
| Accounting | perAgent: { totalTimeMs, taskCount, lastTaskId } |

### Terminal Patterns Worth Lifting

1. **Declarative layout** -- YAML -> tmux session with rows/panes/commands/env
2. **Pane communication** -- Send commands between panes, cross-widget messaging
3. **Agent idle detection** -- Spinner char detection in pane titles + prompt detection
4. **Stall recovery** -- Nudge agents exceeding timeout, release crashed pane tasks
5. **Hot reload config** -- Watch ide.yml, apply changes without session restart
6. **Session naming** -- Named sessions with attach/detach/list/inspect
7. **Title drift correction** -- Detect when agent modifies pane title, restore original
8. **Theme system** -- accent, border, background, foreground per session
9. **Before hooks** -- Pre-launch commands before session creation
10. **Cast recording** -- Terminal session recording for replay

---

## Master Steal List (deduplicated, prioritized)

### Tier 1 -- Critical (build these)

| # | Priority | Effort | Feature | Source | What to Build |
|---|----------|--------|---------|--------|--------------|
| 1 | HIGH | M | Onboarding wizard | Cabinet | 5-8 step wizard: name, workspace type, agent selection, provider setup, first task |
| 2 | HIGH | M | Mission/milestone task structure | Tmux-IDE | Tasks module upgrade: mission -> milestones -> tasks with dependency gating |
| 3 | HIGH | M | Agent org chart + departments | Cabinet | Visual hierarchy in Agents module with department grouping, activity beacons |
| 4 | HIGH | M | Git changes panel | Tmux-IDE | New Review pane: staged/unstaged files, inline diff, stage/unstage actions |
| 5 | HIGH | M | Multi-agent orchestrator | Tmux-IDE | Backend: dispatch tasks to idle agents, dependency resolution, retry, stall detection |
| 6 | HIGH | S | Conversation approval panel | Cabinet | Inline approval cards in Build conversations for pending agent actions |
| 7 | HIGH | S | Conversation compaction | Cabinet | Auto-digest earlier turns when token usage > 80% of context window |
| 8 | HIGH | S | Task wrap-up signal | Cabinet | Visual cue when agent reaches natural stopping point, prompt completion |
| 9 | HIGH | M | Dashboard/home with widgets | Core-OSS | Bento grid home: workspace stats, recent activity, quick actions, agent status |
| 10 | HIGH | M | Agent heartbeat/routine system | Cabinet | Cron-based self-triggering for agents with schedule management UI |

### Tier 2 -- Important (build next)

| # | Priority | Effort | Feature | Source | What to Build |
|---|----------|--------|---------|--------|--------------|
| 11 | MED | M | Rich file viewers | Core-OSS | PDF, DOCX, PPTX, XLSX viewers in Files module |
| 12 | MED | M | AI app builder | Core-OSS | Prompt -> scaffold app: chat + live preview + download |
| 13 | MED | M | Research agent system | Tmux-IDE | Auto-dispatch research on triggers (stall, milestone, retry cluster) |
| 14 | MED | M | Wiki-links in docs | Cabinet | Internal `#page:slug` links with fuzzy path resolution |
| 15 | MED | S | Task density toggle | Cabinet | Compact/comfortable card spacing in task boards |
| 16 | MED | S | NL agent creation | Cabinet | Type description -> AI generates agent config |
| 17 | MED | M | Document version history | Cabinet + Core-OSS | Timeline of doc versions with restore |
| 18 | MED | M | Validation contracts | Tmux-IDE | Testable assertions verified before milestone advancement |
| 19 | MED | M | Skill trust levels + origins | Cabinet | Tag skills by source, flag executables, show upstream stats |
| 20 | MED | S | Stack auto-detection | Tmux-IDE | Auto-detect project type on workspace creation |

### Tier 3 -- Nice to Have

| # | Priority | Effort | Feature | Source | What to Build |
|---|----------|--------|---------|--------|--------------|
| 21 | MED | M | Email integration | Core-OSS | Gmail/Outlook sync module (huge scope) |
| 22 | MED | M | Calendar integration | Core-OSS | Google Cal/Microsoft 365 sync module |
| 23 | MED | M | Costs/metrics widget | Tmux-IDE | Per-agent session metrics: task count, time, avg |
| 24 | MED | S | Avatar catalog | Cabinet | 110+ preset avatars with search for profiles |
| 25 | MED | S | Accent color picker | Cabinet | 12+ presets or custom hex for workspace personalization |
| 26 | LOW | M | Tunnel manager | Tmux-IDE | Expose local services via Cloudflare/ngrok |
| 27 | LOW | M | Remote machine registry | Tmux-IDE | mDNS discovery + HQ heartbeat for distributed agents |
| 28 | LOW | L | Website/linktree builder | Core-OSS | Personal site generator (Core-OSS has placeholder only) |
| 29 | LOW | S | Cast recording | Tmux-IDE | Terminal session recording for replay |
| 30 | LOW | M | Public share links | Core-OSS | Permission-based sharing with public URLs |

---

## Modules to Add to Canopy

| Module Name | What It Does | Source | Priority |
|-------------|-------------|--------|----------|
| **Home** | Greeting + task launcher + workspace stats + bento widget grid | Cabinet + Core-OSS | HIGH |
| **Onboarding** | Multi-step setup wizard (name, type, agents, provider) | Cabinet | HIGH |
| **Mission Control** | Agent grid by department, pulse metrics, scheduler, NL creation | Cabinet | HIGH |
| **Review (enhanced)** | Git changes panel: staged/unstaged, inline diff, stage/unstage | Tmux-IDE | HIGH |
| **Email** | Gmail/Outlook sync with threads, categories, compose | Core-OSS | MED |
| **Calendar** | Google Cal/Microsoft 365 sync | Core-OSS | MED |
| **Dashboard** | Bento grid of workspace widget cards | Core-OSS | MED (merge with Home) |
| **App Builder** | Prompt -> app scaffold with live preview | Core-OSS | MED |

### Enhancements to Existing Modules

| Existing Module | Enhancement | Source |
|----------------|-------------|--------|
| Agents | Org chart view, department hierarchy, heartbeat/routine management, NL creation | Cabinet |
| Tasks | Mission/milestone structure, 5-lane kanban, density toggle, dependency gating | Cabinet + Tmux-IDE |
| Build | Approval panel, compaction, wrap-up signal, artifacts/diff/logs/transcript tabs | Cabinet |
| Files/Docs | Rich viewers (PDF/DOCX/PPTX/XLSX), wiki-links, folder indexing, version history | Core-OSS + Cabinet |
| Skills | Trust levels, origins, upstream stats, import/discover flow | Cabinet |
| Settings | Provider verification, accent color, avatar catalog, MCP config | Cabinet |
| Activity | Event log with color-coded types, orchestrator events | Tmux-IDE |
| Governance | Validation contracts, assertion tracking | Tmux-IDE |
| Schedule | Calendar + list views, heartbeat management | Cabinet |
| Analytics | Per-agent costs/metrics widget | Tmux-IDE |

---

## Stats Summary

- **Total distinct features cataloged across 3 repos:** 187
- **Features we already HAVE:** 98 (52%)
- **Features we have PARTIAL:** 36 (19%)
- **Features we're MISSING:** 53 (28%)
- **Top 10 critical builds:** Onboarding, Mission/Milestones, Agent Org Chart, Git Changes Panel, Multi-Agent Orchestrator, Approval Panel, Compaction, Wrap-Up Signal, Home Dashboard, Heartbeat System
- **New modules recommended:** 5 (Home, Onboarding, Mission Control, Email, Calendar)
- **Existing module enhancements:** 10 modules need upgrades
