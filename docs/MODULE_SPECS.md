# Canopy Module Specifications

> Complete module-by-module breakdown of every sidebar feature.
> Generated 2026-03-22. Covers frontend (SvelteKit 2 + Svelte 5), backend (Phoenix 1.8 + Ecto), and integration state.

---

## Table of Contents

| # | Module | Section | Route | Status |
|---|--------|---------|-------|--------|
| 1 | [Dashboard](#1-dashboard) | Core | `/app` | Working |
| 2 | [Inbox](#2-inbox) | Core | `/app/inbox` | Partial |
| 3 | [Office](#3-office) | Core | `/app/office` | Partial |
| 4 | [Library](#4-library) | Core | `/app/library` | Working (mock catalog) |
| 5 | [Issues](#5-issues) | Ops | `/app/issues` | Working |
| 6 | [Goals](#6-goals) | Ops | `/app/goals` | Partial |
| 7 | [Documents](#7-documents) | Ops | `/app/documents` | Partial |
| 8 | [Projects](#8-projects) | Projects | `/app/projects` | Partial |
| 9 | [Agents](#9-agents) | Team | `/app/agents` | Critical bugs |
| 10 | [Activity](#10-activity) | Monitor | `/app/activity` | SSE broken |
| 11 | [Sessions](#11-sessions) | Monitor | `/app/sessions` | Transcript broken |
| 12 | [Logs](#12-logs) | Monitor | `/app/logs` | Partial |
| 13 | [Costs](#13-costs) | Monitor | `/app/costs` | Key mismatches |
| 14 | [Memory](#14-memory) | Monitor | `/app/memory` | Field mismatches |
| 15 | [Signals](#15-signals) | Monitor | `/app/signals` | Field mismatches |
| 16 | [Skills](#16-skills) | Orchestrate | `/app/skills` | Minimal UI |
| 17 | [Schedules](#17-schedules) | Orchestrate | `/app/schedules` | Working |
| 18 | [Spawn](#18-spawn) | Orchestrate | `/app/spawn` | Working |
| 19 | [Webhooks](#19-webhooks) | Orchestrate | `/app/webhooks` | No create UI |
| 20 | [Alerts](#20-alerts) | Orchestrate | `/app/alerts` | Field mismatch + stub |
| 21 | [Integrations](#21-integrations) | Orchestrate | `/app/integrations` | Partial |
| 22 | [Users](#22-users) | Admin | `/app/users` | Field mismatch |
| 23 | [Audit](#23-audit) | Admin | `/app/audit` | Missing IP |
| 24 | [Gateways](#24-gateways) | Admin | `/app/gateways` | All fields undefined |
| 25 | [Config](#25-config) | Admin | `/app/config` | Full stub |
| 26 | [Templates](#26-templates) | Admin | `/app/templates` | Fields undefined |
| 27 | [Workspaces](#27-workspaces) | Admin | `/app/workspaces` | Status bug |
| 28 | [Terminal](#28-terminal) | Bottom | `/app/terminal` | Full stub |
| 29 | [Settings](#29-settings) | Bottom | `/app/settings` | Budget tab unwired |

---

## Cross-Cutting Issues

These problems affect multiple modules and should be fixed first:

| Issue | Affected Modules | Fix |
|-------|-----------------|-----|
| **IDOR across resource endpoints** | All 29 — `WorkspaceAuth` only fires on explicit `workspace_id` param | Add per-resource ownership check |
| **No rate limiting on auth** | Auth (login/refresh) | Add `hammer` or `plug_attack` |
| **Zero tests** | All 29 | Write tests per module |
| **544 hardcoded hex colors** | All frontend pages | Migrate to CSS token system |
| **18 Svelte 5 reactivity bugs** | GoalForm, IssueForm, AgentDesk3D, others | Fix `$props()` capture in closures |
| **No real-time push on most pages** | 25 of 29 modules | Subscribe to EventBus via SSE/Channel |
| **`inspect()` leaks in API** | Spawn, Documents | Replace with `format_errors()` |
| **Duplicate files** | Build | Delete `lib/canopy 2.ex`, `lib/canopy_web 2.ex` |

---

## CORE SECTION

---

## 1. DASHBOARD

### What
Landing page — single-pane overview showing KPIs, live runs, recent activity, cost burn, and backend health.

### Frontend
- **Route:** `/app`
- **Store:** `dashboardStore` (`dashboard.svelte.ts`)
- **Components:** KPI grid, live runs widget, recent activity feed, finance summary, quick actions, system health bar
- **State:** `kpis` (active_agents, total_agents, live_runs, open_issues, budget_remaining_pct), `liveRuns[]`, `recentActivity[]`, `financeSummary`, `systemHealth`, `isLoading`, `error`, `lastFetched`
- **API calls:** `GET /api/v1/dashboard` — single call returning all sections; 30s auto-refresh interval

### Backend
- **Controller:** `DashboardController` — `show/2`
- **Schema:** Aggregates from `Agent`, `Session`, `ActivityEvent`, `Issue`, `BudgetPolicy`, `CostEvent`
- **Business logic:** Five sequential Repo queries, date arithmetic, BEAM memory via `:erlang.memory()`
- **Endpoints:** `GET /api/v1/dashboard`

### Data Flow
Frontend polls every 30s. Re-fetches on workspace change via `$effect`. Single JSON envelope response.

### Current State
- ✅ Full polling pipeline works end-to-end
- ✅ KPIs, live runs, recent activity, finance cost aggregation
- ❌ `daily_limit_cents` always `0` — `BudgetPolicy` has no daily limit column
- ❌ `cpu_pct` always `0` — no system metrics collection
- ❌ `cache_savings_pct` always `0` — no cache token tracking on `CostEvent`

### Dependencies
- Depends on: Workspace, Agents, Sessions, Issues, Budget, Costs
- Feeds into: Nothing (read-only aggregation)

### Priority Fixes
1. Add `daily_limit_cents` to `BudgetPolicy` schema — `backend/lib/canopy/schemas/budget_policy.ex`
2. Add CPU sampling via `:cpu_sup` — `backend/lib/canopy_web/controllers/dashboard_controller.ex`
3. Track cache token savings on `CostEvent` — `backend/lib/canopy_web/controllers/dashboard_controller.ex`

---

## 2. INBOX

### What
Notification center surfacing agent alerts, approvals, budget warnings, mentions, and failures.

### Frontend
- **Route:** `/app/inbox`
- **Store:** `inboxStore` (`inbox.svelte.ts`)
- **Components:** Inbox filters, inbox feed
- **State:** `items[]`, `selected`, `filterType`, `filterStatus`, `searchQuery`; derived `unreadCount`, `filteredItems`, `typeGroups`
- **API calls:** `GET /api/v1/inbox`, `POST /inbox/:id/action`, `POST /inbox/:id/read`, `POST /inbox/read-all`

### Backend
- **Controller:** `InboxController` — `index`, `read`, `read_all`, `perform_action`
- **Schema:** `ActivityEvent` with `level = "notification"` discriminator; read state in `metadata["read"]`
- **Endpoints:** `GET /inbox`, `POST /inbox/read-all`, `POST /inbox/:id/read`, `POST /inbox/:id/action`

### Data Flow
Fetch all on mount. Client-side filtering. No real-time push — new notifications invisible until reload.

### Current State
- ✅ Fetch, filter, search, type-grouping, optimistic action updates
- ❌ `dismiss()` calls non-existent `POST /inbox/:id/dismiss` — will 404
- ❌ No real-time push for new notifications
- ⚠️ `markRead`/`markAllRead` update local state but don't call backend endpoints
- ⚠️ `total` count ignores workspace filter

### Dependencies
- Depends on: Workspace, ActivityEvent
- Feeds into: Nothing

### Priority Fixes
1. Add `POST /inbox/:id/dismiss` route or collapse into action endpoint — `backend/lib/canopy_web/router.ex`
2. Make `markRead`/`markAllRead` call backend — `desktop/src/lib/stores/inbox.svelte.ts`
3. Subscribe to EventBus for live notifications
4. Fix `total` workspace scoping — `backend/lib/canopy_web/controllers/inbox_controller.ex`

---

## 3. OFFICE

### What
2D pixel-art virtual office visualizing agent status and location on a tile-based canvas.

### Frontend
- **Route:** `/app/office`
- **Store:** `officeStore` (`office.svelte.ts`)
- **Components:** `VirtualOffice`, `PixelOffice` (canvas), `Office3D`, `Scene3D`, `AgentDesk3D`
- **State:** `viewMode` (2d/3d), `selectedAgentId`, derived `positions` (djb2 hash placement), `collaborationLinks`, `zoneAgents`
- **API calls:** `GET /agents` via `agentsStore.fetchAgents()` on mount

### Backend
- None — purely client-side after initial agents fetch

### Data Flow
`agentsStore.agents` → `officeStore` derives positions via `$derived`. `PixelOffice` uses `requestAnimationFrame` game loop. Critical `untrack()` fix prevents infinite reactivity loop.

### Current State
- ✅ 2D pixel office renders and animates agents
- ✅ Deterministic desk placement, click-to-inspect
- ✅ `untrack()` fix prevents crash
- ⚠️ 3D mode present but completion unknown
- ❌ Agent positions don't update live — page must be remounted
- ❌ Duplicated `viewMode` state between store and page

### Dependencies
- Depends on: Agents
- Feeds into: Nothing

### Priority Fixes
1. Deduplicate `viewMode` — `desktop/src/lib/stores/office.svelte.ts` vs `desktop/src/routes/app/office/+page.svelte`
2. Add interval or SSE to refresh agents while on page
3. Audit/complete 3D mode — `desktop/src/lib/components/office/Office3D.svelte`

---

## 4. LIBRARY

### What
Local marketplace catalog for browsing and deploying pre-built agents, skills, and workspace templates. All catalog data is static mock; deployment uses real backend endpoints.

### Frontend
- **Route:** `/app/library` (index), `/app/library/agents/[id]`, `/app/library/skills/[id]`, `/app/library/teams/[id]`, `/app/library/companies/[id]`
- **Store:** None — page-local `$state`; catalog from mock functions
- **Components:** `LibraryAgentCard`, `LibrarySkillCard`, `LibraryOperationCard`, `LibraryTemplateCard`
- **State:** `activeTab`, per-tab search/category/sort/viewMode; data loaded once from mock
- **API calls:** `deployTemplate()` service on deploy; detail routes use mock functions

### Backend
- **Controller:** `TemplateController` — `index`, `create`
- **Business logic:** `$lib/services/template-deploy` translates templates into backend API calls
- **Endpoints:** `GET /templates`, `POST /templates`, `GET /skills`, `POST /skills/import`

### Data Flow
Catalog loaded synchronously from in-memory mock arrays. No network on mount. Deploy triggers real backend calls.

### Current State
- ✅ Agents and skills tabs with search, category filter, sort, grid/list toggle
- ✅ 300ms debounce on search inputs
- ⚠️ Teams/companies tabs mock-only with unknown completeness
- ❌ No real backend catalog API — all static mock data

### Dependencies
- Depends on: Templates, Skills, Agents (for deployment)
- Feeds into: Agents store, Workspace store

### Priority Fixes
1. Build real backend catalog API — new controller needed
2. Audit `template-deploy` error handling — `desktop/src/lib/services/template-deploy.ts`
3. Complete or remove teams/companies tabs

---

## OPS SECTION

---

## 5. ISSUES

### What
Work-tracking board with kanban/list/table views, filtering, optimistic updates, and one-click dispatch to agents.

### Frontend
- **Route:** `/app/issues`
- **Store:** `issuesStore` (`issues.svelte.ts`)
- **Components:** `IssueViewSwitcher`, `IssueKanban`, `IssueList`, `IssueTable`, `IssueForm`
- **State:** `issues[]`, `selected`, filters (status/priority/assignee/search), sort, derived `filteredIssues`, `kanbanColumns`, `openCount`
- **API calls:** `GET /issues`, `GET /agents` (parallel), `POST /issues`, `PUT /issues/:id`, `DELETE /issues/:id`, `POST /issues/:id/dispatch`

### Backend
- **Controller:** `IssueController` — full CRUD + `assign`, `checkout`, `dispatch`
- **Schema:** `Issue` — title, description, status (backlog/todo/in_progress/in_review/done), priority, workspace_id, project_id, goal_id, assignee_id, checked_out_by
- **Business logic:** `IssueDispatcher` (GenServer), `IssueContext`, `Heartbeat` (via Task.Supervisor)
- **Endpoints:** Full CRUD + `/assign`, `/checkout`, `/dispatch`

### Data Flow
Dispatch pipeline: `POST /dispatch` → `IssueDispatcher.dispatch/1` → validates agent readiness → `IssueContext.build_context/2` → `Task.Supervisor` spawns Heartbeat. EventBus broadcasts on status changes.

### Current State
- ✅ Full CRUD, three view modes, dispatch pipeline wired end-to-end
- ✅ Checkout locking prevents double-dispatch (409)
- ❌ `assignee_name` always `nil` — no Agent join in list query
- ❌ `labels` always `[]`, `comments_count` always `0` — no joins
- ❌ No EventBus subscription — agent status changes invisible without reload
- ⚠️ `IssueDispatcher.dispatch/2` is blocking GenServer.call with no timeout

### Dependencies
- Depends on: Workspace, Agents, Goals, Projects
- Feeds into: GoalDecomposer, IssueDispatcher, Dashboard

### Priority Fixes
1. Join Agent in `index/2` for `assignee_name` — `backend/lib/canopy_web/controllers/issue_controller.ex`
2. Populate labels and comments_count in serializer
3. Add EventBus subscription for live status updates
4. Add timeout to `IssueDispatcher.dispatch/2` GenServer.call

---

## 6. GOALS

### What
Hierarchical objective tracker scoped to projects, with AI decomposition into issues via Claude CLI.

### Frontend
- **Route:** `/app/goals`
- **Store:** `goalsStore` (`goals.svelte.ts`)
- **Components:** `GoalHierarchy`, `GoalForm`
- **State:** `goals[]` (tree), `selected`, `activeProjectId`, filters (status/priority/search), derived `flatGoals`, `filteredGoals`, `overallProgress`
- **API calls:** `GET /goals?project_id=`, `POST /goals`, `PUT /goals/:id`, `POST /goals/:id/decompose`

### Backend
- **Controller:** `GoalController` — CRUD + `ancestry`, `decompose`
- **Schema:** `Goal` — title, description, status, workspace_id, project_id, parent_id; self-referential children
- **Business logic:** `GoalDecomposer` — builds prompt, runs `System.cmd("claude", ...)`, parses JSON, creates Issues
- **Endpoints:** Full CRUD + `/ancestry`, `/decompose`

### Data Flow
Goals scoped to project via `projectsStore.selected`. Decompose is synchronous HTTP blocking for full LLM inference.

### Current State
- ✅ Manual CRUD, AI decomposition pipeline
- ✅ Ancestry traversal, markdown code-fence stripping
- ❌ No `priority`, `progress`, or `issue_count` columns on Goal schema — `filterPriority` is dead code
- ❌ `index` returns flat goals — no tree nesting server-side
- ❌ Decompose blocks HTTP connection for full LLM time — no background job
- ❌ `ClaudeBinary.find()` crash if CLI not installed

### Dependencies
- Depends on: Projects, Workspace, Agents (for decomposer)
- Feeds into: Issues, IssueDispatcher

### Priority Fixes
1. Add `progress`/`issue_count` as computed fields to `GoalController.index` — `backend/lib/canopy_web/controllers/goal_controller.ex`
2. Remove dead `filterPriority` — `desktop/src/lib/stores/goals.svelte.ts`
3. Move decompose to background job with polling/streaming
4. Guard `ClaudeBinary.find()` with descriptive error

---

## 7. DOCUMENTS

### What
File browser for the workspace's `.canopy/reference/` directory with filesystem read/write and revision history.

### Frontend
- **Route:** `/app/documents`
- **Store:** `documentsStore` (`documents.svelte.ts`)
- **Components:** `DocumentTree`, `DocumentViewer`
- **State:** `documents[]`, `tree[]`, `selected`, `loading`, `error`
- **API calls:** `GET /documents` on mount only

### Backend
- **Controller:** `DocumentController` — CRUD + `revisions`
- **Schema:** `DocumentRevision` (history); files are filesystem objects
- **Business logic:** `resolve_reference_dir/1` resolves workspace path, calls `File.mkdir_p!`
- **Endpoints:** `GET /documents`, `GET /documents/*path`, `POST /documents`, `PUT /documents/*path`, `DELETE /documents/*path`, `GET /document-revisions`

### Data Flow
Backend reads/writes `.canopy/reference/` filesystem. No real-time, no workspace-change re-fetch.

### Current State
- ✅ Backend filesystem read/write pipeline
- ✅ DocumentRevision history endpoint
- ❌ Store silently swallows all fetch errors
- ❌ No workspace-change re-fetch
- ❌ No `createDocument`/`updateDocument`/`deleteDocument` in store
- ❌ `update/2` doesn't write DocumentRevision records

### Dependencies
- Depends on: Workspace (filesystem path)
- Feeds into: Agent context (reference material)

### Priority Fixes
1. Add workspace-change `$effect` — `desktop/src/routes/app/documents/+page.svelte`
2. Add CRUD methods to store — `desktop/src/lib/stores/documents.svelte.ts`
3. Surface fetch errors to user
4. Write DocumentRevision on every update — `backend/lib/canopy_web/controllers/document_controller.ex`

---

## PROJECTS SECTION

---

## 8. PROJECTS

### What
Top-level organizational container grouping goals, issues, and agents into named workspace-scoped units.

### Frontend
- **Route:** `/app/projects` (list), `/app/projects/[id]` (detail)
- **Store:** `projectsStore` (`projects.svelte.ts`)
- **Components:** Card grid, create dialog, detail page with metrics
- **State:** `projects[]`, `selected`, `loading`, `error`, filters (status/search), derived `filteredProjects`, `activeCount`, `totalCount`
- **API calls:** `GET /projects?workspace_id=`, `POST /projects`, `GET /projects/:id`

### Backend
- **Controller:** `ProjectController` — CRUD + `goals`, `workspaces`
- **Schema:** `Project` — name, description, status, workspace_id
- **Endpoints:** Full CRUD + `/goals`, `/workspaces`

### Data Flow
Fetches on workspace change. Client-side filtering. Create is optimistic.

### Current State
- ✅ List with status filter, search, create dialog
- ❌ Detail page reads from mock `getProjectById()` — never calls real backend
- ❌ Edit/Archive/Delete buttons have empty `onclick={() => {}}` handlers
- ❌ Backend serializer missing `goal_count`, `issue_count`, `agent_count` for list
- ❌ `workspaces` action returns `[]` (stub)

### Dependencies
- Depends on: Workspace
- Feeds into: Goals, Issues, Agents

### Priority Fixes
1. Wire `[id]/+page.svelte` to `projectsStore.fetchProject(id)` instead of mock
2. Wire Edit/Archive/Delete buttons — `desktop/src/routes/app/projects/[id]/+page.svelte`
3. Add counts to `ProjectController.index` serializer

---

## TEAM SECTION

---

## 9. AGENTS

### What
**Most critical module.** Autonomous worker entities with full lifecycle (sleeping→idle→running→paused→terminated), org hierarchy, per-agent cost tracking, skills, schedules, and budget policies.

### Frontend
- **Route:** `/app/agents` (roster), `/app/agents/[id]` (detail — 7 tabs)
- **Store:** `agentsStore` (`agents.svelte.ts`)
- **Components:** `AgentCard`, `AgentTable`, `HireAgentDialog`, status/badge components
- **State:** `agents[]`, `hierarchy[]`, `selected`, `viewMode` (grid/org/table), filters, derived `filteredAgents`, `activeCount`
- **API calls:** `GET /agents`, `POST /agents`, lifecycle actions (`/wake`, `/sleep`, `/pause`, `/resume`, `/focus`, `/terminate`), `DELETE /agents/:id`, `GET /agents/hierarchy`

### Backend
- **Controller:** `AgentController` — CRUD + lifecycle + `runs`, `inbox`, `hierarchy`
- **Schema:** `Agent` — slug, name, role, adapter, model, status, config (jsonb), system_prompt, workspace_id, reports_to
- **Business logic:** `transition_status/4`, `serialize_with_skills/1` (N+1 bug)
- **Endpoints:** 14 total

### N+1 Bug
`serialize_with_skills/1` fires **3 extra DB queries per agent** in list response. 50 agents = 151 queries.

### Status Mismatch
| Frontend expects | Backend returns |
|-----------------|----------------|
| `idle` | `active` |
| `running` | `working` |

After lifecycle actions, status badges render incorrectly until next full fetch.

### Current State
- ✅ List/filter/search, grid/table views, hire dialog, lifecycle buttons with optimistic update
- ✅ Detail page (7 tabs)
- ❌ **N+1: 3N+1 queries per list request**
- ❌ **Status mismatch: backend `active`/`working` vs frontend `idle`/`running`**
- ❌ Resume sends `wake` instead of `resume` (different backend behavior)
- ❌ Org chart calls wrong endpoint — shows stub
- ❌ Runs tab: stub — `GET /agents/:id/runs` never called
- ❌ Inbox tab: stub — never called
- ⚠️ `schedule_id`/`budget_policy_id` always nil

### Dependencies
- Depends on: Workspace, Costs, Schedules, Sessions
- Feeds into: Activity, Sessions, Costs, Logs, all other modules

### Priority Fixes
1. **Fix N+1** — batch queries in `serialize_with_skills/1` — `backend/lib/canopy_web/controllers/agent_controller.ex`
2. **Fix status mismatch** — align backend status strings with frontend `AgentStatus` union
3. **Fix resume routing** — `desktop/src/routes/app/agents/[id]/+page.svelte`
4. **Wire Runs tab** — call `agentsApi.runs(agentId)`
5. **Wire Org chart** — `fetchHierarchy()` should call `/agents/hierarchy`

---

## MONITOR SECTION

---

## 10. ACTIVITY

### What
Live event stream of all system activity with SSE real-time subscription.

### Frontend
- **Route:** `/app/activity`
- **Store:** `activityStore` (`activity.svelte.ts`)
- **Components:** Activity feed, filters
- **State:** `events[]` (500 ring buffer), `connected`, filters (type/level/agent/search), derived `filteredEvents`, `errorCount`
- **API calls:** `GET /activity?limit=100` (initial), `GET /activity/stream` (SSE)

### Backend
- **Controller:** `ActivityController` — `index`, `stream`
- **Schema:** `ActivityEvent`
- **Endpoints:** `GET /activity`, `GET /activity/stream` (SSE, unauthenticated scope)

### Data Flow
HTTP initial fetch + persistent SSE subscription. Backend emits events, frontend appends to ring buffer.

### Current State
- ✅ HTTP fetch, display, filters, SSE opens
- ❌ **SSE payload shape mismatch** — backend emits `{event: "agent.hired", ...}` but store expects `{type: "system_event", event: "activity"}` — **live events silently dropped**
- ❌ SSE stream endpoint has no JWT check
- ⚠️ `total` count ignores workspace filter

### Dependencies
- Depends on: Workspace, Agents
- Feeds into: Logs, Signals

### Priority Fixes
1. **Fix SSE payload shape** — `desktop/src/lib/stores/activity.svelte.ts` — handle raw backend shape
2. Fix `total` workspace scoping — `backend/lib/canopy_web/controllers/activity_controller.ex`

---

## 11. SESSIONS

### What
Observability for all agent execution sessions — list + detail with live-streaming transcript.

### Frontend
- **Route:** `/app/sessions` (list), `/app/sessions/[id]` (detail)
- **Store:** `sessionsStore` (`sessions.svelte.ts`)
- **Components:** `SessionList`, `SessionOverview`, `ExecutionWorkspace`
- **State:** `sessions[]`, filters, `selectedSession`, `transcript[]`, `isLive`, pagination
- **API calls:** `GET /sessions`, `GET /sessions/:id`, `GET /sessions/:id/transcript`, `GET /sessions/:id/stream` (SSE), `POST /sessions/:id/message`

### Backend
- **Controller:** `SessionController` — `index`, `show`, `delete`, `transcript`, `message`, `stream`
- **Schema:** `Session`, `SessionEvent`
- **Endpoints:** 6 total

### Data Flow
List fetch + detail fetch + SSE for live sessions. Transcript re-fetched from REST when stream completes.

### Current State
- ✅ List, filter, pagination, SSE streaming wired
- ❌ **Transcript shape mismatch** — backend returns `SessionEvent` rows but frontend expects `Message[]` — **transcript always renders empty**
- ❌ `message_count` hardcoded to `0`
- ❌ Session SSE has no keepalive — drops silently
- ⚠️ `total` not workspace-scoped

### Dependencies
- Depends on: Agents
- Feeds into: Costs, Activity

### Priority Fixes
1. **Fix transcript serialization** — map `SessionEvent` to `Message` shape — `backend/lib/canopy_web/controllers/session_controller.ex`
2. Add 30s keepalive to session SSE loop
3. Fix `message_count` with subquery

---

## 12. LOGS

### What
Structured log viewer with level filtering and real-time SSE streaming. 10K entry ring buffer.

### Frontend
- **Route:** `/app/logs`
- **Store:** `logsStore` (`logs.svelte.ts`)
- **Components:** Log filters, log viewer
- **State:** `entries[]` (10K cap), `connected`, `isPaused`, filters (levels/source/agent/search)
- **API calls:** `GET /activity?limit=200` (initial — no `/logs` REST endpoint), `GET /logs/stream` (SSE)

### Backend
- **Controller:** `LogController` — `stream` only
- **Endpoints:** `GET /logs/stream` (SSE, unauthenticated scope)

### Data Flow
Initial load borrows `/activity` endpoint. SSE for live streaming.

### Current State
- ✅ SSE streaming, ring buffer, level coloring
- ❌ **No `GET /logs` REST endpoint** — initial fetch uses wrong shape from `/activity`
- ❌ **`isPaused` has no effect** — SSE handler doesn't check it
- ❌ Filter params never passed to SSE URL

### Dependencies
- Depends on: Activity (borrows REST endpoint)
- Feeds into: Nothing

### Priority Fixes
1. Add `LogController.index/2` — `backend/lib/canopy_web/controllers/log_controller.ex`
2. Gate `isPaused` in SSE handler — `desktop/src/lib/stores/logs.svelte.ts`
3. Pass filter params to SSE URL

---

## 13. COSTS

### What
Cost observability + budget enforcement dashboard with spend analysis, policy management, and incident tracking.

### Frontend
- **Route:** `/app/costs`
- **Store:** `costsStore` (`costs.svelte.ts`)
- **Components:** `CostDashboard`
- **State:** `summary`, `agentBreakdown[]`, `modelBreakdown[]`, `policies[]`, `incidents[]`, `dailyTrend[]`, `dateRange`
- **API calls:** `GET /costs/summary`, `GET /costs/by-agent`, `GET /costs/by-model`, `GET /budgets`, `GET /budgets/incidents`

### Backend
- **Controllers:** `CostController` (5 actions), `BudgetController` (4 actions)
- **Schema:** `CostEvent`, `BudgetPolicy`, `BudgetIncident`
- **Business logic:** `BudgetEnforcer` GenServer with ETS atomic accumulators
- **Endpoints:** 9 total

### Data Flow
Frontend fetches all sections in parallel. Budget enforcement is entirely backend-side via ETS.

### Current State
- ✅ Summary, breakdowns, policy list, incident list, BudgetEnforcer GenServer
- ❌ **`policies` vs `budgets` key mismatch** — backend returns `{budgets: ...}`, frontend reads `data.policies`
- ❌ `daily` trend endpoint exists but `fetchTrends()` returns `[]` — chart always empty
- ❌ `daily_budget_cents`/`daily_remaining_cents` always `0`
- ❌ `cache_savings_cents` always `0`
- ⚠️ Workspace-scope ETS entries never pre-loaded

### Dependencies
- Depends on: Agents, Sessions, EventBus
- Feeds into: Agents (hard stop), Activity

### Priority Fixes
1. Fix `policies`/`budgets` key mismatch — `backend/lib/canopy_web/controllers/budget_controller.ex`
2. Wire `fetchTrends()` to `GET /costs/daily` — `desktop/src/lib/stores/costs.svelte.ts`
3. Pre-load workspace-scope ETS on init — `backend/lib/canopy/budget_enforcer.ex`

---

## 14. MEMORY

### What
Key-value store browser for agent/workspace memory with CRUD, namespace filtering, and search.

### Frontend
- **Route:** `/app/memory`
- **Store:** `memoryStore` (`memory.svelte.ts`)
- **Components:** Memory browser
- **State:** `entries[]`, `namespaces[]`, `selected`, `activeNamespace`, `searchQuery`, pagination
- **API calls:** `GET /memory`, `GET /memory/search?q=`, `POST /memory`, `PATCH /memory/:id`, `DELETE /memory/:id`

### Backend
- **Controller:** `MemoryController` — CRUD + `search`
- **Schema:** `MemoryEntry` — key, content, category, tags, workspace_id, agent_id
- **Endpoints:** 6 total

### Data Flow
Fetch on mount. Search replaces entries with results. CRUD is optimistic.

### Current State
- ✅ Full CRUD, namespace filter, search, pagination, optimistic updates
- ❌ **`GET /memory/namespaces` route doesn't exist** — 404, namespaces always `[]`
- ❌ **Backend field `content` vs frontend field `value`** — name divergence throughout
- ⚠️ `search` uses `ILIKE` with no index — full table scan

### Dependencies
- Depends on: Workspace, Agents
- Feeds into: Agent runtime (knowledge tool)

### Priority Fixes
1. Add `GET /memory/namespaces` route — `backend/lib/canopy_web/router.ex`
2. Reconcile `content` vs `value` field name across all files
3. Add GIN index for search

---

## 15. SIGNALS

### What
Signal Theory observability surface — records/classifies inter-agent signals per S=(M,G,T,F,W) framework.

### Frontend
- **Route:** `/app/signals`
- **Store:** `signalsStore` (`signals.svelte.ts`)
- **Components:** Inline signal list
- **State:** `signals[]`, `searchQuery`, `filterChannel`, `filterMode`; derived `filteredSignals`
- **API calls:** `GET /signals/feed?limit=100`

### Backend
- **Controller:** `SignalController` — `classify`, `feed`, `patterns`, `stats`
- **Schema:** None — feeds from `ActivityEvent` rows with `level IN [warn, error]`
- **Endpoints:** 4 total

### Data Flow
Fetch on mount. Client-side filtering. No real-time.

### Current State
- ✅ Feed display, search, classify endpoint with full Signal Theory heuristics
- ❌ **Backend `feed` returns wrong shape** — missing `channel`, `mode`, `genre`, `tier`, `weight`, `input_preview`, `failure_mode` — all render blank
- ❌ `filterChannel`/`filterMode` non-functional (fields never populated)
- ❌ `patterns`/`stats` endpoints implemented but never called from frontend

### Dependencies
- Depends on: Activity (data source)
- Feeds into: Nothing

### Priority Fixes
1. Align `feed` serialization with frontend `Signal` type — `backend/lib/canopy_web/controllers/signal_controller.ex`
2. Create `signals` table for structured metadata
3. Wire `patterns`/`stats` to frontend

---

## ORCHESTRATE SECTION

---

## 16. SKILLS

### What
Named capabilities that can be enabled/disabled per workspace and injected into agent sessions.

### Frontend
- **Route:** `/app/skills`
- **Store:** `skillsStore` (`skills.svelte.ts`)
- **Components:** Inline list
- **State:** `skills[]`, `loading`, `error`; derived `enabledCount`, `totalCount`, `filteredSkills`
- **API calls:** `GET /skills`, `POST /skills/:id/toggle`

### Backend
- **Controller:** `SkillController` — `index`, `show`, `toggle`, `bulk_enable/disable`, `categories`, `import`, `inject`
- **Schema:** `Skill` — name, description, category, trigger_rules, enabled, workspace_id
- **Endpoints:** 8 total

### Current State
- ✅ List, toggle with optimistic update, retry
- ❌ No create/delete UI
- ❌ No search or category filter in UI (backend supports both)
- ❌ `version` field renders `vundefined` — not in backend serializer

### Priority Fixes
1. Add `version` to serializer — `backend/lib/canopy_web/controllers/skill_controller.ex`
2. Wire category/search filters
3. Add create/delete to store and UI

---

## 17. SCHEDULES

### What
Cron-based agent activation backed by Quantum, with timeline visualization and run history.

### Frontend
- **Route:** `/app/schedules`
- **Store:** `schedulesStore` (`schedules.svelte.ts`)
- **Components:** `ScheduleTimeline`, `ScheduleCard`, `ScheduleForm`, `RunHistory`, `WakeupQueue`
- **State:** `schedules[]`, `runHistory`, `selected`, 11 cron presets
- **API calls:** `GET /schedules`, `POST /schedules`, `PATCH /schedules/:id`, `DELETE /schedules/:id`, `POST /schedules/:id/trigger`

### Backend
- **Controller:** `ScheduleController` — CRUD + `trigger`, `queue`, `wake_all`, `pause_all`
- **Schema:** `Schedule` — name, cron_expression, context, enabled, timezone, agent_id
- **Business logic:** `trigger` dispatches `Heartbeat.run` via Task.Supervisor
- **Endpoints:** 9 total

### Current State
- ✅ Full CRUD, timeline, card grid, wakeup queue, trigger
- ⚠️ Run history N+1 — per-schedule endpoint fetched individually
- ❌ No real-time status update when Quantum fires automatically
- ❌ `agent_name` hardcoded to `nil` in non-index serialize path

### Priority Fixes
1. Verify `/schedules/:id/runs` route exists in router
2. Batch run history into index response
3. Propagate `agent_name` through all serialize paths

---

## 18. SPAWN

### What
Fire-and-forget agent launcher — creates Session, dispatches Heartbeat, polls active instances.

### Frontend
- **Route:** `/app/spawn`
- **Store:** `spawnStore` (`spawn.svelte.ts`)
- **Components:** `SpawnForm`, `SpawnPresets`, `ActiveInstances`, `SpawnHistory`
- **State:** `instances[]`, derived `activeInstances`, `completedInstances`, `activeCount`, `totalCostCents`
- **API calls:** `POST /spawn`, `GET /spawn/active` (5s polling), `DELETE /spawn/:id`

### Backend
- **Controller:** `SpawnController` — `create`, `active`, `kill`, `history`
- **Business logic:** Creates Session row, dispatches Heartbeat with pre-created session_id
- **Endpoints:** 4 total

### Current State
- ✅ Create, active display, history, idle-aware polling, preset prefill
- ❌ Kill button not wired in UI
- ❌ Field name mismatch: frontend `task` vs backend `context`

### Priority Fixes
1. Reconcile `task`/`context` field name
2. Wire kill button in `ActiveInstances`
3. Verify `spawnApi.list()` maps to `/spawn/active`

---

## 19. WEBHOOKS

### What
Outbound event hooks and inbound payload receivers with HMAC-SHA256 signing and delivery logging.

### Frontend
- **Route:** `/app/webhooks`
- **Store:** `webhooksStore` (`webhooks.svelte.ts`)
- **Components:** Inline list
- **State:** `webhooks[]`, `loading`, `error`
- **API calls:** `GET /webhooks`, `DELETE /webhooks/:id`

### Backend
- **Controller:** `WebhookController` — CRUD + `test`, `deliveries`, `receive`
- **Schema:** `Webhook`, `WebhookDelivery`
- **Business logic:** `test` fires real HTTP POST with HMAC signature; `receive` verifies incoming signature
- **Endpoints:** 8 total (including public `receive`)

### Current State
- ✅ List with delete
- ✅ Backend complete with outbound + inbound + delivery logging
- ❌ **No create webhook form in UI**
- ❌ No test, delivery history, or update UI
- ❌ `receive` endpoint routing unverified for public access

### Priority Fixes
1. Add "New Webhook" form — `desktop/src/routes/app/webhooks/+page.svelte`
2. Add delivery history and test-fire UI
3. Confirm `receive` endpoint is outside authenticated pipeline

---

## 20. ALERTS

### What
Declarative rules that compare entity fields against thresholds and trigger notification actions.

### Frontend
- **Route:** `/app/alerts`
- **Store:** `alertsStore` (`alerts.svelte.ts`)
- **Components:** Inline list
- **State:** `rules[]`, `loading`, `error`; derived `totalCount`, `enabledCount`
- **API calls:** `GET /alerts/rules`

### Backend
- **Controller:** `AlertController` — CRUD + `evaluate`, `history`
- **Schema:** `AlertRule`, `AlertHistory`
- **Endpoints:** 7 total

### Current State
- ✅ List display with condition expression
- ❌ **`evaluate` is a stub** — no live rule evaluation
- ❌ **Page uses `rule.entity_type` but backend returns `rule.entity`** — renders `undefined`
- ❌ No create/edit/delete UI
- ❌ No alert history UI

### Priority Fixes
1. Fix `entity_type` → `entity` field name — `desktop/src/routes/app/alerts/+page.svelte`
2. Add create/edit modal
3. Implement live rule evaluation

---

## 21. INTEGRATIONS

### What
Dual-tab page: Adapters (local runtime detection via Tauri IPC) + Services (backend-persisted third-party connections).

### Frontend
- **Route:** `/app/integrations`
- **Store:** `integrationsStore` (`integrations.svelte.ts`)
- **Components:** Adapter grid cards, OSA setup wizard, services tab
- **State:** Adapters (local Tauri state), services (`integrations[]`)
- **API calls:** Tauri IPC (adapters), `GET /integrations` (services)

### Backend
- **Controller:** `IntegrationController` — `index`, `connect`, `disconnect`, `status`, `pull_all`
- **Schema:** `Integration`
- **Endpoints:** 5 total

### Current State
- ✅ Adapter detection, install, health check, OSA setup
- ❌ `pull_all` is a stub — no sync logic
- ❌ Services tab: no connect/disconnect UI
- ❌ `connectedCount` checks `i.status === "connected"` but serializer returns `i.connected: boolean` — always 0

### Priority Fixes
1. Fix `connectedCount` — check `i.connected === true` — `desktop/src/lib/stores/integrations.svelte.ts`
2. Add connect/disconnect actions in Services tab
3. Implement `pull_all` sync logic

---

## ADMIN SECTION

---

## 22. USERS

### What
Admin roster for human accounts with role-based filtering.

### Frontend
- **Route:** `/app/users`
- **Store:** `usersStore` (`users.svelte.ts`)
- **State:** `users[]`, `selected`, `searchQuery`, `filterRole`
- **API calls:** `GET /users`

### Backend
- **Controller:** `UserController` — full CRUD
- **Schema:** `User`
- **Endpoints:** 5 total

### Current State
- ✅ List with role filter, search
- ❌ `user.created_at` doesn't exist — field is `inserted_at` — **renders "Invalid Date"**
- ❌ No invite/edit/delete UI
- ❌ Row click selection does nothing

### Priority Fixes
1. Fix `created_at` → `inserted_at` — `desktop/src/routes/app/users/+page.svelte`
2. Add invite/edit modal
3. Add role-change action

---

## 23. AUDIT

### What
Paginated, append-only record of every system action.

### Frontend
- **Route:** `/app/audit`
- **Store:** `auditStore` (`audit.svelte.ts`)
- **State:** `entries[]`, `page`, `hasMore`, `searchQuery`
- **API calls:** `GET /audit` (paginated)

### Backend
- **Controller:** `AuditController` — `index`
- **Schema:** `AuditEvent`
- **Business logic:** Entries auto-written by `Canopy.Plugs.Audit`
- **Endpoints:** 1

### Current State
- ✅ Paginated table, load-more, client search
- ✅ Auto-written by Audit plug
- ❌ `ip_address` hardcoded to `nil` — column always shows `—`
- ❌ Date range/action/actor filters not exposed in UI
- ❌ `totalCount` reflects only loaded entries, ignores server `total`

### Priority Fixes
1. Add `ip_address` to `AuditEvent` schema + capture from `conn.remote_ip` in Audit plug
2. Use server `total` field in store
3. Expose server-side filters in UI

---

## 24. GATEWAYS

### What
LLM API endpoint registrations with live health probing and latency measurement.

### Frontend
- **Route:** `/app/gateways`
- **Store:** `gatewaysStore` (`gateways.svelte.ts`)
- **State:** `gateways[]`; derived `totalCount`, `healthyCount`, `primaryGateway`
- **API calls:** `GET /gateways`, `POST /gateways/:id/probe`

### Backend
- **Controller:** `GatewayController` — `index`, `create`, `delete`, `probe`
- **Schema:** `Gateway` — url, status, latency_ms, is_primary, token
- **Endpoints:** 4 total

### Current State
- ✅ Backend probe with real HTTP call and latency
- ❌ **Template references `gw.name`, `gw.provider`, `gw.endpoint`, `gw.models` — none in serializer — ALL render as `undefined`**
- ❌ No create/delete UI
- ❌ `healthyCount` checks `"healthy"` but probe sets `"connected"` — always 0

### Priority Fixes
1. Add `name`, `provider`, `endpoint`, `models` to Gateway schema + serializer
2. Fix `healthyCount` status check
3. Add create form

---

## 25. CONFIG

### What
Instance-wide runtime configuration (model defaults, concurrency, feature flags).

### Frontend
- **Route:** `/app/config`
- **Store:** none
- **Components:** Static placeholder
- **API calls:** none

### Backend
- **Controller:** `ConfigController` — `show`, `update`
- **Business logic:** Reads/writes `Application.env` (non-persistent)
- **Endpoints:** `GET /config`, `PATCH /config`

### Current State
- ❌ **Page is entirely a stub — "Backend required" placeholder**
- ✅ Backend fully implemented with 7 whitelisted config keys
- ⚠️ Changes lost on node restart — no persistence

### Priority Fixes
1. Build Config page — fetch and render editable fields
2. Create `configStore`
3. Persist config to database

---

## 26. TEMPLATES

### What
Pre-configured agent workspace blueprints.

### Frontend
- **Route:** `/app/templates`
- **Store:** `templatesStore` (`templates.svelte.ts`)
- **State:** `templates[]`, `searchQuery`, `filterCategory`
- **API calls:** `GET /templates`

### Backend
- **Controller:** `TemplateController` — `index`, `create`
- **Schema:** `Template`
- **Endpoints:** 2 total

### Current State
- ✅ Card grid with category filter, search
- ❌ Template cards reference `adapter`, `model`, `downloads` — **not in serializer — all `undefined`**
- ❌ No "Apply Template" action
- ❌ No update/delete endpoints

### Priority Fixes
1. Add missing fields to serializer — `backend/lib/canopy_web/controllers/template_controller.ex`
2. Implement "Apply" action
3. Add PATCH/DELETE endpoints

---

## 27. WORKSPACES

### What
Root organizational unit — a named directory with `.canopy/` protocol folder. Bridges Tauri IPC, localStorage, and backend.

### Frontend
- **Route:** `/app/workspaces`
- **Store:** `workspaceStore` (`workspace.svelte.ts`)
- **State:** `workspaces[]`, `activeWorkspaceId`, `lastScan`
- **API calls:** localStorage reads, `POST /workspaces/:id/activate`, `GET /workspaces`, Tauri IPC (`scan_canopy_dir`, `watch_canopy_dir`)

### Backend
- **Controller:** `WorkspaceController` — CRUD + `activate`, `agents`, `skills`, `config`
- **Schema:** `Workspace` — name, path, status, owner_id
- **Business logic:** `create` scaffolds `.canopy/` directory; `activate` archives all others
- **Endpoints:** 9 total

### Data Flow
Three-layer state: localStorage (truth for frontend), Tauri IPC (filesystem scan), backend (sync).

### Current State
- ✅ Card list, activate/delete, Tauri scan + watch, backend sync
- ❌ **`activate` sets others to `archived` — cannot re-activate** (no `inactive` status)
- ❌ Stats only populated for active workspace — others show zeros
- ❌ Backend N+1 aggregate counts in index

### Priority Fixes
1. Fix `activate` status — use `inactive` instead of `archived` — `backend/lib/canopy_web/controllers/workspace_controller.ex`
2. Replace N+1 counts with window functions
3. Populate stats for inactive workspaces

---

## BOTTOM SECTION

---

## 28. TERMINAL

### What
Planned embedded interactive shell for agent interaction and log streaming.

### Frontend
- **Route:** `/app/terminal`
- **Store:** none
- **Components:** Static placeholder with animated cursor
- **API calls:** none

### Backend
- None

### Current State
- ❌ **Entire feature is a stub — zero functionality**

### Priority Fixes
1. Add `@xterm/xterm` integration
2. Implement Phoenix Channel for shell I/O
3. Replace stub page

---

## 29. SETTINGS

### What
Tabbed config panel for user preferences (theme, adapter, model, budget, notifications).

### Frontend
- **Route:** `/app/settings`
- **Store:** `settingsStore` (`settings.svelte.ts`)
- **Components:** 7 tab sub-components (General, Appearance, Agents, Budget, Notifications, Integrations, Advanced)
- **State:** `data: Settings`, `miosaCloud`, `dirty`
- **API calls:** `GET /config`, `PATCH /config`, Tauri store reads

### Backend
- **Controller:** `ConfigController` (shared with Config module)
- **Business logic:** Only 7 whitelisted keys accepted; `theme`, `font_size`, etc. silently dropped
- **Endpoints:** `GET /config`, `PATCH /config`

### Current State
- ✅ Tab navigation, dirty tracking, save, theme selection, advanced tools
- ❌ **BudgetSettings tab values are local `$state` only — not connected to store or backend**
- ❌ Most Settings fields dropped by backend whitelist
- ⚠️ Settings non-persistent (Application env)

### Priority Fixes
1. Connect BudgetSettings to `settingsStore` — `desktop/src/routes/app/settings/tabs/BudgetSettings.svelte`
2. Create dedicated `SettingsController` or expand whitelist
3. Persist settings to database

---

## Summary: Fix Priority Matrix

### P0 — Blocks core user flow
| # | Fix | Modules affected |
|---|-----|-----------------|
| 1 | Fix Agent status mismatch (`active`/`working` vs `idle`/`running`) | 9, 1, 10, 17 |
| 2 | Fix Session transcript shape (SessionEvent→Message) | 11 |
| 3 | Fix Activity SSE payload shape mismatch | 10 |
| 4 | Fix Agent N+1 (3N+1 queries per list) | 9 |
| 5 | Fix Costs `policies`/`budgets` key mismatch | 13 |
| 6 | Fix Memory `content`/`value` field divergence | 14 |
| 7 | Fix Signals `feed` serialization (all fields blank) | 15 |
| 8 | Fix Gateway serialization (all fields `undefined`) | 24 |

### P1 — Broken functionality
| # | Fix | Modules |
|---|-----|---------|
| 9 | Add `GET /memory/namespaces` route | 14 |
| 10 | Add `GET /logs` REST endpoint | 12 |
| 11 | Fix `dismiss()` 404 in Inbox | 2 |
| 12 | Fix Project detail (reads mock instead of backend) | 8 |
| 13 | Fix `entity_type`→`entity` in Alerts | 20 |
| 14 | Fix `created_at`→`inserted_at` in Users | 22 |
| 15 | Fix `connected`/`status` in Integrations store | 21 |
| 16 | Fix Workspace `activate` status bug | 27 |
| 17 | Fix Template serializer missing fields | 26 |
| 18 | Fix Skills `version` in serializer | 16 |
| 19 | Fix Gateway `healthyCount` status string | 24 |
| 20 | Wire BudgetSettings to store | 29 |

### P2 — Missing features
| # | Fix | Modules |
|---|-----|---------|
| 21 | Wire Agent Runs tab, Inbox tab, Org chart | 9 |
| 22 | Wire Agent resume action (currently sends wake) | 9 |
| 23 | Wire `fetchTrends()` to `/costs/daily` | 13 |
| 24 | Wire Signals `patterns`/`stats` endpoints | 15 |
| 25 | Add workspace-change re-fetch to Documents | 7 |
| 26 | Add CRUD to Documents store | 7 |
| 27 | Add create UI to Webhooks, Alerts, Gateways, Skills | 19, 20, 24, 16 |
| 28 | Build Config page implementation | 25 |
| 29 | Move GoalDecomposer to background job | 6 |
| 30 | Add DocumentRevision writes on update | 7 |

### P3 — Performance + hardening
| # | Fix | Modules |
|---|-----|---------|
| 31 | Add `sessions.agent_id` and `sessions.status` indexes | 11, 9 |
| 32 | Replace N+1 in Workspace index counts | 27 |
| 33 | Replace N+1 in Schedule run history | 17 |
| 34 | Add `isPaused` gating in Logs SSE handler | 12 |
| 35 | Add GIN index for Memory search | 14 |
| 36 | Add keepalive to Session SSE | 11 |
| 37 | Pre-load workspace ETS in BudgetEnforcer | 13 |
| 38 | Add `ip_address` to AuditEvent | 23 |
| 39 | Fix `total` workspace scoping in Activity, Sessions, Audit | 10, 11, 23 |
| 40 | Add rate limiting on `/auth/login` | Cross-cutting |
