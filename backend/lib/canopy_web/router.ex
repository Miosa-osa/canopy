defmodule CanopyWeb.Router do
  use CanopyWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug CanopyWeb.Plugs.CORS
  end

  pipeline :authenticated do
    plug CanopyWeb.Plugs.Auth
    plug CanopyWeb.Plugs.WorkspaceAuth
    plug CanopyWeb.Plugs.Audit
  end

  pipeline :streaming do
    plug :accepts, ["event-stream", "json"]
    plug CanopyWeb.Plugs.CORS
  end

  # Health check — no auth
  scope "/api/v1", CanopyWeb do
    pipe_through :api

    get "/health", HealthController, :show
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh
  end

  # Authenticated API routes
  scope "/api/v1", CanopyWeb do
    pipe_through [:api, :authenticated]

    get "/dashboard", DashboardController, :show

    # Workspaces
    resources "/workspaces", WorkspaceController, except: [:new, :edit] do
      post "/activate", WorkspaceController, :activate, as: :activate
      get "/agents", WorkspaceController, :agents, as: :agents
      get "/skills", WorkspaceController, :skills, as: :skills
      get "/config", WorkspaceController, :config, as: :config
    end

    # Agents
    get "/agents/hierarchy", AgentController, :hierarchy
    resources "/agents", AgentController, except: [:new, :edit] do
      post "/wake", AgentController, :wake, as: :wake
      post "/sleep", AgentController, :sleep, as: :sleep
      post "/pause", AgentController, :pause, as: :pause
      post "/resume", AgentController, :resume, as: :resume
      post "/focus", AgentController, :focus, as: :focus
      post "/terminate", AgentController, :terminate, as: :terminate
      get "/runs", AgentController, :runs, as: :runs
      get "/inbox", AgentController, :inbox, as: :inbox
    end

    # Sessions
    resources "/sessions", SessionController, only: [:index, :show, :delete] do
      get "/transcript", SessionController, :transcript, as: :transcript
      post "/message", SessionController, :message, as: :message
      get "/stream", SessionController, :stream, as: :stream
    end

    # Schedules
    get "/schedules/queue", ScheduleController, :queue
    post "/schedules/wake-all", ScheduleController, :wake_all
    post "/schedules/pause-all", ScheduleController, :pause_all
    resources "/schedules", ScheduleController, except: [:new, :edit] do
      post "/trigger", ScheduleController, :trigger, as: :trigger
    end

    # Costs + Budgets
    get "/costs/summary", CostController, :summary
    get "/costs/by-agent", CostController, :by_agent
    get "/costs/by-model", CostController, :by_model
    get "/costs/daily", CostController, :daily
    get "/costs/events", CostController, :events
    get "/budgets", BudgetController, :index
    put "/budgets/:scope_type/:scope_id", BudgetController, :upsert
    get "/budgets/incidents", BudgetController, :incidents
    post "/budgets/incidents/:id/resolve", BudgetController, :resolve

    # Spawn
    post "/spawn", SpawnController, :create
    get "/spawn/active", SpawnController, :active
    delete "/spawn/:id", SpawnController, :kill
    get "/spawn/history", SpawnController, :history

    # Issues
    resources "/issues", IssueController, except: [:new, :edit] do
      post "/assign", IssueController, :assign, as: :assign
      resources "/comments", CommentController, only: [:index, :create]
      post "/checkout", IssueController, :checkout, as: :checkout
      post "/dispatch", IssueController, :dispatch, as: :dispatch
    end

    # Goals
    resources "/goals", GoalController, except: [:new, :edit] do
      get "/ancestry", GoalController, :ancestry, as: :ancestry
      post "/decompose", GoalController, :decompose, as: :decompose
    end

    # Projects
    resources "/projects", ProjectController, except: [:new, :edit] do
      get "/goals", ProjectController, :goals, as: :goals
      get "/workspaces", ProjectController, :workspaces, as: :workspaces
    end

    # Documents
    get "/documents", DocumentController, :index
    get "/document-revisions", DocumentController, :revisions
    get "/documents/*path", DocumentController, :show
    put "/documents/*path", DocumentController, :update
    delete "/documents/*path", DocumentController, :delete
    post "/documents", DocumentController, :create

    # Inbox
    get "/inbox", InboxController, :index
    post "/inbox/read-all", InboxController, :read_all
    post "/inbox/:id/read", InboxController, :read
    post "/inbox/:id/action", InboxController, :perform_action

    # Activity + Logs
    get "/activity", ActivityController, :index

    # Memory
    get "/memory/search", MemoryController, :search
    resources "/memory", MemoryController, except: [:new, :edit]

    # Signals
    post "/signals/classify", SignalController, :classify
    get "/signals/feed", SignalController, :feed
    get "/signals/patterns", SignalController, :patterns
    get "/signals/stats", SignalController, :stats

    # Skills
    post "/skills/bulk-enable", SkillController, :bulk_enable
    post "/skills/bulk-disable", SkillController, :bulk_disable
    get "/skills/categories", SkillController, :categories
    post "/skills/import", SkillController, :import_skill
    resources "/skills", SkillController, only: [:index, :show] do
      post "/toggle", SkillController, :toggle, as: :toggle
      post "/inject", SkillController, :inject, as: :inject
    end

    # Webhooks
    resources "/webhooks", WebhookController, except: [:new, :edit] do
      post "/test", WebhookController, :test, as: :test
      get "/deliveries", WebhookController, :deliveries, as: :deliveries
    end

    # Alerts
    get "/alerts/rules", AlertController, :index_rules
    post "/alerts/rules", AlertController, :create_rule
    get "/alerts/rules/:id", AlertController, :show_rule
    patch "/alerts/rules/:id", AlertController, :update_rule
    delete "/alerts/rules/:id", AlertController, :delete_rule
    post "/alerts/evaluate", AlertController, :evaluate
    get "/alerts/history", AlertController, :history

    # Integrations
    get "/integrations", IntegrationController, :index
    post "/integrations/pull-all", IntegrationController, :pull_all
    post "/integrations/:slug/connect", IntegrationController, :connect
    delete "/integrations/:slug", IntegrationController, :disconnect
    get "/integrations/:slug/status", IntegrationController, :status

    # Admin
    resources "/users", UserController, except: [:new, :edit]
    get "/audit", AuditController, :index

    resources "/gateways", GatewayController, only: [:index, :create, :delete] do
      post "/probe", GatewayController, :probe, as: :probe
    end

    get "/config", ConfigController, :show
    patch "/config", ConfigController, :update
    get "/templates", TemplateController, :index
    post "/templates", TemplateController, :create

    # Secrets
    resources "/secrets", SecretController, except: [:new, :edit] do
      post "/rotate", SecretController, :rotate, as: :rotate
    end

    # Approvals
    resources "/approvals", ApprovalController, except: [:new, :edit] do
      post "/approve", ApprovalController, :approve, as: :approve
      post "/reject", ApprovalController, :reject, as: :reject
      post "/comments", ApprovalController, :comment, as: :comments
    end

    # Organizations
    resources "/organizations", OrganizationController, except: [:new, :edit] do
      get "/members", OrganizationController, :members, as: :members
    end

    # Invitations
    resources "/invitations", InvitationController, only: [:index, :create]
    post "/invitations/:token/accept", InvitationController, :accept

    # Labels
    resources "/labels", LabelController, only: [:index, :create, :delete]

    # Issue Attachments
    get "/issues/:issue_id/attachments", AttachmentController, :index
    post "/issues/:issue_id/attachments", AttachmentController, :create
    delete "/issues/:issue_id/attachments/:id", AttachmentController, :delete

    # Work Products
    get "/issues/:issue_id/work-products", WorkProductController, :index
    post "/work-products", WorkProductController, :create

    # Config Revisions
    get "/config/revisions", ConfigRevisionController, :index
    post "/config/revisions/:id/restore", ConfigRevisionController, :restore

    # Sidebar Badges
    get "/sidebar-badges", SidebarBadgeController, :show

    # Access Control (RBAC)
    get "/access", AccessController, :index
    post "/access/assign", AccessController, :assign
    delete "/access/:id", AccessController, :revoke

    # Execution Workspaces
    resources "/execution-workspaces", ExecutionWorkspaceController, only: [:index, :create, :delete]

    # Plugins
    resources "/plugins", PluginController, except: [:new, :edit] do
      get "/logs", PluginController, :logs, as: :logs
    end
  end

  # SSE streaming endpoints (accept text/event-stream)
  scope "/api/v1", CanopyWeb do
    pipe_through [:streaming, :authenticated]

    get "/activity/stream", ActivityController, :stream
    get "/logs/stream", LogController, :stream
  end

  # Incoming webhook receiver (no JWT — uses webhook secret)
  scope "/api/v1", CanopyWeb do
    pipe_through :api
    post "/hooks/:webhook_id", WebhookController, :receive
  end
end
