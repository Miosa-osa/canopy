defmodule CanopyWeb.Router do
  @moduledoc """
  Phoenix router for Canopy's HTTP API.

  All API routes are versioned under `/api/v1`. The OpenAPI spec is served at
  `/api/v1/openapi` (machine-readable JSON) and `/api/v1/docs` (Swagger UI in dev).

  Week 1 additions:
  - `resources "/runtimes"` — list, get, test_environment, get_config_schema
  - `resources "/sessions"` — create, get, cancel, list (with SSE streaming)
  - `resources "/agents"` — list, get, hire, fire
  - `resources "/workspaces"` — list, get, create
  - `resources "/sandboxes"` — list, get, destroy (MIOSA-provisioned VMs)

  Week 3 additions:
  - Workspace CRUD: list, show, create, delete (soft)
  - Workspace templates: GET /workspaces/templates
  - Workspace file tree: GET /workspaces/:slug/tree
  - Workspace file ops: GET/PUT/DELETE /workspaces/:slug/files/*path
  - Workspace move: POST /workspaces/:slug/files/move
  """

  use CanopyWeb, :router

  pipeline :api do
    plug :accepts, ["json"]

    # CORS — origins pulled from app config. See config/dev.exs and config/runtime.exs.
    # Empty list = no CORS headers sent = browser-origin calls blocked. Tauri native
    # packaged app uses ipc:// / tauri://, not CORS. This is for dev browser mode.
    plug Corsica,
      origins: Application.compile_env(:canopy, :cors_origins, []),
      allow_credentials: true,
      allow_headers: ["content-type", "authorization", "x-requested-with"],
      max_age: 86_400

    plug OpenApiSpex.Plug.PutApiSpec, module: CanopyWeb.ApiSpec
  end

  scope "/api/v1", CanopyWeb do
    pipe_through :api

    # Health check — always available, no auth required
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

    # MIOSA compute sandboxes — derived from session sandbox columns
    get "/sandboxes", SandboxesController, :index
    get "/sandboxes/:sandbox_id", SandboxesController, :show
    delete "/sandboxes/:sandbox_id", SandboxesController, :delete

    # Budget enforcement — 3-tier spend control
    get "/budgets", BudgetsController, :index
    post "/budgets", BudgetsController, :create
    get "/budgets/:id", BudgetsController, :show
    put "/budgets/:id", BudgetsController, :update
    delete "/budgets/:id", BudgetsController, :delete
    get "/budgets/:id/spend", BudgetsController, :spend
    post "/budgets/:id/check", BudgetsController, :check_budget

    # Skills — markdown bundles injected into agent execution environments
    get "/skills", SkillsController, :index
    get "/skills/:slug", SkillsController, :show
    post "/skills/import", SkillsController, :import

    # Governance — approval gates, rules, and audit log
    get "/governance/rules", GovernanceController, :rules_index
    post "/governance/rules", GovernanceController, :rules_create
    put "/governance/rules/:id", GovernanceController, :rules_update
    delete "/governance/rules/:id", GovernanceController, :rules_delete
    get "/governance/approvals", GovernanceController, :approvals_index
    post "/governance/approvals/:id/approve", GovernanceController, :approve
    post "/governance/approvals/:id/reject", GovernanceController, :reject
    get "/governance/audit", GovernanceController, :audit

    # Tool registry — Week 2 Track F
    get "/tools", ToolsController, :index
    get "/tools/:name", ToolsController, :show
    post "/tools/:name/dispatch", ToolsController, :dispatch

    # Workspace management — Week 3 (CRUD + soft-delete)
    # NOTE: /workspaces/templates must come before /workspaces/:slug to avoid slug conflict
    get "/workspaces/templates", WorkspacesController, :templates
    get "/workspaces", WorkspacesController, :index
    get "/workspaces/:slug", WorkspacesController, :show
    post "/workspaces", WorkspacesController, :create
    delete "/workspaces/:slug", WorkspacesController, :delete

    # Workspace file operations — Week 3
    get "/workspaces/:slug/tree", WorkspaceFilesController, :tree
    get "/workspaces/:slug/files", WorkspaceFilesController, :list_dir
    post "/workspaces/:slug/files/move", WorkspaceFilesController, :move
    get "/workspaces/:slug/files/*path", WorkspaceFilesController, :read
    put "/workspaces/:slug/files/*path", WorkspaceFilesController, :write
    delete "/workspaces/:slug/files/*path", WorkspaceFilesController, :delete
  end

  # OpenAPI spec endpoint — outside the CanopyWeb scope so the module name is literal
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
      get "/docs", OpenApiSpex.Plug.SwaggerUI, path: "/api/v1/openapi"
    end
  end
end
