# Canopy v2 — Phase 3 Completion Report

**Date:** 2026-04-18
**Status:** ✅ COMPLETE — backend module surfaces shipped, bloat rolled back
**Scope:** Cross-cutting infrastructure + 6 module backends + ruthless self-audit rollback

---

## 1. Go / No-Go Decision

**GO.** Triple-stack green. 1473 backend tests (+365 net from Phase 2 after deletions), 277 vitest, 11 cargo. 6 module backends live (Tasks/Chat/Docs/Channels/Files/Dashboard/Notifications). MCP control surface expanded (resources + prompts). Governance rule cache + Oban concurrency bump land scaling prep. The overengineering that shipped in-flight was caught, audited, and rolled back in the same phase — net result is the minimum backend surface Roberto needs without speculative infrastructure.

---

## 2. Triple-Stack Verify

| Stack | Command | Result |
|-------|---------|--------|
| Backend compile | `mix compile --warnings-as-errors` | ✅ clean |
| Backend format | `mix format --check-formatted` | ✅ clean |
| Backend tests | `mix test --seed 0` | ✅ **1473 / 0 failures** (18.4s) |
| Backend lint | `mix credo` | 229 cosmetic issues (up from Phase 2's 117; new code landed without running credo) |
| Desktop type-check | `pnpm check` | ✅ **0 errors**, 23 warnings (16 pre-existing Foundation + 7 a11y) |
| Desktop tests | `pnpm test` | ✅ **277 / 277** (450ms) |
| Rust compile + tests | `cargo test` | ✅ **11 / 0** |

---

## 3. What Shipped

### Module backends

| Module | Surface |
|--------|---------|
| **Tasks** | Single `tasks` table with `parent_id` self-ref + `project_slug` string tag. 1 schema, 1 context (~115 LOC), 1 controller, 8 endpoints. Short_id `"T-" <> Nanoid.generate(8, "0123456789")` inline. Assignee = user_id OR agent_slug. |
| **Chat** | `chat_threads` table. Thread chain walked via existing `Session.parent_session_id`. Markdown exporter supports all 11 TranscriptEntry kinds. 7 endpoints. |
| **Docs** | `documents` + `doc_folders` tables. Plaintext extracted inline from ProseMirror JSON for Postgres FTS. NO document_versions, NO optimistic lock, NO body_extractor module. |
| **Channels** | 5 tables (channels/members/messages/reactions/pins). Polymorphic actor (user or agent). Mention parser inlined in context (no separate module). |
| **Files** | `files` + `file_activity` tables. pgvector extension kept (skills uses it) but NO file_embeddings table. ILIKE name search only. Upload + activity log + tag CRUD. |
| **Dashboard** | 3 widgets: `active_agents`, `spend_this_month`, `recent_sessions`. Single `/dashboard/summary` endpoint. NO dashboard_configs table, NO widget registry, NO layout editor. |
| **Notifications** | `notifications` table. 5-function context. `create/1` inlines PubSub broadcast to `user:<id>` topic. NO delivery adapter pattern, NO template registry. |

### Infrastructure

| Piece | Outcome |
|-------|---------|
| **MCP resources + prompts** | `CanopyMCP.ResourceAdapter` + `PromptAdapter`. URIs `canopy://workspace/:slug/files/:path` + `canopy://agent/:slug/persona`. Prompts from hired agents only. +69 tests. |
| **Governance RuleCache** | ETS-backed rule list, GenServer keeper, invalidation on CRUD. `Governance.evaluate/1` now hits cache, not DB. Supervisor-wired. |
| **Oban concurrency bump** | heartbeats 5 → 50 in config. |
| **Phoenix.Presence** | 1-line base module added to supervisor tree. No wrapper helpers. |

### Migrations applied (Phase 3)

```
20260418130300  add_persona_markdown_to_agents       (kept from Phase 2)
20260418140000  create_notifications
20260418205800  create_chat_threads
20260418215900  create_channels_schema
20260418220000  create_docs_schema
20260418225900  create_dashboard_configs             (DELETED — see §4)
20260418230000  create_files_schema
20260418231000  create_tasks
20260418232000  create_tasks_hierarchy               (DELETED — see §4)
20260418210000  create_session_messages_v2_partitioned  (DELETED — see §4)
```

---

## 4. Rollback — What Got Deleted and Why

Mid-phase self-audit caught systemic overengineering patterns. 12 agents were dispatched in parallel for the feature build; cleanup agent #83 then executed a ruthless deletion pass. Tasks hierarchy (#77) landed after #83's tasks deletion step and re-created the bloat, requiring surgical re-delete #84.

### Wrappers around stdlib (deleted)

| Deleted | Replacement |
|---------|-------------|
| `Canopy.Realtime.broadcast_user/workspace/session/channel/chat/doc/task` | Direct `Phoenix.PubSub.broadcast(Canopy.PubSub, "topic:#{id}", msg)` at each call site |
| `Canopy.Presence.Tracker` helper module | Direct `Phoenix.Presence.track/list/untrack` |
| `Canopy.Notifications.Delivery.{InApp,Email,System}` adapter modules (3) | `Notifications.create/1` inlines one PubSub broadcast |
| `Canopy.Notifications.Templates` pattern-matched template registry | Callers build `%{title, body, icon, link_path}` inline |
| `Canopy.Tasks.ShortIdGenerator` module + per-project sequences | Inline `"T-" <> Nanoid.generate(8, "0123456789")` |
| `Canopy.Docs.BodyExtractor` module | Inline private function in `Canopy.Docs` |
| `Canopy.Channels.MentionParser` module | Inline private function in `Canopy.Channels` |
| `Canopy.Files.Search` module | `search_by_name` inline in `Canopy.Files` |
| `Canopy.Dashboard.Widgets` dispatcher + `DefaultLayout` module | 3 inline widget functions on `Canopy.Dashboard` |

### Config systems for one config (deleted)

| Deleted |
|---------|
| `dashboard_configs` table + migration + layout CRUD endpoints — hardcoded default is fine for single-user |
| `task_views` table + controller — query-string filters suffice |
| `chat_threads.metadata` JSONB bag — no defined keys |
| `issue_labels` separate table — `labels :array, :string` on task row |

### Event systems for direct calls (deleted)

| Deleted |
|---------|
| `Canopy.Events` universal event log + types registry + controller + migration + table. Activity feed will compose per-module queries when Command Center UI needs it. |
| `Canopy.Notifications.emit_from_template/3` + template registry |

### Speculative infrastructure (deleted)

| Deleted | Reason |
|---------|--------|
| Auth scaffolding (Guardian, Accounts, User schema, AuthController, 2 plugs, `:authenticated_api` pipeline) | Tauri desktop on localhost — OS process boundary IS the auth. Week 17 deferred. |
| `Canopy.Partitions` module + `EnsureWorker` + `mix canopy.partitions.ensure` + monthly cron | Partitioning cron for a problem 6,700 users away. Migration A also deleted; partitioning is a documented deferral now. |
| `document_versions` table + `restore_version` API + optimistic-lock `expected_version` | No collab yet (Week 18). 409 stale_version errors theoretical. |
| `file_embeddings` table + ivfflat index + `search_semantic` stub | No embedding provider wired. |
| 4-level task hierarchy (Initiatives → Projects → Issues → Sub-issues) + 4 controllers + 13 schema submodules + 23 routes | Single `tasks` table with `parent_id` handles the required shapes. |
| `chat_thread_sessions` junction table | `Session.parent_session_id` already walks the chain. |
| 11 dashboard widgets with graceful-degrade stubs | 3 real widgets compose inline. |

### Files deleted (total)

**36 source files** deleted across the phase: auth (8), events (5), realtime (2), partitions (3), notifications (5), tasks-hierarchy (14 across modules + controllers + tests), chat junction (1), docs versions + extractor (2), channels parser (1), files embeddings + search (2), dashboard widgets (3). Plus 3 migration files rolled back.

---

## 5. Phase 3 Dispatch vs Outcome — Per-Track

| # | Track | Dispatched | Landed | Kept |
|---|-------|------------|--------|------|
| 71 | Auth scaffolding | full build | full build | **DELETED** |
| 72 | Presence + Realtime | full build | partial (rate-limit) | Presence base only; Realtime wrapper DELETED |
| 73 | Notifications | full with templates + 3 delivery adapters | full | 5-function context + table; adapters/templates DELETED |
| 74 | Business events | full build | full build | **DELETED** |
| 75 | MCP resources + prompts | full | full | **KEPT** (audit Tier 1 win) |
| 76 | Scaling prep | RuleCache + Oban + partitioning | full build | RuleCache + Oban kept; Partitions DELETED |
| 77 | Tasks (Multica lift) | 4-table hierarchy | full build (race with #83) | Collapsed to 1 table by #84 |
| 78 | Chat | threads + junction + exporter | full | Junction DELETED; threads + exporter kept |
| 79 | Docs | docs + folders + versions + extractor | full | Versions + extractor DELETED; docs + folders kept |
| 80 | Channels | 5 tables + parser module | partial (rate-limit) | Parser module DELETED, inlined |
| 81 | Files | files + activity + embeddings + search | full | Embeddings + Search module DELETED |
| 82 | Dashboard | 11 widgets + config table + layout editor | full | 3 widgets + summary endpoint; config + registry DELETED |

---

## 6. Critical Incident — Tasks Race Condition

**What happened:** Cleanup agent #83 ran tasks deletion as part of its queue. Track #77 (Tasks build) had not yet completed when #83 finished. #77 then landed afterward, writing the 4-table hierarchy back to disk.

**How caught:** Inventory check on `lib/canopy/tasks/` after #83's completion report. Found 10 module files and 4 controllers — the exact bloat #83 was supposed to have deleted. Reverse-compared against #77's completion report: #77 explicitly reported writing these files.

**Fix:** Dispatched surgical re-delete agent #84 with narrow scope (Tasks only). Landed clean — 1562 → 1473 tests (89 hierarchy tests deleted), zero failures.

**Root cause:** Parallel agent orchestration without explicit sequencing guarantee. Cleanup's deletion pass was computed from a pre-#77 state; #77 wrote files from a pre-#83 state. Classic lost-update.

**Lesson:** Cleanup-style agents need a RE-VERIFY step at the end that re-inventories the files they targeted for deletion. If a target reappears, delete again.

---

## 7. Security + Correctness Side-Effects

- Governance RuleCache bug: Cleanup agent #83 found and fixed — the GenServer had been written but never added to the supervisor tree (rules would not load, ETS operations failed). Now wired correctly.
- Chat transcript ordering bug: `walk_session_chain/1` had a spurious `Enum.reverse/1` that flipped the chronological order. Fixed by #83.
- All Phase 2 Tier 0 findings remain closed (governance wired in Sessions.create, rate limiter with compile_env opts, markdown href allowlist, ghost session fix, HKDF vault, etc.).

---

## 8. Deferrals — Targets Listed

| Item | Target |
|------|--------|
| Auth (multi-user) | Week 17 |
| OAuth (Inbox, Schedule modules) | Week 11–12 |
| Tiptap rich editor + real-time collab | Week 18 |
| session_messages partitioning | When table crosses 10M rows |
| File embeddings + semantic search | When embedding provider is wired |
| Analytics module | Week 15 |
| Governance approval UI | Week 16 |
| Credo 229 cosmetic issues | Week 4 Day 5 sweep |
| Activity feed / event replay surface | Build per-module query when Command Center UI asks for it |
| Tree virtualization for large workspace trees | Week 5+ when UI shows them |

---

## 9. Assumptions

1. Single-user Tauri desktop bound to 127.0.0.1 with no application-layer auth is the correct model for v0.1. Week 17 re-adds auth when multi-user ships.
2. All module backends use `optional :user_id, :binary_id` fields prepared for the auth flip — no retro-active migration needed later.
3. Activity logging is a pull pattern (modules query their own recent rows) not a push pattern (central event bus). Revisit if 3+ modules need cross-module activity feeds at the same time.
4. Notifications are fire-and-forget PubSub broadcasts to a `user:<id>` topic. No delivery receipts, no retry, no email. When the app needs real delivery guarantees, add an Oban worker.

---

## 10. Next

**Phase 4** — Frontend for the landed module backends.

Narrow, anti-bloat scope per-track:
- `/tasks` list + create form (no Kanban lib)
- `/chat` thread list + detail with SSE (reuse existing wiring)
- `/docs` list + folder tree + textarea editor (no Tiptap)
- `/channels` list + message composer (reuse Composer pattern)
- `/files` list + upload (native input, no drag-drop lib)
- `/dashboard` renders 3 widgets from `/dashboard/summary`
- `<NotificationBell>` in +layout with 60s poll

Each frontend track gets an explicit NO-list in its brief: no wrapper components, no config-table-driven layouts, no separate "Registry" sub-modules.

---

## Commit

```
feat: Phase 3 — module backends + ruthless self-audit rollback
```

69 source files created, 36 speculative files deleted, 10 migrations applied (3 rolled back). Net: 1473 tests / 0 failures.
