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

    # Session lifecycle + SSE streaming
    get "/sessions", SessionsController, :index
    post "/sessions", SessionsController, :create
    get "/sessions/:id", SessionsController, :show
    delete "/sessions/:id", SessionsController, :delete
    get "/sessions/:id/chain", SessionsController, :chain
    get "/sessions/:id/messages", SessionsController, :messages
    get "/sessions/:id/events", SessionEventsController, :stream
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
