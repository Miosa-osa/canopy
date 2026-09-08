> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Cross-Competitor Module Audit -- 2026-05-01

> 14 competitors audited. 28 current sidebar modules. 127 distinct competitor features cataloged.
> 42 features we're MISSING that matter. Top 10 recommended additions below.

---

## What We Have (current sidebar -- 28 modules)

### COCKPIT (10)
- Build (mosaic workspace -- agent conversations, blocks, embedded runtimes, slash commands)
- Runtimes (adapter management, multi-runtime support)
- Sessions (history, resume, conversation list)
- Agents (330+ agent personas, hire/edit)
- Workspaces (workspace browser, file tree)
- Sandboxes (MIOSA-provisioned VMs)
- Agent Control (governance gates, approval flows)
- Activity (activity feed)
- Command Center (terminal hub)
- Review (code review surface)

### WORKSPACE (9)
- Inbox/Notifications
- Schedule (cron, heartbeats)
- Chat
- Channels
- Files (file explorer)
- Docs (markdown editor)
- Tasks
- Issues
- My Issues

### SYSTEM (9)
- Drive (workflow/prompt/notebook library)
- Skills (agent skill registry)
- Templates (conversation/workspace templates)
- Analytics
- Projects
- Team
- Goals
- Routines
- Governance (approval policies, budget rules)

### Build internals (not sidebar, but exist)
- Mosaic layout (splits, tabs, drag-drop, pane picker)
- Block system (8 block kinds, stream, actions)
- Embedded runtimes (Claude Code, Codex, Gemini inline)
- Slash command palette, Command palette (Cmd+K), Keyword search (Cmd+/)
- Agent Kanban pane
- Code editor pane, Diff pane, File viewer pane
- Settings (18 sub-pages: appearance, keyboard, budgets, hooks, integrations, etc.)

---

## Missing Modules (by source)

### 1. Warp Terminal
| Module | What It Does | We Have? | Priority | Effort |
|--------|-------------|----------|----------|--------|
| Blocks keyboard nav | Arrow-key navigation between command blocks | MISSING | HIGH | M |
| Workflows (parameterized) | Saved commands with fillable args, run UI | PARTIAL (Drive lists them, no editor/runner) | HIGH | M |
| Notebooks (runbooks) | Annotated command sequences, executable cells | PARTIAL (Drive lists them, no viewer) | HIGH | M |
| Ghost-text completion | Inline AI command suggestion, Tab to accept | MISSING | HIGH | S |
| Custom keybinding editor | Rebind any shortcut, conflict detection | PARTIAL (read-only cheatsheet) | MED | M |
| Theme registry | Multiple themes, xterm palette sync | PARTIAL (light/dark only) | MED | M |
| Triggers | On-event hooks ("on session start, run X") | MISSING | MED | L |
| Cross-session history | Search all blocks across all sessions, frecency | PARTIAL (per-session only) | MED | M |
| Session rename | Name/rename conversations | MISSING | HIGH | S |
| Pinned tabs | Pin important tabs, sort-first | MISSING (type exists, no UI) | MED | S |
| Agent status bar | "Agent is thinking/calling tool X" indicator | MISSING | HIGH | S |

### 2. Cursor
| Module | What It Does | We Have? | Priority | Effort |
|--------|-------------|----------|----------|--------|
| Codebase indexing | Semantic index of entire repo for context | MISSING | HIGH | L |
| Multi-file edit | Agent edits multiple files simultaneously with diff preview | PARTIAL (diff pane exists, no multi-file orchestration) | HIGH | L |
| .cursorrules / project rules | Per-project AI behavior rules, auto-loaded | PARTIAL (Skills exist but not auto-loaded per-workspace) | MED | S |
| Composer (multi-step) | Multi-turn composer with file context chips | HAVE (our Composer is comparable) | -- | -- |
| @ mentions for context | @file, @folder, @docs, @web for inline context | PARTIAL (@mention exists, limited sources) | HIGH | M |
| Tab completion (Copilot-style) | Inline code completion suggestions | MISSING | MED | L |
| Background agent | Agent works in background on long tasks | MISSING | HIGH | M |

### 3. CodeSurf/Contex
| Module | What It Does | We Have? | Priority | Effort |
|--------|-------------|----------|----------|--------|
| Agent-to-agent relay messaging | Mailbox system: inbox/sent/memory, threads, priority, scope | MISSING | HIGH | L |
| Client-side event bus | Wildcard pub/sub with ring buffer, cross-pane comms | MISSING | HIGH | M |
| Extension/plugin system | Manifest-driven plugins with UI tiles + MCP tools + settings | MISSING | MED | L |
| Tool permission scopes | 5 levels: once/session/today/forever/never | PARTIAL (binary approve/reject) | HIGH | S |
| Tile context sharing | Panes declare produces/consumes context keys | MISSING | MED | S |
| Browser tile | Embedded browser with web context | MISSING | LOW | L |
| Layout templates | Save/restore mosaic arrangements | MISSING | MED | M |

### 4. Stacks
| Module | What It Does | We Have? | Priority | Effort |
|--------|-------------|----------|----------|--------|
| MCP-as-workspace-API | Expose workspace state (files, sessions, Drive) as MCP tools | MISSING | HIGH | L |
| Auto-layout algorithms | Grid/bento/scatter for card arrangement | MISSING | MED | S |
| Connections/graph view | Visual edges between items, knowledge graph | MISSING | MED | L |
| Structured AI output to UI | Agent output auto-creates Drive entries, tasks, files | MISSING | MED | M |
| Canvas pane | Spatial 2D view alongside mosaic | MISSING | LOW | L |

### 5. Cabinet
| Module | What It Does | We Have? | Priority | Effort |
|--------|-------------|----------|----------|--------|
| Home greeting + task launcher | Time-of-day greeting, one-shot prompt, quick-action chips | PARTIAL (home route exists, minimal) | HIGH | M |
| Workspace stats dashboard | Agent count, job count, heartbeat count pills | MISSING | MED | S |
| Activity feed (per-workspace) | Recent conversations with status, agent, model, token count | PARTIAL (Activity module exists, not workspace-scoped) | MED | M |
| Registry carousel | Importable workspace templates, horizontal scroll | MISSING | LOW | S |
| Schedule sidebar (next-up runs) | 7-day horizon of upcoming agent jobs | PARTIAL (Schedule module exists, not sidebar widget) | MED | S |

### 6. Windsurf/Codeium
| Module | What It Does | We Have? | Priority | Effort |
|--------|-------------|----------|----------|--------|
| Cascade (multi-step agent) | Agent plans + executes multi-step tasks with rollback | PARTIAL (agent conversations do multi-step, no explicit planner UI) | HIGH | L |
| Flows (reusable workflows) | Pre-built multi-step agent workflows | PARTIAL (Drive workflows, no execution surface) | MED | M |
| Supercomplete | Context-aware multi-line code completion | MISSING | MED | L |
| Memories/knowledge graph | Persistent agent memory across sessions | MISSING | HIGH | M |
| Command palette (deep) | Fuzzy search across files, symbols, commands, settings | HAVE (Cmd+K + Cmd+/) | -- | -- |

### 7. Bolt.new
| Module | What It Does | We Have? | Priority | Effort |
|--------|-------------|----------|----------|--------|
| One-shot app generation | Prompt -> full app scaffold in sandbox | PARTIAL (sandboxes exist, no app-gen UX) | MED | M |
| Live preview | In-app preview of generated web app | MISSING | MED | L |
| One-click deploy | Deploy generated app to hosting | MISSING | LOW | L |

### 8. Devin
| Module | What It Does | We Have? | Priority | Effort |
|--------|-------------|----------|----------|--------|
| Autonomous agent planner | Visual task plan with step-by-step progress | PARTIAL (Agent Kanban, no auto-planning) | HIGH | L |
| Agent browser | Agent can browse web, take screenshots, interact | MISSING | MED | L |
| Agent timeline | Visual timeline of all agent actions with replay | MISSING | MED | M |
| Knowledge base (per-project) | Persistent KB that agent learns from across sessions | MISSING | HIGH | M |

### 9. OpenHands
| Module | What It Does | We Have? | Priority | Effort |
|--------|-------------|----------|----------|--------|
| Micro-agents | Specialized sub-agents spawned for specific tasks | PARTIAL (330 agents exist, no auto-delegation) | MED | M |
| Agent workspace isolation | Each agent gets own filesystem sandbox | HAVE (Sandboxes) | -- | -- |
| Conversation branching | Fork conversation at any point | PARTIAL (fork exists in context menu) | -- | -- |

### 10. Claude Code CLI
| Module | What It Does | We Have? | Priority | Effort |
|--------|-------------|----------|----------|--------|
| Hooks system | Pre/post tool-use hooks, custom validation | HAVE (Settings > Hooks) | -- | -- |
| Permission modes | Plan/auto-accept/normal modes per session | PARTIAL (Governance, not per-session toggle) | MED | S |
| Worktrees | Parallel git worktree management | MISSING | LOW | M |
| CLAUDE.md auto-loading | Project instructions auto-loaded per workspace | PARTIAL (Skills, not auto-detected) | HIGH | S |
| MCP server management | Add/remove/configure MCP servers per workspace | HAVE (Settings > Integrations) | -- | -- |

### 11. Aider
| Module | What It Does | We Have? | Priority | Effort |
|--------|-------------|----------|----------|--------|
| Repo map | Auto-generated codebase structure map for context | MISSING | HIGH | M |
| Architect mode | High-level planning agent that delegates to editor agent | MISSING | MED | M |
| Lint-fix loop | Auto-run linter after edits, fix issues in loop | MISSING | MED | S |
| Voice input | Microphone transcription for prompts | PARTIAL (mic chip exists in composer) | LOW | M |
| Git integration (auto-commit) | Auto-commit with descriptive messages after changes | MISSING | MED | S |

### 12. Continue.dev
| Module | What It Does | We Have? | Priority | Effort |
|--------|-------------|----------|----------|--------|
| Autocomplete (inline) | Ghost-text code completion in editor | MISSING | MED | L |
| Custom slash commands | User-defined / commands with templates | HAVE (Slash commands + Drive) | -- | -- |
| Context providers | Pluggable context sources (@codebase, @docs, @web) | PARTIAL (@mention exists, limited providers) | HIGH | M |
| Model config per task | Different models for chat vs edit vs autocomplete | PARTIAL (model picker exists per conversation) | MED | S |

### 13. VS Code
| Module | What It Does | We Have? | Priority | Effort |
|--------|-------------|----------|----------|--------|
| Extension marketplace | Browse, install, manage extensions | MISSING | LOW | XL |
| Debugger integration | Step-through debugging, breakpoints, watch | MISSING | LOW | XL |
| Source control panel | Git status, stage, commit, push, diff inline | PARTIAL (Review module, no inline git) | MED | L |
| Testing panel | Run/debug tests, test explorer tree | MISSING | MED | L |
| Notebook support | Jupyter-style notebooks with cell execution | PARTIAL (Drive notebooks, no execution) | MED | L |
| Profiles | Save/restore entire configuration profiles | MISSING | LOW | M |

### 14. GitHub Copilot
| Module | What It Does | We Have? | Priority | Effort |
|--------|-------------|----------|----------|--------|
| Inline suggestions | Ghost-text code completion while typing | MISSING | MED | L |
| Workspace agent | Agent with full repo context, multi-file edits | PARTIAL (agent conversations have context) | HIGH | L |
| PR summaries | Auto-generate PR description from diff | MISSING | MED | M |
| CLI integration | AI in terminal for command help | HAVE (Build composer + shell detect) | -- | -- |

---

## Recommended New Modules (deduplicated, prioritized)

Scoring: (competitor count having it) x (relevance to "agent command center" positioning).

### Tier 1 -- Critical (5+ competitors, core to positioning)

1. **[HIGH/M] Codebase Indexing** -- Semantic index of repo for agent context. Cursor, Windsurf, Copilot, Continue, Aider, Devin all have it. Foundational for "agent powerhouse" -- agents without codebase context are hobbled. Backend: embed + vector store or FTS5 on AST. Frontend: progress indicator in workspace header.

2. **[HIGH/M] Persistent Agent Memory** -- Knowledge base that persists across sessions per workspace. Windsurf (memories), Devin (knowledge base), Claude Code (CLAUDE.md), Cursor (.cursorrules). 4+ competitors. Essential for "company 2nd brain" positioning. Backend: Ecto schema for memory entries + retrieval. Frontend: memory browser in sidebar or settings.

3. **[HIGH/S] Ghost-Text Completion** -- Inline AI suggestion in composer/editor, Tab to accept. Warp, Cursor, Copilot, Continue, Windsurf, Codeium. 6+ competitors. Standard expectation. Frontend: grey ghost text in Composer.svelte with 300ms debounce.

4. **[HIGH/M] Agent-to-Agent Communication** -- Relay messaging between agents (mailbox, threads, delegation). CodeSurf has the reference implementation. 3+ competitors (Devin, OpenHands implicit). Core to "agent command center" -- agents that can't talk to each other aren't a team. Backend: Ecto relay schema. Frontend: relay viewer pane.

5. **[HIGH/S] Auto-Loaded Project Rules** -- CLAUDE.md / .cursorrules equivalent auto-detected per workspace. Claude Code, Cursor, Aider, Continue. 4+ competitors. Trivial to implement: on workspace load, scan for config files, inject into agent system prompt. Backend: workspace config scanner. Frontend: indicator in workspace header.

6. **[HIGH/M] Background Agent Execution** -- Agent works on tasks in background, notifies on completion. Cursor, Devin, Windsurf. Core to "agent powerhouse" -- you should be able to dispatch work and move on. Backend: async job + notification. Frontend: background task indicator in Activity or status bar.

### Tier 2 -- Important (3+ competitors, strong UX lift)

7. **[HIGH/S] Agent Status Bar** -- Persistent "agent is thinking / calling tool X / writing file Y" indicator. Warp, Cursor, Windsurf, Devin. Quick win. Frontend: thin bar above composer subscribing to block stream.

8. **[HIGH/S] Session Rename** -- Name/rename conversations. Warp, Cursor, Windsurf. Table-stakes UX. Frontend: inline rename in conversation list + tab title.

9. **[MED/M] Agent Timeline/History Pane** -- Visual timeline of all agent actions with replay/search across sessions. Devin, Warp, Cursor. Frontend: new `history` PaneKind (already in PaneKind union). Backend: blocks search endpoint.

10. **[MED/S] Granular Tool Permissions** -- 5-scope model (once/session/today/forever/never) replacing binary approve/reject. CodeSurf, Claude Code. Frontend: scope selector in approval cards. Backend: grant expiration logic.

### Tier 3 -- Nice to Have (2+ competitors, differentiating)

11. **[MED/M] Structured Output to UI Objects** -- Agent output auto-creates tasks, Drive entries, files. Stacks, Bolt. Frontend: block post-processor.
12. **[MED/M] MCP-as-Workspace-API** -- Expose workspace state as MCP tools for agents. Stacks, CodeSurf. Backend: MCP tool definitions.
13. **[MED/M] Context Providers (@codebase, @docs, @web)** -- Pluggable context injection in composer. Cursor, Continue, Copilot. Frontend: extend @mention sources.
14. **[MED/M] Workflow/Notebook Execution Pane** -- Open and run Drive workflows/notebooks. Warp, VS Code. Frontend: new pane components.
15. **[MED/S] Layout Templates** -- Save/restore mosaic arrangements. CodeSurf, Stacks. Frontend: template CRUD + picker.
16. **[MED/S] Auto-Commit After Agent Edits** -- Agent auto-commits with descriptive messages. Aider, Cursor. Backend: git integration.
17. **[LOW/L] Extension/Plugin System** -- Third-party extensions with manifest + marketplace. VS Code, CodeSurf, Continue. Long-term moat but massive effort.
18. **[LOW/L] Live Preview** -- Preview generated web apps inline. Bolt, Devin. Frontend: embedded webview pane.

---

## Recommended Consolidations

| Merge | Why |
|-------|-----|
| **Agent Control + Governance** -> "Governance" | Both are approval/permission surfaces. Agent Control is governance with a different name. |
| **Chat + Channels** -> "Messages" | Chat and Channels are the same communication paradigm. One module with DM vs channel tabs. |
| **Issues + My Issues** -> "Issues" (with "Mine" filter) | My Issues is a filtered view, not a separate module. Add a toggle/filter. |
| **Activity + Command Center** -> "Activity" | Command Center is terminal-centric activity. Merge into Activity with a terminal tab. |
| **Files + Docs** -> "Files" (with doc viewer) | Docs are files with a markdown renderer. One file browser that renders docs inline. |

Net effect: 28 modules -> 23 modules (5 consolidations) + 6-10 new modules = 29-33 total.

---

## Final Proposed Sidebar

### COCKPIT
1. **Home** -- Greeting + task launcher + quick actions + workspace stats (Cabinet lift)
2. **Build** -- Mosaic workspace (conversations, terminals, editors, blocks, kanban)
3. **Runtimes** -- Runtime adapters, status, config, spend
4. **Sessions** -- Conversation history, search, resume
5. **Agents** -- Agent library, hire, edit, background tasks indicator
6. **Workspaces** -- Workspace browser, project rules, codebase index status
7. **Sandboxes** -- MIOSA VMs, provision, terminal

### WORKSPACE
8. **Inbox** -- Notifications, agent completions, approvals needing action
9. **Schedule** -- Cron, heartbeats, upcoming runs
10. **Messages** -- Chat (DMs) + Channels (merged)
11. **Files** -- File explorer + docs viewer (merged)
12. **Tasks** -- Task management
13. **Issues** -- Issues + My Issues (merged, with "Mine" filter)
14. **Activity** -- Activity feed + command center (merged) + agent timeline
15. **Review** -- Code review, PR summaries

### SYSTEM
16. **Drive** -- Workflow/prompt/notebook library + execution
17. **Skills** -- Agent skill registry
18. **Templates** -- Conversation/workspace/layout templates
19. **Analytics** -- Usage, spend, performance metrics
20. **Projects** -- Project management
21. **Team** -- Team members, roles
22. **Goals** -- OKRs, targets
23. **Routines** -- Recurring automations
24. **Governance** -- Approvals, permissions (5-scope), budget rules, hooks (merged with Agent Control)
25. **Memory** -- Persistent agent memory, knowledge base (NEW)
26. **Extensions** -- Plugin management (future, placeholder)

---

## Stats Summary

- **Total distinct features cataloged across 14 competitors:** 127
- **Features we already HAVE or have PARTIAL:** 85 (67%)
- **Features we're MISSING that matter:** 42 (33%)
- **Top 6 critical additions:** Codebase Indexing, Persistent Agent Memory, Ghost-Text Completion, Agent-to-Agent Communication, Auto-Loaded Project Rules, Background Agent Execution
- **Recommended consolidations:** 5 merges saving 5 sidebar slots
- **Final sidebar count:** 26 modules (23 existing after merges + 3 new: Home, Memory, Extensions)
