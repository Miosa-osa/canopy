defmodule CanopyWeb.Router do
  @moduledoc """
  Phoenix router for Canopy's HTTP API.

  All API routes are versioned under `/api/v1`.
  """

  use CanopyWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])

    plug(CanopyWeb.Plugs.RateLimiter,
      scale_ms: 60_000,
      limit: Application.compile_env(:canopy, [CanopyWeb.Plugs.RateLimiter, :limit], 100),
      enabled: Application.compile_env(:canopy, [CanopyWeb.Plugs.RateLimiter, :enabled], true)
    )

    # CORS moved to CanopyWeb.Endpoint so OPTIONS preflights are handled before
    # routing (router only matches concrete GET/POST/etc. routes, so preflights
    # would return 404 if handled here).

    plug(OpenApiSpex.Plug.PutApiSpec, module: CanopyWeb.ApiSpec)
    plug(CanopyWeb.Plugs.RunIdAudit)
  end

  scope "/api/v1", CanopyWeb do
    pipe_through(:api)

    # Health check
    get("/health", HealthController, :index)
    get("/health/ready", HealthController, :ready)

    # Editor detection
    get("/editors", EditorsController, :index)

    # Runtime management
    get("/runtimes", RuntimesController, :index)
    post("/runtimes/detect", RuntimesController, :detect)
    get("/runtimes/:type", RuntimesController, :show)
    post("/runtimes/:type/test", RuntimesController, :test_environment)
    get("/runtimes/:type/models", RuntimesController, :models)
    put("/runtimes/:type/credentials", RuntimesController, :put_credentials)
    get("/runtimes/:type/credentials", RuntimesController, :get_credentials)

    # Runtime auth — detection status, device-code flows, API-key storage, revocation, test-probe
    get("/runtimes/:type/auth/status", RuntimeAuthController, :auth_status)
    post("/runtimes/:type/auth/start", RuntimeAuthController, :start_flow)
    post("/runtimes/:type/auth/poll", RuntimeAuthController, :poll_flow)
    put("/runtimes/:type/auth/credentials", RuntimeAuthController, :store_credentials)
    delete("/runtimes/:type/auth/credentials", RuntimeAuthController, :revoke_credentials)
    post("/runtimes/:type/auth/test", RuntimeAuthController, :test_credential)

    # Agent management
    post("/agents", AgentsController, :create)
    get("/agents", AgentsController, :index)
    post("/workspaces/:workspace_slug/agents/sync", AgentsController, :sync_workspace)
    get("/agents/:slug", AgentsController, :show)
    put("/agents/:slug/persona", AgentsController, :update_persona)
    post("/agents/:slug/hire", AgentsController, :hire)
    delete("/agents/:slug/hire", AgentsController, :fire)
    get("/agents/:slug/heartbeats", AgentsController, :heartbeats)

    # Agent orchestration tools — agents call tools, humans inspect audit trail
    post("/agents/tools/:tool_name", AgentToolsController, :dispatch)
    get("/agents/:slug/tool-calls", AgentToolsController, :index)

    # Session lifecycle + SSE streaming
    get("/sessions", SessionsController, :index)
    post("/sessions", SessionsController, :create)
    delete("/sessions", SessionsController, :bulk_delete)
    get("/sessions/:id", SessionsController, :show)
    delete("/sessions/:id", SessionsController, :delete)
    get("/sessions/:id/chain", SessionsController, :chain)
    get("/sessions/:id/messages", SessionsController, :messages)
    post("/sessions/:id/messages", SessionsController, :create_message)
    post("/sessions/:id/inject", SessionsController, :inject)
    get("/sessions/:id/events", SessionEventsController, :stream)
    get("/sessions/:id/stats", HeartbeatsController, :stats)
    get("/sessions/:id/scrollback", ScrollbackController, :show)
    post("/sessions/:id/pause", SessionsController, :pause)
    post("/sessions/:id/resume", SessionsController, :resume)
    post("/sessions/:id/stop", SessionsController, :stop)
    get("/sessions/:id/ports", SessionsController, :ports)
    get("/sessions/:id/lifecycle", SessionsController, :lifecycle)
    get("/sessions/:id/worktree", SessionsController, :worktree_status)
    get("/sessions/:id/worktree/diff", SessionsController, :worktree_diff)
    post("/sessions/:id/worktree/commit", SessionsController, :worktree_commit)
    post("/sessions/:id/worktree/stage", SessionsController, :worktree_stage)
    post("/sessions/:id/worktree/discard-hunk", SessionsController, :worktree_discard_hunk)
    post("/sessions/:id/worktree/push", SessionsController, :worktree_push)
    post("/sessions/:id/worktree/merge", SessionsController, :worktree_merge)
    delete("/sessions/:id/worktree", SessionsController, :worktree_cleanup)
    # Legacy route — kept for backwards compat
    post("/sessions/:id/cleanup_worktree", SessionsController, :cleanup_worktree)
    # PR info — public-repo GitHub lookup for session's worktree branch
    get("/sessions/:id/pr-info", SessionsController, :pr_info)

    # Heartbeats + Activity feed
    get("/heartbeats", HeartbeatsController, :index)
    get("/activity", HeartbeatsController, :activity)

    # MIOSA settings
    get("/miosa/health", MiosaController, :health)
    get("/miosa", MiosaController, :show)
    put("/settings/miosa", MiosaController, :update)

    # MIOSA compute sandboxes
    get("/sandboxes", SandboxesController, :index)
    get("/sandboxes/:sandbox_id", SandboxesController, :show)
    delete("/sandboxes/:sandbox_id", SandboxesController, :delete)

    # Budget enforcement
    get("/budgets", BudgetsController, :index)
    post("/budgets", BudgetsController, :create)
    get("/budgets/:id", BudgetsController, :show)
    put("/budgets/:id", BudgetsController, :update)
    delete("/budgets/:id", BudgetsController, :delete)
    get("/budgets/:id/spend", BudgetsController, :spend)
    post("/budgets/:id/check", BudgetsController, :check_budget)

    # Skills — order matters: /skills/import must precede /skills/:slug
    get("/skills", SkillsController, :index)
    post("/skills/import", SkillsController, :import)
    get("/skills/:slug", SkillsController, :show)
    put("/skills/:slug", SkillsController, :update)

    # Agent ↔ Skill assignments
    get("/agents/:slug/skills", AgentSkillsController, :index)
    post("/agents/:slug/skills", AgentSkillsController, :create)
    delete("/agents/:slug/skills/:skill_slug", AgentSkillsController, :delete)

    # Agent template marketplace — order matters: /agents/from-template before /agents/:slug
    get("/agent-templates", AgentTemplatesController, :index)
    get("/agent-templates/:slug", AgentTemplatesController, :show)
    post("/agents/from-template", AgentTemplatesController, :from_template)

    # Governance
    get("/governance/rules", GovernanceController, :rules_index)
    post("/governance/rules", GovernanceController, :rules_create)
    put("/governance/rules/:id", GovernanceController, :rules_update)
    delete("/governance/rules/:id", GovernanceController, :rules_delete)
    get("/governance/approvals", GovernanceController, :approvals_index)
    post("/governance/approvals/:id/approve", GovernanceController, :approve)
    post("/governance/approvals/:id/reject", GovernanceController, :reject)
    get("/governance/audit", GovernanceController, :audit)
    get("/governance/permissions", GovernanceController, :permissions_index)
    post("/governance/permissions", GovernanceController, :permissions_create)
    delete("/governance/permissions/:id", GovernanceController, :permissions_delete)
    post("/governance/permissions/check", GovernanceController, :permissions_check)

    # Tool registry
    get("/tools", ToolsController, :index)
    get("/tools/:name", ToolsController, :show)
    post("/tools/:name/dispatch", ToolsController, :dispatch)

    # Workspace management
    get("/workspaces/templates", WorkspacesController, :templates)
    get("/workspaces", WorkspacesController, :index)
    get("/workspaces/:slug", WorkspacesController, :show)
    patch("/workspaces/:slug", WorkspacesController, :update)
    post("/workspaces", WorkspacesController, :create)
    post("/workspaces/:slug/detect", WorkspacesController, :detect)
    delete("/workspaces/:slug", WorkspacesController, :delete)

    # Workspace-local OptimalEngine (shell bridge — allowlist-guarded)
    get("/workspaces/:slug/engine/health", WorkspaceEngineController, :health)
    get("/workspaces/:slug/engine/commands", WorkspaceEngineController, :commands)
    post("/workspaces/:slug/engine/run", WorkspaceEngineController, :run)

    # Optimal Engine bridge — search, ingest, memory, context
    post("/workspaces/:slug/engine/search", EngineController, :search)
    post("/workspaces/:slug/engine/ingest", EngineController, :ingest)
    get("/workspaces/:slug/engine/l0", EngineController, :l0)
    post("/workspaces/:slug/engine/assemble", EngineController, :assemble)
    get("/workspaces/:slug/engine/diagnostic", EngineController, :engine_health)
    post("/workspaces/:slug/engine/remember", EngineController, :remember)
    get("/workspaces/:slug/engine/recall", EngineController, :recall)

    # Workspace pinned items
    get("/workspaces/:slug/pins", WorkspacePinsController, :index)
    post("/workspaces/:slug/pins", WorkspacePinsController, :create)
    delete("/workspaces/:slug/pins/:type/:ref", WorkspacePinsController, :delete)
    put("/workspaces/:slug/pins/reorder", WorkspacePinsController, :reorder)

    # Workspace init jobs + SSE streaming
    post("/workspaces/:slug/init", WorkspaceInitController, :start)
    get("/workspaces/:slug/init/:job_id", WorkspaceInitController, :show)
    post("/workspaces/:slug/init/:job_id/cancel", WorkspaceInitController, :cancel)
    get("/workspaces/:slug/init/:job_id/stream", WorkspaceInitController, :stream)
    post("/workspaces/:slug/setup", WorkspaceInitController, :run_setup)
    post("/workspaces/:slug/init/detect", WorkspaceInitController, :detect)

    # Workspace file operations
    get("/workspaces/:slug/tree", WorkspaceFilesController, :tree)
    get("/workspaces/:slug/files", WorkspaceFilesController, :list_dir)
    post("/workspaces/:slug/files/move", WorkspaceFilesController, :move)
    get("/workspaces/:slug/files/*path", WorkspaceFilesController, :read)
    put("/workspaces/:slug/files/*path", WorkspaceFilesController, :write)
    delete("/workspaces/:slug/files/*path", WorkspaceFilesController, :delete)

    # Tasks — single table
    get("/tasks", TasksController, :index)
    post("/tasks", TasksController, :create)
    get("/tasks/:id", TasksController, :show)
    patch("/tasks/:id", TasksController, :update)
    post("/tasks/:id/assign", TasksController, :assign)
    post("/tasks/:id/complete", TasksController, :complete)
    post("/tasks/:id/reopen", TasksController, :reopen)
    post("/tasks/:id/dispatch", TasksController, :dispatch)
    post("/tasks/:id/transition", TasksController, :transition)
    delete("/tasks/:id", TasksController, :delete)

    # Agent Kanban — auto-pickup queue + manual claim/release/complete
    get("/agent-kanban/board", AgentKanbanController, :board)
    get("/agent-kanban/idle-agents", AgentKanbanController, :idle_agents)
    post("/agent-kanban/claim", AgentKanbanController, :claim)
    post("/agent-kanban/release/:task_id", AgentKanbanController, :release)
    post("/agent-kanban/complete/:task_id", AgentKanbanController, :complete)

    # Issues — developer unit of work
    get("/issues", IssuesController, :index)
    post("/issues", IssuesController, :create)
    get("/issues/:id", IssuesController, :show)
    patch("/issues/:id", IssuesController, :update)
    post("/issues/:id/assign", IssuesController, :assign)
    post("/issues/:id/complete", IssuesController, :complete)
    post("/issues/:id/reopen", IssuesController, :reopen)
    post("/issues/:id/dispatch", IssuesController, :dispatch)
    post("/issues/:id/transition", IssuesController, :transition)
    post("/issues/:id/checkout", IssuesController, :checkout)
    post("/issues/:id/release", IssuesController, :release)
    delete("/issues/:id", IssuesController, :delete)

    # Projects — containers for Issues, Tasks, Goals
    get("/projects", ProjectsController, :index)
    post("/projects", ProjectsController, :create)
    get("/projects/:slug/summary", ProjectsController, :summary)
    get("/projects/:slug", ProjectsController, :show)
    patch("/projects/:slug", ProjectsController, :update)
    post("/projects/:slug/archive", ProjectsController, :archive)
    post("/projects/:slug/unarchive", ProjectsController, :unarchive)
    delete("/projects/:slug", ProjectsController, :delete)

    # Goals — orchestrator unit of work
    get("/goals", GoalsController, :index)
    post("/goals", GoalsController, :create)
    get("/goals/:id", GoalsController, :show)
    patch("/goals/:id", GoalsController, :update)
    post("/goals/:id/progress", GoalsController, :progress)
    post("/goals/:id/achieve", GoalsController, :achieve)
    post("/goals/:id/cancel", GoalsController, :cancel)
    delete("/goals/:id", GoalsController, :delete)

    # Routines — recurring automations
    get("/routines", RoutinesController, :index)
    post("/routines", RoutinesController, :create)
    get("/routines/:id", RoutinesController, :show)
    patch("/routines/:id", RoutinesController, :update)
    post("/routines/:id/enable", RoutinesController, :enable)
    post("/routines/:id/disable", RoutinesController, :disable)
    post("/routines/:id/fire", RoutinesController, :fire)
    delete("/routines/:id", RoutinesController, :delete)

    # Knowledge Bases (RAG)
    get("/knowledge-bases", KnowledgeController, :index)
    post("/knowledge-bases", KnowledgeController, :create)
    get("/knowledge-bases/:slug/chunks", KnowledgeController, :list_chunks)
    post("/knowledge-bases/:slug/files", KnowledgeController, :add_file)
    post("/knowledge-bases/:slug/search", KnowledgeController, :search)
    get("/knowledge-bases/:slug/assignments", KnowledgeController, :list_assignments)
    post("/knowledge-bases/:slug/assignments", KnowledgeController, :assign)
    delete("/knowledge-bases/:slug/assignments/:agent_slug", KnowledgeController, :unassign)
    post("/knowledge-bases/:slug/rebuild", KnowledgeController, :rebuild)
    get("/knowledge-bases/:slug", KnowledgeController, :show)
    delete("/knowledge-bases/:slug", KnowledgeController, :delete)

    # Dashboard (Command Center)
    get("/dashboard/summary", DashboardController, :summary)

    # Docs
    get("/docs/search", DocsController, :search)
    get("/docs", DocsController, :index)
    post("/docs", DocsController, :create)
    post("/docs/:id/publish", DocsController, :publish)
    post("/docs/:id/unpublish", DocsController, :unpublish)
    post("/docs/:id/archive", DocsController, :archive)
    post("/docs/:id/unarchive", DocsController, :unarchive)
    get("/docs/:id", DocsController, :show)
    put("/docs/:id", DocsController, :update)
    delete("/docs/:id", DocsController, :delete)

    # Doc Folders
    get("/doc-folders/tree", DocFoldersController, :tree)
    get("/doc-folders", DocFoldersController, :index)
    post("/doc-folders", DocFoldersController, :create)
    patch("/doc-folders/:id", DocFoldersController, :update)
    delete("/doc-folders/:id", DocFoldersController, :delete)

    # Channels
    get("/channels", ChannelsController, :index)
    post("/channels", ChannelsController, :create)
    post("/channels/:id/members", ChannelsController, :add_member)
    delete("/channels/:id/members/:actor_type/:actor_id", ChannelsController, :remove_member)
    get("/channels/:id/messages", ChannelsController, :list_messages)
    post("/channels/:id/messages", ChannelsController, :create_message)
    patch("/channels/:id/messages/:message_id", ChannelsController, :edit_message)
    delete("/channels/:id/messages/:message_id", ChannelsController, :delete_message)
    post("/channels/:id/messages/:message_id/reactions", ChannelsController, :add_reaction)

    delete(
      "/channels/:id/messages/:message_id/reactions/:emoji",
      ChannelsController,
      :remove_reaction
    )

    post("/channels/:id/messages/:message_id/pin", ChannelsController, :pin_message)
    delete("/channels/:id/messages/:message_id/pin", ChannelsController, :unpin_message)
    post("/channels/:id/read", ChannelsController, :mark_read)
    get("/channels/:id/unread", ChannelsController, :unread_count)
    get("/channels/:id", ChannelsController, :show)
    patch("/channels/:id", ChannelsController, :update)
    delete("/channels/:id", ChannelsController, :delete)

    # Notifications
    get("/notifications", NotificationsController, :index)
    get("/notifications/unread_count", NotificationsController, :unread_count)
    post("/notifications/read_all", NotificationsController, :read_all)
    post("/notifications/:id/read", NotificationsController, :mark_read)
    delete("/notifications/:id", NotificationsController, :delete)

    # Chat threads
    get("/chat/threads", ChatController, :index)
    post("/chat/threads", ChatController, :create)
    get("/chat/threads/:id/export", ChatController, :export)
    post("/chat/threads/:id/continue", ChatController, :continue)
    get("/chat/threads/:id", ChatController, :show)
    patch("/chat/threads/:id", ChatController, :update)
    delete("/chat/threads/:id", ChatController, :delete)

    # Human-review approval queue
    get("/reviews", ReviewsController, :index)
    get("/reviews/summary", ReviewsController, :summary)
    get("/reviews/:id", ReviewsController, :show)
    post("/reviews", ReviewsController, :create)
    post("/reviews/:id/approve", ReviewsController, :approve)
    post("/reviews/:id/reject", ReviewsController, :reject)
    post("/reviews/:id/request_changes", ReviewsController, :request_changes)
    post("/reviews/:id/resubmit", ReviewsController, :resubmit)

    # Agent lifecycle hooks — observability endpoint (no auth for Week-0 dev)
    post("/hooks/notify", HooksController, :notify)
    post("/hooks/install", HooksController, :install)
    post("/hooks/uninstall", HooksController, :uninstall)
    get("/hooks/status", HooksController, :show)

    # Runs ledger — execution record for agent-originated actions
    get("/runs", RunsController, :index)
    post("/runs", RunsController, :create)
    get("/runs/:id", RunsController, :show)
    patch("/runs/:id", RunsController, :update)
    post("/runs/:id/finish", RunsController, :finish)
    get("/runs/:id/log", RunsController, :log)
    get("/runs/:id/transcript", RunsController, :transcript)

    # Files index
    post("/files", FilesController, :upload)
    get("/files/search", FilesController, :search)
    post("/files/scan", FilesController, :scan)
    get("/files/:id/content", FilesController, :content)
    get("/files/:id/activity", FilesController, :activity)
    get("/files/:id", FilesController, :show)
    patch("/files/:id", FilesController, :update)
    delete("/files/:id", FilesController, :delete)
    get("/files", FilesController, :index)

    # Analytics — telemetry, costs, breadcrumbs, insights, alerts (Iris agent surface)
    get("/analytics/telemetry", AnalyticsController, :telemetry)
    get("/analytics/costs", AnalyticsController, :costs)
    get("/analytics/breadcrumbs/:run_id", AnalyticsController, :breadcrumbs)
    get("/analytics/insights", AnalyticsController, :insights_index)
    post("/analytics/insights", AnalyticsController, :insights_create)
    post("/analytics/insights/:slug/ack", AnalyticsController, :insights_acknowledge)
    get("/analytics/alerts", AnalyticsController, :alerts_index)
    post("/analytics/alerts", AnalyticsController, :alerts_create)

    # Sandboxes (next-gen) — operator surface for Sandbox Operator agent
    get("/sandboxes-ng", SandboxesNgController, :index)
    get("/sandboxes-ng/events", SandboxesNgController, :events)
    get("/sandboxes-ng/events/:sandbox_id", SandboxesNgController, :events_for_sandbox)
    get("/sandboxes-ng/snapshots", SandboxesNgController, :snapshots_index)
    post("/sandboxes-ng/snapshots", SandboxesNgController, :snapshots_create)
    get("/sandboxes-ng/ports", SandboxesNgController, :ports_index)
    post("/sandboxes-ng/ports", SandboxesNgController, :ports_create)
    delete("/sandboxes-ng/ports/:id", SandboxesNgController, :ports_delete)
    get("/sandboxes-ng/alerts", SandboxesNgController, :alerts_index)
    post("/sandboxes-ng/alerts", SandboxesNgController, :alerts_create)

    # Schedule — specs, runs, overlaps, alerts (Scheduling Agent surface)
    get("/schedule/specs", ScheduleController, :specs_index)
    post("/schedule/specs", ScheduleController, :specs_create)
    get("/schedule/specs/:slug", ScheduleController, :specs_show)
    patch("/schedule/specs/:slug", ScheduleController, :specs_update)
    post("/schedule/specs/:slug/pause", ScheduleController, :specs_pause)
    post("/schedule/specs/:slug/unpause", ScheduleController, :specs_unpause)
    delete("/schedule/specs/:slug", ScheduleController, :specs_archive)
    get("/schedule/runs", ScheduleController, :runs_index)
    get("/schedule/runs/aggregate", ScheduleController, :runs_aggregate)
    get("/schedule/overlaps", ScheduleController, :overlaps_index)
    get("/schedule/alerts", ScheduleController, :alerts_index)
    post("/schedule/alerts", ScheduleController, :alerts_create)
    post("/schedule/alerts/:slug/close", ScheduleController, :alerts_close)
    post("/schedule/alerts/:slug/ack", ScheduleController, :alerts_acknowledge)

    # Templates — Forge agent surface (workspace/persona/workflow templates)
    get("/templates", TemplatesController, :index)
    get("/templates/instantiations", TemplatesController, :instantiations)
    get("/templates/:slug", TemplatesController, :show)
    post("/templates", TemplatesController, :create)
    patch("/templates/:slug", TemplatesController, :update)
    post("/templates/:slug/preview", TemplatesController, :preview)
    post("/templates/:slug/instantiate", TemplatesController, :instantiate)
    post("/templates/:slug/publish", TemplatesController, :publish)
    post("/templates/:slug/fork", TemplatesController, :fork)
    get("/templates/:slug/versions", TemplatesController, :versions)

    # Skill Curator — lockfile, versions, verification, sources (Atlas agent surface)
    get("/skill-curator/lockfile", SkillCuratorController, :lockfile_index)
    post("/skill-curator/lockfile", SkillCuratorController, :lockfile_create)

    delete(
      "/skill-curator/lockfile/:workspace_slug/:skill_slug",
      SkillCuratorController,
      :lockfile_delete
    )

    get("/skill-curator/skills/:slug/versions", SkillCuratorController, :versions_index)
    get("/skill-curator/skills/:slug/diff", SkillCuratorController, :versions_diff)
    post("/skill-curator/skills/:slug/verify", SkillCuratorController, :verify)
    delete("/skill-curator/skills/:slug/verify", SkillCuratorController, :unverify)
    get("/skill-curator/unverified", SkillCuratorController, :unverified_index)
    get("/skill-curator/sources", SkillCuratorController, :sources_index)
    post("/skill-curator/sources", SkillCuratorController, :sources_create)
    post("/skill-curator/sources/refresh", SkillCuratorController, :sources_refresh)

    # Runtime Adapter — model info, roles, checkpoints (Runtime Adapter Agent surface)
    get("/runtime-adapter/models", RuntimeAdapterController, :models)
    get("/runtime-adapter/roles", RuntimeAdapterController, :roles_index)
    post("/runtime-adapter/roles", RuntimeAdapterController, :roles_create)
    get("/runtime-adapter/checkpoints", RuntimeAdapterController, :checkpoints_index)
    post("/runtime-adapter/checkpoints", RuntimeAdapterController, :checkpoints_create)

    post(
      "/runtime-adapter/checkpoints/:id/restore",
      RuntimeAdapterController,
      :checkpoints_restore
    )

    get("/runtime-adapter/suggestions", RuntimeAdapterController, :suggestions)
    post("/runtime-adapter/swap", RuntimeAdapterController, :swap)

    # Drive — typed knowledge entries (Vault agent surface)
    # Bare paths /drive/tree, /drive/search, /drive/reorder MUST come before /drive/:id
    get("/drive", DriveController, :index)
    post("/drive", DriveController, :create)
    get("/drive/tree", DriveController, :tree)
    get("/drive/search", DriveController, :search)
    post("/drive/reorder", DriveController, :reorder)
    get("/drive/:id", DriveController, :show)
    patch("/drive/:id", DriveController, :update)
    post("/drive/:id/archive", DriveController, :archive)
    post("/drive/:id/restore", DriveController, :restore)
    post("/drive/:id/move", DriveController, :move)

    # Build — saved layouts, suggestions, defaults (Conductor agent surface)
    get("/build/layouts", BuildController, :list_layouts)
    post("/build/layouts", BuildController, :create_layout)
    get("/build/layouts/:slug", BuildController, :show_layout)
    patch("/build/layouts/:slug", BuildController, :update_layout)
    delete("/build/layouts/:slug", BuildController, :archive_layout)
    post("/build/suggest", BuildController, :suggest_layout)
    get("/build/default", BuildController, :default_layout)
    post("/build/layouts/:slug/set-default", BuildController, :set_default)

    # MCP read views (desktop MCP Tools pane)
    get("/mcp/servers", MCPController, :servers)
    get("/mcp/tool-calls", MCPController, :tool_calls)

    # Block primitive — agentic-terminal navigation unit
    # Order matters: /search must come before /:id
    get("/sessions/:session_id/blocks", BlocksController, :index)
    get("/sessions/:session_id/blocks/search", BlocksController, :search)
    get("/sessions/:session_id/blocks/:id", BlocksController, :show)

    # Build commands — multi-source slash command aggregator (builtin + runtime + drive + template + skill)
    get("/build/commands", BuildController, :commands)

    # Workspace state — per-workspace key/value persistence (Mosaic layout, side rail section, etc.)
    get("/workspaces/:workspace_slug/state", WorkspaceStatesController, :index)
    get("/workspaces/:workspace_slug/state/:key", WorkspaceStatesController, :show)
    put("/workspaces/:workspace_slug/state/:key", WorkspaceStatesController, :put)
    delete("/workspaces/:workspace_slug/state/:key", WorkspaceStatesController, :delete)

    # Workspace search — ripgrep + Elixir fallback
    get("/search", SearchController, :index)

    # Missions + Milestones
    get("/missions", MissionsController, :index)
    post("/missions", MissionsController, :create)
    get("/missions/:id", MissionsController, :show)
    patch("/missions/:id", MissionsController, :update)
    post("/missions/:id/milestones", MissionsController, :add_milestone)
    post("/missions/:id/milestones/:mid/advance", MissionsController, :advance_milestone)

    # Orchestrator — dispatch queue status + manual trigger
    get("/orchestrator/status", MissionsController, :orchestrator_status)
    post("/orchestrator/dispatch", MissionsController, :orchestrator_dispatch)

    # Agent relay — agent-to-agent messaging system
    get("/relay/participants", RelayController, :list_participants)
    post("/relay/participants", RelayController, :register_participant)
    get("/relay/inbox/:agent_slug", RelayController, :inbox)
    post("/relay/messages", RelayController, :send_message)
    post("/relay/messages/:id/read", RelayController, :mark_read)
    get("/relay/threads/:thread_id", RelayController, :list_thread)
    get("/relay/channels", RelayController, :list_channels)
    post("/relay/channels", RelayController, :create_channel)
    post("/relay/channels/:name/join", RelayController, :join_channel)
    post("/relay/channels/:name/leave", RelayController, :leave_channel)
    post("/relay/channels/:name/broadcast", RelayController, :broadcast_channel)
  end

  # OpenAPI spec endpoint
  scope "/api/v1" do
    pipe_through(:api)
    get("/openapi", OpenApiSpex.Plug.RenderSpec, [])
  end

  # LiveDashboard and Swagger UI (development only)
  if Application.compile_env(:canopy, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through([:fetch_session, :protect_from_forgery])
      live_dashboard("/dashboard", metrics: CanopyWeb.Telemetry)
    end

    scope "/api/v1" do
      get("/swagger", OpenApiSpex.Plug.SwaggerUI, path: "/api/v1/openapi")
    end
  end
end
