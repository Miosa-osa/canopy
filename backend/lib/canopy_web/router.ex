defmodule CanopyWeb.Router do
  @moduledoc """
  Phoenix router for Canopy's HTTP API.

  All API routes are versioned under `/api/v1`.
  """

  use CanopyWeb, :router

  pipeline :api do
    plug :accepts, ["json"]

    plug CanopyWeb.Plugs.RateLimiter,
      scale_ms: 60_000,
      limit: Application.compile_env(:canopy, [CanopyWeb.Plugs.RateLimiter, :limit], 100),
      enabled: Application.compile_env(:canopy, [CanopyWeb.Plugs.RateLimiter, :enabled], true)

    plug Corsica,
      origins: Application.compile_env(:canopy, :cors_origins, []),
      allow_credentials: true,
      allow_headers: ["content-type", "authorization", "x-requested-with"],
      max_age: 86_400

    plug OpenApiSpex.Plug.PutApiSpec, module: CanopyWeb.ApiSpec
  end

  scope "/api/v1", CanopyWeb do
    pipe_through :api

    # Health check
    get "/health", HealthController, :index
    get "/health/ready", HealthController, :ready

    # Runtime management
    get "/runtimes", RuntimesController, :index
    post "/runtimes/detect", RuntimesController, :detect
    get "/runtimes/:type", RuntimesController, :show
    post "/runtimes/:type/test", RuntimesController, :test_environment
    get "/runtimes/:type/models", RuntimesController, :models
    put "/runtimes/:type/credentials", RuntimesController, :put_credentials
    get "/runtimes/:type/credentials", RuntimesController, :get_credentials

    # Agent management
    get "/agents", AgentsController, :index
    get "/agents/:slug", AgentsController, :show
    put "/agents/:slug/persona", AgentsController, :update_persona
    post "/agents/:slug/hire", AgentsController, :hire
    delete "/agents/:slug/hire", AgentsController, :fire
    get "/agents/:slug/heartbeats", AgentsController, :heartbeats

    # Session lifecycle + SSE streaming
    get "/sessions", SessionsController, :index
    post "/sessions", SessionsController, :create
    get "/sessions/:id", SessionsController, :show
    delete "/sessions/:id", SessionsController, :delete
    get "/sessions/:id/chain", SessionsController, :chain
    get "/sessions/:id/messages", SessionsController, :messages
    get "/sessions/:id/events", SessionEventsController, :stream

    # MIOSA compute sandboxes
    get "/sandboxes", SandboxesController, :index
    get "/sandboxes/:sandbox_id", SandboxesController, :show
    delete "/sandboxes/:sandbox_id", SandboxesController, :delete

    # Budget enforcement
    get "/budgets", BudgetsController, :index
    post "/budgets", BudgetsController, :create
    get "/budgets/:id", BudgetsController, :show
    put "/budgets/:id", BudgetsController, :update
    delete "/budgets/:id", BudgetsController, :delete
    get "/budgets/:id/spend", BudgetsController, :spend
    post "/budgets/:id/check", BudgetsController, :check_budget

    # Skills
    get "/skills", SkillsController, :index
    get "/skills/:slug", SkillsController, :show
    post "/skills/import", SkillsController, :import

    # Governance
    get "/governance/rules", GovernanceController, :rules_index
    post "/governance/rules", GovernanceController, :rules_create
    put "/governance/rules/:id", GovernanceController, :rules_update
    delete "/governance/rules/:id", GovernanceController, :rules_delete
    get "/governance/approvals", GovernanceController, :approvals_index
    post "/governance/approvals/:id/approve", GovernanceController, :approve
    post "/governance/approvals/:id/reject", GovernanceController, :reject
    get "/governance/audit", GovernanceController, :audit

    # Tool registry
    get "/tools", ToolsController, :index
    get "/tools/:name", ToolsController, :show
    post "/tools/:name/dispatch", ToolsController, :dispatch

    # Workspace management
    get "/workspaces/templates", WorkspacesController, :templates
    get "/workspaces", WorkspacesController, :index
    get "/workspaces/:slug", WorkspacesController, :show
    post "/workspaces", WorkspacesController, :create
    delete "/workspaces/:slug", WorkspacesController, :delete

    # Workspace file operations
    get "/workspaces/:slug/tree", WorkspaceFilesController, :tree
    get "/workspaces/:slug/files", WorkspaceFilesController, :list_dir
    post "/workspaces/:slug/files/move", WorkspaceFilesController, :move
    get "/workspaces/:slug/files/*path", WorkspaceFilesController, :read
    put "/workspaces/:slug/files/*path", WorkspaceFilesController, :write
    delete "/workspaces/:slug/files/*path", WorkspaceFilesController, :delete

    # Tasks — single table
    get "/tasks", TasksController, :index
    post "/tasks", TasksController, :create
    get "/tasks/:id", TasksController, :show
    put "/tasks/:id", TasksController, :update
    patch "/tasks/:id", TasksController, :update
    post "/tasks/:id/assign", TasksController, :assign
    post "/tasks/:id/complete", TasksController, :complete
    post "/tasks/:id/reopen", TasksController, :reopen
    delete "/tasks/:id", TasksController, :delete

    # Dashboard (Command Center)
    get "/dashboard/summary", DashboardController, :summary

    # Docs
    get "/docs/search", DocsController, :search
    get "/docs", DocsController, :index
    post "/docs", DocsController, :create
    post "/docs/:id/publish", DocsController, :publish
    post "/docs/:id/unpublish", DocsController, :unpublish
    post "/docs/:id/archive", DocsController, :archive
    post "/docs/:id/unarchive", DocsController, :unarchive
    get "/docs/:id", DocsController, :show
    put "/docs/:id", DocsController, :update
    delete "/docs/:id", DocsController, :delete

    # Doc Folders
    get "/doc-folders/tree", DocFoldersController, :tree
    get "/doc-folders", DocFoldersController, :index
    post "/doc-folders", DocFoldersController, :create
    patch "/doc-folders/:id", DocFoldersController, :update
    delete "/doc-folders/:id", DocFoldersController, :delete

    # Channels
    get "/channels", ChannelsController, :index
    post "/channels", ChannelsController, :create
    post "/channels/:id/members", ChannelsController, :add_member
    delete "/channels/:id/members/:actor_type/:actor_id", ChannelsController, :remove_member
    get "/channels/:id/messages", ChannelsController, :list_messages
    post "/channels/:id/messages", ChannelsController, :create_message
    patch "/channels/:id/messages/:message_id", ChannelsController, :edit_message
    delete "/channels/:id/messages/:message_id", ChannelsController, :delete_message
    post "/channels/:id/messages/:message_id/reactions", ChannelsController, :add_reaction

    delete "/channels/:id/messages/:message_id/reactions/:emoji",
           ChannelsController,
           :remove_reaction

    post "/channels/:id/messages/:message_id/pin", ChannelsController, :pin_message
    delete "/channels/:id/messages/:message_id/pin", ChannelsController, :unpin_message
    post "/channels/:id/read", ChannelsController, :mark_read
    get "/channels/:id/unread", ChannelsController, :unread_count
    get "/channels/:id", ChannelsController, :show
    patch "/channels/:id", ChannelsController, :update
    delete "/channels/:id", ChannelsController, :delete

    # Notifications
    get "/notifications", NotificationsController, :index
    get "/notifications/unread_count", NotificationsController, :unread_count
    post "/notifications/read_all", NotificationsController, :read_all
    post "/notifications/:id/read", NotificationsController, :mark_read
    delete "/notifications/:id", NotificationsController, :delete

    # Chat threads
    get "/chat/threads", ChatController, :index
    post "/chat/threads", ChatController, :create
    get "/chat/threads/:id/export", ChatController, :export
    post "/chat/threads/:id/continue", ChatController, :continue
    get "/chat/threads/:id", ChatController, :show
    patch "/chat/threads/:id", ChatController, :update
    delete "/chat/threads/:id", ChatController, :delete

    # Files index
    post "/files", FilesController, :upload
    get "/files/search", FilesController, :search
    post "/files/scan", FilesController, :scan
    get "/files/:id/content", FilesController, :content
    get "/files/:id/activity", FilesController, :activity
    get "/files/:id", FilesController, :show
    patch "/files/:id", FilesController, :update
    delete "/files/:id", FilesController, :delete
    get "/files", FilesController, :index
  end

  # OpenAPI spec endpoint
  scope "/api/v1" do
    pipe_through :api
    get "/openapi", OpenApiSpex.Plug.RenderSpec, []
  end

  # LiveDashboard and Swagger UI (development only)
  if Application.compile_env(:canopy, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]
      live_dashboard "/dashboard", metrics: CanopyWeb.Telemetry
    end

    scope "/api/v1" do
      get "/swagger", OpenApiSpex.Plug.SwaggerUI, path: "/api/v1/openapi"
    end
  end
end
