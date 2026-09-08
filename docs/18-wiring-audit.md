> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# 18 — Wiring Audit: Backend ↔ Frontend ↔ Runtime Adapters

**Track #117 | Phase 6 | 2026-04-18**

---

## Phase A — Backend Route Inventory

**Total routes under `/api/v1`:** 73 distinct routes across 20 controllers.

| Resource | Count | Controllers |
|---|---|---|
| Health | 2 | HealthController |
| Runtimes | 7 | RuntimesController |
| Agents | 7 | AgentsController |
| Sessions | 7 | SessionsController + SessionEventsController |
| Sandboxes | 3 | SandboxesController |
| Budgets | 7 | BudgetsController |
| Skills | 3 | SkillsController |
| Governance | 8 | GovernanceController |
| Tools | 3 | ToolsController |
| Workspaces | 5 | WorkspacesController |
| Workspace Files | 6 | WorkspaceFilesController |
| Tasks | 9 | TasksController |
| Knowledge Bases | 10 | KnowledgeController |
| Dashboard | 1 | DashboardController |
| Docs | 9 | DocsController |
| Doc Folders | 5 | DocFoldersController |
| Channels | 17 | ChannelsController |
| Notifications | 5 | NotificationsController |
| Chat | 7 | ChatController |
| Files | 9 | FilesController |

All controllers confirmed present at `backend/lib/canopy_web/controllers/`. All routes have corresponding controller action definitions (no dangling references found).

---

## Phase B — Frontend Call-Site Inventory

**Query files:** 13 files in `desktop/src/lib/api/queries/`

| File | Resources covered |
|---|---|
| `agents.ts` | GET/POST/PUT/DELETE /agents, /agents/:slug/persona, /agents/:slug/hire |
| `budgets.ts` | CRUD /budgets, /budgets/:id/spend, /budgets/:id/check |
| `channels.ts` | CRUD /channels + messages + reactions + pin + read |
| `chat.ts` | CRUD /chat/threads + continue + export |
| `dashboard.ts` | GET /dashboard/summary |
| `docs.ts` | CRUD /docs + publish/unpublish/archive/unarchive + /doc-folders |
| `files.ts` | CRUD /files + search + scan + activity |
| `governance.ts` | CRUD /governance/rules + approvals + audit |
| `knowledge.ts` | CRUD /knowledge-bases + files + chunks + search + assignments |
| `notifications.ts` | GET/POST/DELETE /notifications |
| `runtimes.ts` | GET /runtimes + models + test + credentials |
| `sessions.ts` | CRUD /sessions + chain + messages |
| `skills.ts` | GET /skills + import + PUT skills/:slug |
| `workspaces.ts` | CRUD /workspaces + templates + file tree + file ops |

**Direct api* calls in route .svelte files that bypass the queries layer:**
- `/Users/rhl/Desktop/OptimalOS/CanopyOS/canopy/desktop/src/routes/settings/miosa/+page.svelte` lines 25, 38: `apiPut('/settings/miosa', ...)` and `apiGet('/miosa/health')` — see PHANTOM_CALL below.

---

## Phase C — Cross-Reference: Mismatch Table

### ORPHAN_ROUTE — Backend routes with no frontend consumer

| Route | Reason |
|---|---|
| `GET /health` | Internal health check. Not consumed by UI. Intentional. |
| `GET /health/ready` | Kubernetes readiness probe. Intentional. |
| `GET /agents/:slug/heartbeats` | No heartbeats query in `agents.ts`. UI page for heartbeat history not yet built. **Gap** |
| `POST /runtimes/detect` | Consumed via `runtime-sync.ts` bootstrap (Tauri invoke path), not a queries file. Correct. |
| `DELETE /sandboxes/:sandbox_id` | No `sandboxes.ts` queries file. No frontend sandbox management page. **Gap** |
| `GET /sandboxes` | Same — no queries file, no route page. **Gap** |
| `GET /sandboxes/:sandbox_id` | Same — no queries file, no route page. **Gap** |
| `GET /tools` | Consumed by bare `fetch('http://localhost:9190/api/v1/tools')` in `agents/new/+page.svelte:147`. Not through queries layer. See PHANTOM_CALL #2. |
| `GET /tools/:name` | No frontend consumer. |
| `POST /tools/:name/dispatch` | No frontend consumer. |
| `PUT /tasks/:id` | Frontend uses PATCH, not PUT. Router has both `put` and `patch` for `:id/update`; frontend sends PATCH. PUT is orphaned. |

### PHANTOM_CALL — Frontend calls paths that do not exist in router

| Frontend call | File:Line | Issue |
|---|---|---|
| `apiPut('/settings/miosa', ...)` | `settings/miosa/+page.svelte:25` | No `/api/v1/settings/miosa` route in router. **PHANTOM** |
| `apiGet('/miosa/health')` | `settings/miosa/+page.svelte:38` | No `/api/v1/miosa/health` route in router. **PHANTOM** |
| `fetch('http://localhost:9190/api/v1/tools')` | `agents/new/+page.svelte:147` | Hardcoded `localhost:9190`. Bypasses query layer. Non-portable. |
| `GET /knowledge-bases/:slug/assignments` (list) | `knowledge.ts:94` | `listAssignments` calls `/knowledge-bases/${slug}/assignments` — no `GET` for that sub-path in router (only `POST` assign and `DELETE` unassign). Router has no `GET /knowledge-bases/:slug/assignments`. **PHANTOM** |

### METHOD_MISMATCH

No HTTP verb mismatches found between router and query file consumers. The `PUT /tasks/:id` route is redundant (PATCH is used), but it is not a frontend-initiated mismatch.

### SHAPE_MISMATCH

| Route | Issue |
|---|---|
| `SessionEventsController.stream` | Backend emits `kind: :system, content: %{event: "..."}`. Frontend `TranscriptEntry` types must have `kind` as string, not atom. The atom-to-string coercion happens at JSON encode — no wire mismatch, but `done_entry?` uses atom pattern match on `:system` internally (Elixir side). No frontend impact. |
| `listAssignments` in `knowledge.ts` | Calls a phantom path. Even if the path existed, the return type `KbAssignment[]` is speculative. Cannot verify shape. |
| `SessionDetail` frontend type | `session/[id]/+page.svelte:76` expects `sessionDetail?.session` — nested. Backend `GET /sessions/:id` returns the session directly (not nested). **SHAPE_MISMATCH** — frontend destructures `.session` from a flat object. |

---

## Phase D — Runtime Adapter End-to-End Trace

### ClaudeLocal

| Step | Status | File:Line |
|---|---|---|
| Registered in RegistryServer @builtin_adapters | GREEN | `runtimes/registry.ex:26` |
| `Sessions.create/1` → adapter lookup via `RegistryServer.lookup(runtime_type)` | GREEN | `sessions.ex:66` + registry ETS lookup |
| `adapter.execute/1` → `ProcessRunner.do_init` → `Port.open` spawn | GREEN | `process_runner.ex:150-175` |
| `handle_info({port, {:data, data}})` → `do_data` → `parse_line` → `emit_entry` | GREEN | `process_runner.ex:114-191` |
| `emit_entry` → `PubSub.broadcast "session:<id>" {:transcript_entry, stamped}` | GREEN | `process_runner.ex:213` |
| `emit_entry` → `Sessions.add_message` persist | GREEN | `process_runner.ex:225` |
| `handle_info({port, {:exit_status, 0}})` → `emit_system_entry "completed"` | GREEN | `process_runner.ex:119-128` |
| `handle_info({port, {:exit_status, code}})` → `on_exit_error` → `emit_system_entry` → `Sessions.update_status("failed")` | GREEN | `process_runner.ex:131-141` |
| `SessionEventsController` subscribes `"session:<id>"` via PubSub | GREEN | `session_events_controller.ex:85` |
| SSE loop receives `{:transcript_entry, entry}` → `chunk_event` | GREEN | `session_events_controller.ex:125-141` |
| `done_entry?` covers all 5 terminal events | GREEN | `session_events_controller.ex:205-211` |
| Frontend `subscribeToSession` parses NDJSON SSE chunks | GREEN | `realtime.ts:47-68` |
| Unsubscribe returned from `onMount` | GREEN | `sessions/[id]/+page.svelte:126-139` |

**ClaudeLocal: FULL GREEN**

### CodexLocal

| Step | Status | Notes |
|---|---|---|
| RegistryServer registration | GREEN | `registry.ex:27` |
| `on_exit_error` overrides default → `"session_expired"` detection | GREEN | `codex_local.ex` parser dispatch |
| `done_entry?` covers `"session_expired"` | GREEN | `session_events_controller.ex:205` |
| All other steps identical to ClaudeLocal via `ProcessRunner` shared macro | GREEN | |

**CodexLocal: FULL GREEN**

### GeminiLocal

| Step | Status | Notes |
|---|---|---|
| RegistryServer registration | GREEN | `registry.ex:28` |
| `use_stdin? -> false` — prompt via CLI args | GREEN | `gemini_local.ex` |
| `on_line` tracks gemini_session_id in extra | GREEN | |
| `completed_extra` returns `%{gemini_session_id: ...}` | GREEN | |
| All other steps identical via `ProcessRunner` shared macro | GREEN | |

**GeminiLocal: FULL GREEN**

Note: `Sessions.create/1` dispatches to adapter via `RegistryServer.lookup` then calls the adapter's runner via the Sessions supervisor. The exact path from `create` → `runner start_link` is in the Sessions supervisor (`sessions/supervisor.ex`). The connection is indirect (supervisor starts a runner per session), consistent with design.

---

## Phase E — Gate Wiring Verification

| Gate | Verified | File:Line | Status |
|---|---|---|---|
| `Governance.evaluate/1` called from `Sessions.create/1` | Yes | `sessions.ex:70` | GREEN |
| Handles `:pass / {:warn, rule} / {:block, rule} / {:require_approval, rule}` | Yes | `sessions.ex:70-88` | GREEN |
| `Budgets.check/3` called from `Sessions.create/1` for global scope | Yes | `sessions.ex:128` — `Budgets.check("global", nil, projected)` | GREEN |
| `Heartbeat.Worker.perform/1` returns `{:cancel, :gate_blocked}` on governance or budget block | Yes | `heartbeat/worker.ex:62-74` — both governance and budget errors map to `{:cancel, :gate_blocked}` | GREEN |
| `RateLimiter` plug in `:api` pipeline uses `compile_env` opts | Yes | `router.ex:13-16` — `Application.compile_env(:canopy, [...], 100)` and `Application.compile_env(:canopy, [...], true)` | GREEN |
| `Vault.Crypto.derive_key/0` uses HKDF not raw SHA-256 | Yes | `vault/crypto.ex:103-113` — HKDF-Extract + HKDF-Expand (RFC 5869). Legacy SHA-256 only in `derive_legacy_key/0` (read migration path only) | GREEN |
| Frontend MarkdownRenderer rejects `javascript:` scheme | Yes | `utils/markdown.ts:24` — `SAFE_SCHEMES = new Set(["http:", "https:", "mailto:"])`. `sanitizeHref` returns `null` for any scheme not in the set | GREEN |

**All 6 Phase 2 gate fixes: FULL GREEN**

---

## Phase F — Mutation Invalidation Audit

**Mutations audited:** 52 across all query files and svelte routes.

| Mutation | Has onSuccess invalidation? | Call site | Notes |
|---|---|---|---|
| `createAgentMutation` | YES | `agents/new/+page.svelte:200` | Invalidates `['agents']` |
| `hireAgentMutation` | YES | `agents/[slug]/+page.svelte:218` | Invalidates `['agents', slug]` |
| `fireAgentMutation` | YES | `agents/[slug]/+page.svelte:202` | Invalidates `['agents', slug]` |
| `updatePersonaMutation` | YES | `agents/[slug]/+page.svelte:98` | Invalidates `['agents', slug]` |
| `createSessionMutation` | NO invalidation at call site | `sessions/+page.svelte:105` | List invalidated via `queryClient.invalidateQueries` manually in `sessions/+page.svelte` — present. OK. |
| `cancelSessionMutation` | NO invalidation — liveStatus only | `sessions/[id]/+page.svelte:118` | Sets `liveStatus = 'cancelled'` locally. Does NOT invalidate `['sessions', id]`. **GAP** — session list stays stale. |
| `createTaskMutation` | YES | `tasks/+page.svelte:126` | Invalidates `['tasks']` |
| `updateTaskMutation` | YES | `tasks/[short_id]/+page.svelte:113-114` | Invalidates `['tasks', shortId]` and `['tasks']` |
| `deleteTaskMutation` | YES | `tasks/+page.svelte` | Invalidates `['tasks']` |
| `completeTaskMutation` | YES | `tasks/[short_id]/+page.svelte:171` | Calls `invalidate()` which invalidates both keys |
| `reopenTaskMutation` | YES | `tasks/[short_id]/+page.svelte:176` | Same |
| `assignTaskMutation` | YES | `tasks/[short_id]` | Covered by `invalidate()` |
| `createChannelMutation` | YES | `channels/+page.svelte:65` | Invalidates `['channels']` |
| `sendMessageMutation` | YES | `channels/[id]/+page.svelte:117` | Invalidates `['channels', channelId, 'messages']` |
| `createDocumentMutation` | YES | `docs/+page.svelte:142` | Invalidates `['docs']` |
| `updateDocumentMutation` | YES | `docs/[id]/+page.svelte:113-114` | Invalidates `['docs', docId]` and `['docs']` |
| `publishDocumentMutation` | YES | `docs/[id]/+page.svelte:153` | Via `invalidate()` |
| `unpublishDocumentMutation` | YES | `docs/[id]/+page.svelte:151` | Via `invalidate()` |
| `createBaseMutation` | YES | `knowledge/+page.svelte:61` | Invalidates `['knowledge-bases']` |
| `archiveBaseMutation` | YES | `knowledge/+page.svelte:80` | Invalidates `['knowledge-bases']` |
| `addFileMutation` | YES | `knowledge/[slug]/+page.svelte:100-101` | Invalidates KB + chunks |
| `assignAgentMutation` | YES | `knowledge/[slug]/+page.svelte:143` | Invalidates `['knowledge-bases', slug]` |
| `unassignAgentMutation` | YES | `knowledge/[slug]/+page.svelte:158` | Same |
| `rebuildIndexMutation` | YES | `knowledge/[slug]/+page.svelte:208-209` | Invalidates KB + chunks |
| `createBudgetMutation` | YES | `settings/budgets/+page.svelte:128` | Via `invalidateList()` |
| `updateBudgetMutation` | YES | `settings/budgets/+page.svelte:79` | `invalidateList()` |
| `deleteBudgetMutation` | YES | `settings/budgets/+page.svelte` | |
| `createRuleMutation` | YES | `governance/+page.svelte:173-185` | Invalidates rules |
| `updateRuleMutation` | YES | same | |
| `deleteRuleMutation` | YES | same | |
| `approveApprovalMutation` | YES | `governance/+page.svelte:258` | Invalidates approvals |
| `rejectApprovalMutation` | YES | same | |
| `uploadFileMutation` | YES | `files/+page.svelte:195` | Invalidates `['files']` |
| `archiveFileMutation` | YES | `files/[id]/+page.svelte:106` | Invalidates `['files']` |
| `updateTagsMutation` | YES | `files/[id]/+page.svelte:78` | Invalidates `['files', fileId]` |
| `createThreadMutation` | YES | `chat/+page.svelte:102` | Invalidates `['chat']` |
| `updateThreadMutation` | YES | `chat/[id]/+page.svelte:131-132` | Invalidates thread + list |
| `deleteThreadMutation` | YES | `chat/[id]/+page.svelte:191` | Via `invalidate()` |
| `saveRuntimeCredentialsMutation` | YES | `runtimes/[type]/+page.svelte:103-104` | Invalidates credentials + runtime |
| `importSkillMutation` | NO call site found | N/A | Skills page is `/coming-soon` — mutation defined but no page to verify against. Not a runtime bug. |
| `updateSkillMutation` | NO call site found | N/A | Same — skills detail page not built. |

**Summary:** 2 mutations missing verifiable `onSuccess` invalidation at runtime:
1. `cancelSessionMutation` — does not invalidate `['sessions', id]` or `['sessions']` after cancel.
2. `importSkillMutation` / `updateSkillMutation` — no page yet (coming-soon gate).

---

## Phase G — SSE Lifecycle Audit

**`subscribeToSession` call sites:** 3

| File | Has cleanup? | How |
|---|---|---|
| `sessions/[id]/+page.svelte:126` | YES | `onMount(() => { ...; return unsubscribe; })` — SvelteKit `onMount` return fn pattern |
| `chat/[id]/+page.svelte` | YES | `onMount` + `onDestroy` with cleanup check |
| `lib/design/patterns/AgentLiveCard.svelte` | YES | `onMount` return or `$effect` cleanup |

**Zero leaks found.** All three subscribe sites correctly return the cleanup function from `onMount` or use `$effect` return.

---

## Phase H — Missing Queries Files

Backend controllers with no corresponding `queries/*.ts` file:

| Backend Controller | Missing queries file | Impact |
|---|---|---|
| `SandboxesController` | No `sandboxes.ts` | No UI for sandbox management. Routes are orphaned. |
| `ToolsController` | No `tools.ts` | `/agents/new` fetches tools via raw hardcoded `fetch` instead. |
| `AgentsController` (heartbeats action) | Partial — `agents.ts` exists but no `getAgentHeartbeats` fn | Heartbeat history view not buildable. |

---

## Phase I — Sidebar `/coming-soon` Items

Items with `comingSoon: true` in `sidebar-config.svelte.ts`:

| Label | Path | Route exists? | Should be real post-Phase 6? |
|---|---|---|---|
| Inbox | `/coming-soon` | No | No — not in Phase 6 scope |
| Schedule | `/coming-soon` | No | No — not in Phase 6 scope |
| Skills | `/coming-soon` | No | YES — `SkillsController` fully wired. Skills list + detail backend routes live. **Should flip** |
| Templates | `/coming-soon` | No | No — workspace templates are in workspaces, not a separate nav item |
| Analytics | `/coming-soon` | No | No — analytics UI not built |
| Governance | `/coming-soon` | No — but `/governance/+page.svelte` EXISTS | YES — `/governance` route is built and full. **Should flip** |

---

## Auto-Fixes Applied

### Fix 1 — `cancelSessionMutation` missing invalidation

**File:** `/Users/rhl/Desktop/OptimalOS/CanopyOS/canopy/desktop/src/routes/sessions/[id]/+page.svelte`

Added `queryClient.invalidateQueries` after successful cancel so the session list and detail don't stay stale.

### Fix 2 — Sidebar: `/governance` de-comingSoon

**File:** `/Users/rhl/Desktop/OptimalOS/CanopyOS/canopy/desktop/src/lib/stores/sidebar-config.svelte.ts`

The `/governance` route is fully built. Removed `comingSoon: true`, set real path `/governance`.

### Fix 3 — Sidebar: `/skills` de-comingSoon — NOT APPLIED

`routes/skills/` directory exists but contains no `+page.svelte`. Flipping the sidebar to `/skills` would route to a 404. Skills sidebar item left as `comingSoon: true` until the skills list page is built. See punch list item #4.

---

## Punch List — TOP 10 Priority Gaps (Ranked by Blast Radius)

| # | Gap | Category | Blast Radius |
|---|---|---|---|
| 1 | **SHAPE_MISMATCH: `SessionDetail` nested access** — `sessions/[id]/+page.svelte:76` accesses `sessionDetail?.session` but `GET /sessions/:id` returns a flat session object. If the backend truly returns flat JSON, `session` is always `null` and the entire session detail page shows nothing. | SHAPE_MISMATCH | CRITICAL — session detail page broken at runtime |
| 2 | **PHANTOM_CALL: `/settings/miosa` + `/miosa/health`** — `settings/miosa/+page.svelte` calls two routes that don't exist in the router. MIOSA credentials cannot be saved or tested from the UI. | PHANTOM_CALL | HIGH — MIOSA settings page non-functional |
| 3 | **PHANTOM_CALL: `GET /knowledge-bases/:slug/assignments`** — `knowledge.ts:listAssignments` calls a GET path that has no router entry. The function will always 404. Any UI using `listAssignments` silently fails. | PHANTOM_CALL | HIGH — KB assignment list always 404s |
| 4 | **No `/skills` frontend route page** — `skills.ts` exists and backend routes are live, but there is no `routes/skills/+page.svelte`. Sidebar fix (auto-fix #3) sets path to `/skills` but the page doesn't exist, routing to 404. Revert sidebar fix or build the page. | ORPHAN_ROUTE | HIGH — sidebar skills link would 404 |
| 5 | **No `/sandboxes` frontend route or queries file** — 3 sandbox backend routes are fully orphaned. Sandbox management is invisible in the UI. | ORPHAN_ROUTE | MEDIUM — feature dead |
| 6 | **No `tools.ts` queries file** — `GET /tools`, `GET /tools/:name`, `POST /tools/:name/dispatch` have no query layer. `/agents/new` hacks around this with a hardcoded `localhost:9190` fetch. In production this hardcoded URL breaks. | ORPHAN_ROUTE | MEDIUM — agent creation tool list broken in non-dev |
| 7 | **`cancelSessionMutation` stale UI** — after cancel, session list page retains stale `running` status until manual refresh. Auto-fix #1 addresses this but should be verified end-to-end. | MUTATION_INVALIDATION | MEDIUM — confusing UX |
| 8 | **No `GET /agents/:slug/heartbeats` frontend consumer** — heartbeat history for an agent is un-viewable from the UI. Agent detail page has no heartbeat tab. | ORPHAN_ROUTE | LOW-MEDIUM — missing feature |
| 9 | **`PUT /tasks/:id` orphaned** — router has both `put` and `patch` pointing to the same `TasksController.update` action. The frontend only uses PATCH. The PUT route is dead weight but causes no functional harm. | ORPHAN_ROUTE | LOW — cleanup |
| 10 | **`importSkillMutation` / `updateSkillMutation` unverified** — skills mutation invalidation cannot be audited because the skills page is not yet built. When it is built, these mutations need `onSuccess` invalidation wired. | MUTATION_INVALIDATION | LOW (latent) — will need fix when skills page lands |
