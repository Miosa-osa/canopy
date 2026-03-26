import Ecto.Query

alias Canopy.Repo

alias Canopy.Schemas.{
  User,
  Workspace,
  Agent,
  Schedule,
  Project,
  Goal,
  Issue,
  BudgetPolicy,
  Skill,
  ActivityEvent,
  Integration,
  Organization,
  OrganizationMembership,
  Secret,
  Label,
  Approval,
  Plugin,
  Template,
  Division,
  Department,
  Team,
  TeamMembership,
  Workflow,
  WorkflowStep,
  Conversation,
  ConversationMessage,
  Dataset,
  Notification,
  LibraryItem,
  Report
}

# ---------------------------------------------------------------------------
# Demo seed guard: set CANOPY_SEED_DEMO=true to populate the database with
# sample users, workspaces, agents, and other demo data.
#
#   CANOPY_SEED_DEMO=true mix run priv/repo/seeds.exs
#
# Without the env var, this file is a no-op so that production and CI
# environments never accidentally create demo credentials.
# ---------------------------------------------------------------------------

unless System.get_env("CANOPY_SEED_DEMO") == "true" do
  IO.puts("""

  === Canopy Seeds ===

  Skipped: CANOPY_SEED_DEMO is not set to "true".

  To populate demo data, run:

      CANOPY_SEED_DEMO=true mix run priv/repo/seeds.exs

  """)
else

IO.puts("\n=== Canopy Dev Seeds ===\n")

# ---------------------------------------------------------------------------
# SECTION 1: Users
# ---------------------------------------------------------------------------

IO.puts("[1/27] Users...")

Repo.insert(
  User.changeset(%User{}, %{
    name: "Roberto Luna",
    email: "admin@canopy.dev",
    password: "canopy123",
    role: "admin"
  }),
  on_conflict: :nothing,
  conflict_target: :email
)

Repo.insert(
  User.changeset(%User{}, %{
    name: "Dev User",
    email: "dev@canopy.dev",
    password: "canopy123",
    role: "member"
  }),
  on_conflict: :nothing,
  conflict_target: :email
)

admin = Repo.get_by!(User, email: "admin@canopy.dev")
_dev_user = Repo.get_by!(User, email: "dev@canopy.dev")

IO.puts("    admin@canopy.dev (admin), dev@canopy.dev (member)")

# ---------------------------------------------------------------------------
# SECTION 2: Workspace
# ---------------------------------------------------------------------------

IO.puts("[2/27] Workspace...")

Repo.insert(
  Workspace.changeset(%Workspace{}, %{
    name: "OSA Development",
    path: Path.expand("~/.canopy/default"),
    status: "active",
    owner_id: admin.id
  }),
  on_conflict: :nothing
)

workspace = Repo.one!(from w in Workspace, where: w.owner_id == ^admin.id, limit: 1)

IO.puts("    \"OSA Development\" (#{workspace.id})")

# ---------------------------------------------------------------------------
# SECTION 3: Agents
# ---------------------------------------------------------------------------

IO.puts("[3/27] Agents...")

# Orchestrator must be inserted first so subordinates can reference its id.
unless Repo.exists?(from a in Agent, where: a.workspace_id == ^workspace.id and a.slug == "orchestrator") do
  Repo.insert!(
    Agent.changeset(%Agent{}, %{
      slug: "orchestrator",
      name: "Orchestrator",
      role: "orchestrator",
      adapter: "osa",
      model: "claude-opus-4-6",
      status: "idle",
      reports_to: nil,
      workspace_id: workspace.id
    })
  )
end

orchestrator = Repo.get_by!(Agent, workspace_id: workspace.id, slug: "orchestrator")

subordinate_agents = [
  %{
    slug: "researcher",
    name: "Research Agent",
    role: "researcher",
    adapter: "claude-code",
    model: "claude-sonnet-4-6",
    status: "sleeping",
    reports_to: orchestrator.id
  },
  %{
    slug: "developer",
    name: "Developer Agent",
    role: "developer",
    adapter: "claude-code",
    model: "claude-sonnet-4-6",
    status: "sleeping",
    reports_to: orchestrator.id
  },
  %{
    slug: "reviewer",
    name: "Code Reviewer",
    role: "reviewer",
    adapter: "claude-code",
    model: "claude-sonnet-4-6",
    status: "sleeping",
    reports_to: orchestrator.id
  },
  %{
    slug: "devops",
    name: "DevOps Agent",
    role: "devops",
    adapter: "bash",
    model: "bash",
    status: "sleeping",
    reports_to: orchestrator.id
  },
  %{
    slug: "api-monitor",
    name: "API Monitor",
    role: "monitor",
    adapter: "http",
    model: "http",
    status: "sleeping",
    reports_to: orchestrator.id
  }
]

for attrs <- subordinate_agents do
  unless Repo.exists?(from a in Agent, where: a.workspace_id == ^workspace.id and a.slug == ^attrs.slug) do
    Repo.insert!(Agent.changeset(%Agent{}, Map.put(attrs, :workspace_id, workspace.id)))
  end
end

developer = Repo.get_by!(Agent, workspace_id: workspace.id, slug: "developer")
reviewer = Repo.get_by!(Agent, workspace_id: workspace.id, slug: "reviewer")
devops = Repo.get_by!(Agent, workspace_id: workspace.id, slug: "devops")
researcher = Repo.get_by!(Agent, workspace_id: workspace.id, slug: "researcher")

IO.puts("    6 agents: orchestrator (osa), researcher, developer, reviewer (claude-code), devops (bash), api-monitor (http)")

# ---------------------------------------------------------------------------
# SECTION 4: Schedules
# ---------------------------------------------------------------------------

IO.puts("[4/27] Schedules...")

schedules = [
  %{
    name: "Morning standup",
    cron_expression: "0 9 * * 1-5",
    context: "Run daily standup: summarize yesterday's completed issues, flag blockers, list today's priorities.",
    enabled: false,
    workspace_id: workspace.id,
    agent_id: researcher.id
  },
  %{
    name: "Nightly code review",
    cron_expression: "0 2 * * *",
    context: "Review all pull requests opened today. Post review comments and summary report.",
    enabled: false,
    workspace_id: workspace.id,
    agent_id: reviewer.id
  },
  %{
    name: "Infrastructure check",
    cron_expression: "*/30 * * * *",
    context: "Check service health endpoints, disk usage, and container status. Alert on anomalies.",
    enabled: false,
    workspace_id: workspace.id,
    agent_id: devops.id
  }
]

for attrs <- schedules do
  unless Repo.exists?(from s in Schedule, where: s.workspace_id == ^workspace.id and s.name == ^attrs.name) do
    Repo.insert!(Schedule.changeset(%Schedule{}, attrs))
  end
end

IO.puts("    3 schedules (all disabled): morning standup, nightly code review, infrastructure check")

# ---------------------------------------------------------------------------
# SECTION 5: Projects
# ---------------------------------------------------------------------------

IO.puts("[5/27] Projects...")

unless Repo.exists?(from p in Project, where: p.workspace_id == ^workspace.id and p.name == "Canopy Platform") do
  Repo.insert!(%Project{
    name: "Canopy Platform",
    description: "The Canopy Command Center desktop application and backend API.",
    status: "active",
    workspace_id: workspace.id
  })
end

unless Repo.exists?(from p in Project, where: p.workspace_id == ^workspace.id and p.name == "Infrastructure") do
  Repo.insert!(%Project{
    name: "Infrastructure",
    description: "CI/CD pipelines, deployment automation, and monitoring setup.",
    status: "active",
    workspace_id: workspace.id
  })
end

canopy_project = Repo.get_by!(Project, workspace_id: workspace.id, name: "Canopy Platform")
infra_project = Repo.get_by!(Project, workspace_id: workspace.id, name: "Infrastructure")

IO.puts("    2 projects: \"Canopy Platform\", \"Infrastructure\"")

# ---------------------------------------------------------------------------
# SECTION 6: Goals
# ---------------------------------------------------------------------------

IO.puts("[6/27] Goals...")

unless Repo.exists?(from g in Goal, where: g.workspace_id == ^workspace.id and g.title == "Launch MVP") do
  Repo.insert!(%Goal{
    title: "Launch MVP",
    description: "Ship the first production-ready release of Canopy with core agent management features.",
    status: "active",
    workspace_id: workspace.id,
    project_id: canopy_project.id
  })
end

launch_mvp = Repo.get_by!(Goal, workspace_id: workspace.id, title: "Launch MVP")

unless Repo.exists?(from g in Goal, where: g.workspace_id == ^workspace.id and g.title == "Implement Adapter System") do
  Repo.insert!(%Goal{
    title: "Implement Adapter System",
    description: "Build the pluggable adapter layer supporting osa, claude-code, bash, http, and codex adapters.",
    status: "active",
    workspace_id: workspace.id,
    project_id: canopy_project.id,
    parent_id: launch_mvp.id
  })
end

unless Repo.exists?(from g in Goal, where: g.workspace_id == ^workspace.id and g.title == "Setup CI/CD") do
  Repo.insert!(%Goal{
    title: "Setup CI/CD",
    description: "Automated build, test, and deployment pipeline via GitHub Actions.",
    status: "active",
    workspace_id: workspace.id,
    project_id: infra_project.id
  })
end

unless Repo.exists?(from g in Goal, where: g.workspace_id == ^workspace.id and g.title == "Security Audit") do
  Repo.insert!(%Goal{
    title: "Security Audit",
    description: "OWASP Top 10 review, JWT hardening, tenant isolation validation.",
    status: "active",
    workspace_id: workspace.id,
    project_id: infra_project.id
  })
end

IO.puts("    4 goals: Launch MVP, Implement Adapter System (child), Setup CI/CD, Security Audit")

# ---------------------------------------------------------------------------
# SECTION 7: Issues
# ---------------------------------------------------------------------------

IO.puts("[7/27] Issues...")

adapter_goal = Repo.get_by!(Goal, workspace_id: workspace.id, title: "Implement Adapter System")
cicd_goal = Repo.get_by!(Goal, workspace_id: workspace.id, title: "Setup CI/CD")
security_goal = Repo.get_by!(Goal, workspace_id: workspace.id, title: "Security Audit")

issues = [
  %{
    title: "Implement OSA adapter",
    description: "Wire up the OSA adapter to the agent execution engine. Support tool calling and streaming responses.",
    status: "todo",
    priority: "high",
    workspace_id: workspace.id,
    project_id: canopy_project.id,
    goal_id: adapter_goal.id,
    assignee_id: developer.id
  },
  %{
    title: "Write integration tests",
    description: "Integration test suite covering adapter execution, session lifecycle, and budget enforcement.",
    status: "backlog",
    priority: "medium",
    workspace_id: workspace.id,
    project_id: canopy_project.id,
    goal_id: adapter_goal.id
  },
  %{
    title: "Fix SSE connection drops",
    description: "SSE stream disconnects after ~30s under load. Suspected Bandit keepalive timeout misconfiguration.",
    status: "in_progress",
    priority: "critical",
    workspace_id: workspace.id,
    project_id: canopy_project.id,
    goal_id: launch_mvp.id,
    assignee_id: developer.id
  },
  %{
    title: "Add budget enforcement UI",
    description: "Budget policy editor in the Canopy UI: set monthly limits, warning thresholds, and view spend history.",
    status: "todo",
    priority: "medium",
    workspace_id: workspace.id,
    project_id: canopy_project.id,
    goal_id: launch_mvp.id
  },
  %{
    title: "Review auth flow",
    description: "Audit JWT issuance, refresh token rotation, and Guardian plug configuration for production readiness.",
    status: "in_review",
    priority: "high",
    workspace_id: workspace.id,
    project_id: infra_project.id,
    goal_id: security_goal.id,
    assignee_id: reviewer.id
  },
  %{
    title: "Setup monitoring dashboards",
    description: "Grafana dashboards for agent session throughput, budget burn rate, and BEAM VM health metrics.",
    status: "backlog",
    priority: "low",
    workspace_id: workspace.id,
    project_id: infra_project.id,
    goal_id: cicd_goal.id,
    assignee_id: devops.id
  }
]

for attrs <- issues do
  unless Repo.exists?(from i in Issue, where: i.workspace_id == ^workspace.id and i.title == ^attrs.title) do
    Repo.insert!(Issue.changeset(%Issue{}, attrs))
  end
end

IO.puts("    6 issues: 2 todo, 1 in_progress (critical), 1 in_review, 2 backlog")

# ---------------------------------------------------------------------------
# SECTION 8: Budget Policies
# ---------------------------------------------------------------------------

IO.puts("[8/27] Budget policies...")

unless Repo.exists?(from b in BudgetPolicy, where: b.scope_type == "agent" and b.scope_id == ^orchestrator.id) do
  Repo.insert!(
    BudgetPolicy.changeset(%BudgetPolicy{}, %{
      scope_type: "agent",
      scope_id: orchestrator.id,
      monthly_limit_cents: 5_000,
      warning_threshold_pct: 80,
      hard_stop: true
    })
  )
end

unless Repo.exists?(from b in BudgetPolicy, where: b.scope_type == "workspace" and b.scope_id == ^workspace.id) do
  Repo.insert!(
    BudgetPolicy.changeset(%BudgetPolicy{}, %{
      scope_type: "workspace",
      scope_id: workspace.id,
      monthly_limit_cents: 20_000,
      warning_threshold_pct: 70,
      hard_stop: true
    })
  )
end

IO.puts("    2 policies: orchestrator $50/mo (80% warn), workspace $200/mo (70% warn)")

# ---------------------------------------------------------------------------
# SECTION 9: Skills
# ---------------------------------------------------------------------------

IO.puts("[9/27] Skills...")

skills = [
  %{
    name: "Code Generation",
    description: "Generate, refactor, and review source code across multiple languages.",
    category: "Development",
    enabled: true,
    trigger_rules: %{keywords: ["implement", "write", "refactor", "generate code"]},
    workspace_id: workspace.id
  },
  %{
    name: "Web Search",
    description: "Search the web for documentation, research papers, and technical references.",
    category: "Research",
    enabled: true,
    trigger_rules: %{keywords: ["search", "find", "look up", "research"]},
    workspace_id: workspace.id
  },
  %{
    name: "PR Review",
    description: "Review pull requests for correctness, security, and style adherence.",
    category: "Development",
    enabled: true,
    trigger_rules: %{keywords: ["review", "PR", "pull request", "LGTM"]},
    workspace_id: workspace.id
  },
  %{
    name: "Deployment",
    description: "Deploy services to staging and production via automated pipelines.",
    category: "Operations",
    enabled: false,
    trigger_rules: %{keywords: ["deploy", "release", "rollout", "ship"]},
    workspace_id: workspace.id
  }
]

for attrs <- skills do
  unless Repo.exists?(from s in Skill, where: s.workspace_id == ^workspace.id and s.name == ^attrs.name) do
    Repo.insert!(Skill.changeset(%Skill{}, attrs))
  end
end

IO.puts("    4 skills: Code Generation, Web Search, PR Review (enabled), Deployment (disabled)")

# ---------------------------------------------------------------------------
# SECTION 10: Activity Events
# ---------------------------------------------------------------------------

IO.puts("[10/27] Activity events & integrations...")

now = DateTime.utc_now() |> DateTime.truncate(:second)

activity_seeds = [
  %{
    event_type: "agent.hired",
    message: "Agent 'Orchestrator' added to workspace OSA Development.",
    level: "info",
    metadata: %{agent_slug: "orchestrator", adapter: "osa"},
    workspace_id: workspace.id,
    agent_id: orchestrator.id,
    inserted_at: DateTime.add(now, -86_400 * 5, :second)
  },
  %{
    event_type: "agent.hired",
    message: "Agent 'Developer Agent' added to workspace OSA Development.",
    level: "info",
    metadata: %{agent_slug: "developer", adapter: "claude-code"},
    workspace_id: workspace.id,
    agent_id: developer.id,
    inserted_at: DateTime.add(now, -86_400 * 4, :second)
  },
  %{
    event_type: "session.completed",
    message: "Orchestrator completed session: architecture planning for Canopy adapter system.",
    level: "info",
    metadata: %{duration_ms: 42_300, tokens_used: 18_400},
    workspace_id: workspace.id,
    agent_id: orchestrator.id,
    inserted_at: DateTime.add(now, -86_400 * 3, :second)
  },
  %{
    event_type: "session.completed",
    message: "Developer Agent completed session: implemented OSA adapter scaffold.",
    level: "info",
    metadata: %{duration_ms: 91_200, tokens_used: 34_750},
    workspace_id: workspace.id,
    agent_id: developer.id,
    inserted_at: DateTime.add(now, -86_400 * 2, :second)
  },
  %{
    event_type: "budget.warning",
    message: "Workspace budget at 72% of monthly limit ($144 / $200).",
    level: "warn",
    metadata: %{spent_cents: 14_400, limit_cents: 20_000, pct: 72},
    workspace_id: workspace.id,
    inserted_at: DateTime.add(now, -86_400, :second)
  },
  %{
    event_type: "issue.status_changed",
    message: "Issue 'Fix SSE connection drops' moved to in_progress by Developer Agent.",
    level: "info",
    metadata: %{from_status: "todo", to_status: "in_progress", issue_title: "Fix SSE connection drops"},
    workspace_id: workspace.id,
    agent_id: developer.id,
    inserted_at: DateTime.add(now, -3_600 * 6, :second)
  },
  %{
    event_type: "session.started",
    message: "Code Reviewer started review session for auth flow issue.",
    level: "info",
    metadata: %{issue_title: "Review auth flow"},
    workspace_id: workspace.id,
    agent_id: reviewer.id,
    inserted_at: DateTime.add(now, -3_600 * 2, :second)
  },
  %{
    event_type: "agent.error",
    message: "API Monitor failed health check: endpoint /api/health returned 503.",
    level: "error",
    metadata: %{endpoint: "/api/health", status_code: 503, retry_count: 3},
    workspace_id: workspace.id,
    inserted_at: DateTime.add(now, -1_800, :second)
  }
]

for attrs <- activity_seeds do
  Repo.insert!(
    ActivityEvent.changeset(%ActivityEvent{}, Map.drop(attrs, [:inserted_at]))
    |> Ecto.Changeset.put_change(:inserted_at, attrs.inserted_at),
    on_conflict: :nothing
  )
end

# ---------------------------------------------------------------------------
# Integrations
# ---------------------------------------------------------------------------

integrations = [
  %{
    slug: "anthropic",
    name: "Anthropic",
    category: "AI Provider",
    config: %{api_key_set: true, default_model: "claude-opus-4-6"},
    connected: true,
    workspace_id: workspace.id,
    last_synced_at: DateTime.add(now, -3_600, :second)
  },
  %{
    slug: "github",
    name: "GitHub",
    category: "Version Control",
    config: %{},
    connected: false,
    workspace_id: workspace.id
  }
]

for attrs <- integrations do
  unless Repo.exists?(from i in Integration, where: i.workspace_id == ^workspace.id and i.slug == ^attrs.slug) do
    Repo.insert!(
      Integration.changeset(%Integration{}, Map.drop(attrs, [:last_synced_at]))
      |> then(fn cs ->
        case Map.get(attrs, :last_synced_at) do
          nil -> cs
          ts -> Ecto.Changeset.put_change(cs, :last_synced_at, ts)
        end
      end)
    )
  end
end

IO.puts("    8 activity events, 2 integrations (anthropic connected, github disconnected)")

# ---------------------------------------------------------------------------
# SECTION 11: Organizations
# ---------------------------------------------------------------------------

IO.puts("[11/27] Organizations...")

unless Repo.exists?(from o in Organization, where: o.slug == "miosa-labs") do
  Repo.insert!(
    Organization.changeset(%Organization{}, %{
      name: "MIOSA Labs",
      slug: "miosa-labs",
      plan: "enterprise",
      settings: %{billing_email: "billing@miosa.ai", timezone: "America/Los_Angeles"}
    })
  )
end

unless Repo.exists?(from o in Organization, where: o.slug == "acme-corp") do
  Repo.insert!(
    Organization.changeset(%Organization{}, %{
      name: "Acme Corp",
      slug: "acme-corp",
      plan: "pro",
      settings: %{billing_email: "billing@acme.com", timezone: "America/New_York"}
    })
  )
end

miosa_org = Repo.get_by!(Organization, slug: "miosa-labs")
acme_org = Repo.get_by!(Organization, slug: "acme-corp")

IO.puts("    MIOSA Labs (enterprise), Acme Corp (pro)")

# ---------------------------------------------------------------------------
# SECTION 12: Organization Memberships
# ---------------------------------------------------------------------------

IO.puts("[12/27] Organization memberships...")

unless Repo.exists?(from m in OrganizationMembership, where: m.organization_id == ^miosa_org.id and m.user_id == ^admin.id) do
  Repo.insert!(
    OrganizationMembership.changeset(%OrganizationMembership{}, %{
      organization_id: miosa_org.id,
      user_id: admin.id,
      role: "owner"
    })
  )
end

unless Repo.exists?(from m in OrganizationMembership, where: m.organization_id == ^acme_org.id and m.user_id == ^admin.id) do
  Repo.insert!(
    OrganizationMembership.changeset(%OrganizationMembership{}, %{
      organization_id: acme_org.id,
      user_id: admin.id,
      role: "admin"
    })
  )
end

IO.puts("    admin@canopy.dev: owner of MIOSA Labs, admin of Acme Corp")

# ---------------------------------------------------------------------------
# SECTION 13: Secrets
# ---------------------------------------------------------------------------

IO.puts("[13/27] Secrets...")

secrets = [
  %{
    name: "OpenAI API Key",
    key: "OPENAI_API_KEY",
    encrypted_value: "enc_***_redacted",
    provider: "openai",
    workspace_id: workspace.id,
    created_by: admin.id
  },
  %{
    name: "GitHub Token",
    key: "GITHUB_TOKEN",
    encrypted_value: "enc_***_redacted",
    provider: "github",
    workspace_id: workspace.id,
    created_by: admin.id
  },
  %{
    name: "Anthropic Key",
    key: "ANTHROPIC_API_KEY",
    encrypted_value: "enc_***_redacted",
    provider: "anthropic",
    workspace_id: workspace.id,
    created_by: admin.id
  }
]

for attrs <- secrets do
  unless Repo.exists?(from s in Secret, where: s.workspace_id == ^workspace.id and s.key == ^attrs.key) do
    Repo.insert!(Secret.changeset(%Secret{}, attrs))
  end
end

IO.puts("    3 secrets: OPENAI_API_KEY, GITHUB_TOKEN, ANTHROPIC_API_KEY")

# ---------------------------------------------------------------------------
# SECTION 14: Labels
# ---------------------------------------------------------------------------

IO.puts("[14/27] Labels...")

labels = [
  %{name: "bug",           color: "#ef4444", workspace_id: workspace.id},
  %{name: "feature",       color: "#3b82f6", workspace_id: workspace.id},
  %{name: "urgent",        color: "#f97316", workspace_id: workspace.id},
  %{name: "documentation", color: "#22c55e", workspace_id: workspace.id},
  %{name: "enhancement",   color: "#8b5cf6", workspace_id: workspace.id}
]

for attrs <- labels do
  unless Repo.exists?(from l in Label, where: l.workspace_id == ^workspace.id and l.name == ^attrs.name) do
    Repo.insert!(Label.changeset(%Label{}, attrs))
  end
end

IO.puts("    5 labels: bug (red), feature (blue), urgent (orange), documentation (green), enhancement (purple)")

# ---------------------------------------------------------------------------
# SECTION 15: Approvals
# ---------------------------------------------------------------------------

IO.puts("[15/27] Approvals...")

unless Repo.exists?(from a in Approval, where: a.workspace_id == ^workspace.id and a.title == "Deploy v2.1 to production") do
  Repo.insert!(
    Approval.changeset(%Approval{}, %{
      title: "Deploy v2.1 to production",
      description: "Requesting approval to deploy Canopy v2.1 to the production environment. Includes adapter system, budget UI, and SSE fixes.",
      status: "pending",
      context: %{version: "2.1.0", environment: "production", risk: "medium"},
      requested_by: orchestrator.id,
      reviewer_id: admin.id,
      workspace_id: workspace.id,
      expires_at: DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), 86_400 * 3, :second)
    })
  )
end

unless Repo.exists?(from a in Approval, where: a.workspace_id == ^workspace.id and a.title == "Update agent budget limits") do
  Repo.insert!(
    Approval.changeset(%Approval{}, %{
      title: "Update agent budget limits",
      description: "Increase orchestrator monthly budget from $50 to $100 to accommodate higher session volume.",
      status: "approved",
      decision: "approved",
      decision_comment: "Approved. Usage has been consistently hitting the old cap. $100 ceiling is reasonable.",
      context: %{old_limit_cents: 5_000, new_limit_cents: 10_000, scope: "agent"},
      requested_by: orchestrator.id,
      reviewer_id: admin.id,
      workspace_id: workspace.id
    })
  )
end

IO.puts("    2 approvals: \"Deploy v2.1 to production\" (pending), \"Update agent budget limits\" (approved)")

# ---------------------------------------------------------------------------
# SECTION 16: Plugins
# ---------------------------------------------------------------------------

IO.puts("[16/27] Plugins...")

plugins = [
  %{
    slug: "github",
    name: "GitHub",
    version: "1.0.0",
    enabled: true,
    config: %{webhook_secret_set: true, default_branch: "main"},
    workspace_id: workspace.id
  },
  %{
    slug: "slack",
    name: "Slack",
    version: "1.2.0",
    enabled: true,
    config: %{channel: "#canopy-alerts", notify_on: ["session.completed", "budget.warning", "agent.error"]},
    workspace_id: workspace.id
  },
  %{
    slug: "jira",
    name: "Jira",
    version: "0.9.0",
    enabled: false,
    config: %{project_key: "CAN", sync_issues: false},
    workspace_id: workspace.id
  }
]

for attrs <- plugins do
  unless Repo.exists?(from p in Plugin, where: p.workspace_id == ^workspace.id and p.slug == ^attrs.slug) do
    Repo.insert!(Plugin.changeset(%Plugin{}, attrs))
  end
end

IO.puts("    3 plugins: github (v1.0.0, enabled), slack (v1.2.0, enabled), jira (v0.9.0, disabled)")

# ---------------------------------------------------------------------------
# SECTION 17: Templates
# ---------------------------------------------------------------------------

IO.puts("[17/27] Templates...")

unless Repo.exists?(from t in Template, where: t.name == "Full-Stack Development Team") do
  Repo.insert!(
    Template.changeset(%Template{}, %{
      name: "Full-Stack Development Team",
      description: "A complete dev team setup with orchestrator, frontend, backend, reviewer, and devops agents. Includes code generation, PR review, and deployment skills.",
      category: "development",
      is_builtin: true,
      agents: [
        %{name: "orchestrator", role: "orchestrator", adapter: "osa", model: "claude-opus-4-6"},
        %{name: "frontend", role: "developer", adapter: "claude-code", model: "claude-sonnet-4-6"},
        %{name: "backend", role: "developer", adapter: "claude-code", model: "claude-sonnet-4-6"},
        %{name: "reviewer", role: "reviewer", adapter: "claude-code", model: "claude-sonnet-4-6"},
        %{name: "devops", role: "devops", adapter: "bash", model: "bash"}
      ],
      skills: [
        %{name: "code_generation", enabled: true},
        %{name: "pr_review", enabled: true},
        %{name: "deployment", enabled: false},
        %{name: "web_search", enabled: true}
      ],
      schedules: [
        %{name: "nightly_review", cron: "0 2 * * *", agent: "reviewer", enabled: false}
      ]
    })
  )
end

unless Repo.exists?(from t in Template, where: t.name == "Research Assistant") do
  Repo.insert!(
    Template.changeset(%Template{}, %{
      name: "Research Assistant",
      description: "A focused research team: one orchestrator coordinating a researcher and a writer. Optimised for document synthesis, literature review, and report generation.",
      category: "research",
      is_builtin: true,
      agents: [
        %{name: "orchestrator", role: "orchestrator", adapter: "osa", model: "claude-opus-4-6"},
        %{name: "researcher", role: "researcher", adapter: "claude-code", model: "claude-sonnet-4-6"},
        %{name: "writer", role: "writer", adapter: "claude-code", model: "claude-sonnet-4-6"}
      ],
      skills: [
        %{name: "web_search", enabled: true},
        %{name: "code_generation", enabled: false}
      ],
      schedules: []
    })
  )
end

IO.puts("    2 built-in templates: \"Full-Stack Development Team\", \"Research Assistant\"")

# ---------------------------------------------------------------------------
# SECTION 18: Divisions
# ---------------------------------------------------------------------------

IO.puts("[18/27] Divisions...")

divisions_data = [
  %{
    name: "Engineering",
    slug: "engineering",
    description: "Product engineering, platform, and infrastructure.",
    organization_id: miosa_org.id,
    budget_monthly_cents: 50_000,
    budget_enforcement: "warning",
    mission: "Build reliable, scalable software that ships on time.",
    signal: "velocity"
  },
  %{
    name: "Operations",
    slug: "operations",
    description: "Deployment, monitoring, and incident response.",
    organization_id: miosa_org.id,
    budget_monthly_cents: 20_000,
    budget_enforcement: "visibility",
    mission: "Keep systems running and mean time to recovery under 15 minutes.",
    signal: "uptime"
  },
  %{
    name: "Research",
    slug: "research",
    description: "AI research, model evaluation, and knowledge synthesis.",
    organization_id: miosa_org.id,
    budget_monthly_cents: 30_000,
    budget_enforcement: "visibility",
    mission: "Advance the state of the art in autonomous agent capabilities.",
    signal: "insight"
  }
]

for attrs <- divisions_data do
  unless Repo.exists?(
           from d in Division,
             where: d.organization_id == ^miosa_org.id and d.slug == ^attrs.slug
         ) do
    Repo.insert!(Division.changeset(%Division{}, attrs))
  end
end

eng_division = Repo.get_by!(Division, organization_id: miosa_org.id, slug: "engineering")
ops_division = Repo.get_by!(Division, organization_id: miosa_org.id, slug: "operations")
research_division = Repo.get_by!(Division, organization_id: miosa_org.id, slug: "research")

IO.puts("    3 divisions: Engineering, Operations, Research")

# ---------------------------------------------------------------------------
# SECTION 19: Departments
# ---------------------------------------------------------------------------

IO.puts("[19/27] Departments...")

departments_data = [
  %{
    name: "Platform Engineering",
    slug: "platform-engineering",
    description: "Backend API, database, and service infrastructure.",
    division_id: eng_division.id,
    budget_monthly_cents: 25_000,
    budget_enforcement: "warning",
    mission: "Own the platform layer: API, data, and runtime services."
  },
  %{
    name: "Product Engineering",
    slug: "product-engineering",
    description: "Frontend, desktop application, and user experience.",
    division_id: eng_division.id,
    budget_monthly_cents: 20_000,
    budget_enforcement: "visibility",
    mission: "Deliver the desktop experience engineers love to use."
  },
  %{
    name: "Site Reliability",
    slug: "site-reliability",
    description: "Uptime, alerting, and deployment automation.",
    division_id: ops_division.id,
    budget_monthly_cents: 15_000,
    budget_enforcement: "visibility",
    mission: "Automate toil, own reliability metrics, drive SLOs."
  },
  %{
    name: "AI Research",
    slug: "ai-research",
    description: "Model evaluation, agent benchmarking, and capability research.",
    division_id: research_division.id,
    budget_monthly_cents: 25_000,
    budget_enforcement: "warning",
    mission: "Evaluate, benchmark, and improve agent performance."
  },
  %{
    name: "Knowledge Engineering",
    slug: "knowledge-engineering",
    description: "Document synthesis, knowledge graphs, and memory systems.",
    division_id: research_division.id,
    budget_monthly_cents: 15_000,
    budget_enforcement: "visibility",
    mission: "Build systems that let agents learn from past sessions."
  }
]

for attrs <- departments_data do
  unless Repo.exists?(
           from d in Department, where: d.division_id == ^attrs.division_id and d.slug == ^attrs.slug
         ) do
    Repo.insert!(Department.changeset(%Department{}, attrs))
  end
end

platform_dept =
  Repo.get_by!(Department, division_id: eng_division.id, slug: "platform-engineering")

product_dept =
  Repo.get_by!(Department, division_id: eng_division.id, slug: "product-engineering")

sre_dept =
  Repo.get_by!(Department, division_id: ops_division.id, slug: "site-reliability")

IO.puts("    5 departments across Engineering, Operations, Research divisions")

# ---------------------------------------------------------------------------
# SECTION 20: Teams
# ---------------------------------------------------------------------------

IO.puts("[20/27] Teams...")

teams_data = [
  %{
    name: "API Team",
    slug: "api-team",
    description: "Owns the Phoenix REST API and Ecto schemas.",
    department_id: platform_dept.id,
    budget_monthly_cents: 10_000,
    mission: "Ship correct, fast, well-documented API endpoints.",
    manager_agent_id: orchestrator.id
  },
  %{
    name: "Data Team",
    slug: "data-team",
    description: "Migrations, seed data, and query performance.",
    department_id: platform_dept.id,
    budget_monthly_cents: 8_000,
    mission: "Own the data layer: schemas, indexes, and integrity.",
    manager_agent_id: developer.id
  },
  %{
    name: "UI Team",
    slug: "ui-team",
    description: "SvelteKit components, stores, and desktop UX.",
    department_id: product_dept.id,
    budget_monthly_cents: 10_000,
    mission: "Build consistent, accessible, fast UI components.",
    manager_agent_id: reviewer.id
  },
  %{
    name: "Infrastructure Team",
    slug: "infra-team",
    description: "Docker, CI/CD, and deployment pipelines.",
    department_id: sre_dept.id,
    budget_monthly_cents: 8_000,
    mission: "Automate build, test, and deploy pipelines end-to-end.",
    manager_agent_id: devops.id
  },
  %{
    name: "Research Team",
    slug: "research-team",
    description: "Agent evaluation, benchmarking, and synthesis.",
    department_id:
      Repo.get_by!(Department,
        division_id: research_division.id,
        slug: "ai-research"
      ).id,
    budget_monthly_cents: 15_000,
    mission: "Measure and improve agent capability and efficiency.",
    manager_agent_id: researcher.id
  },
  %{
    name: "Monitor Team",
    slug: "monitor-team",
    description: "Alerting, health checks, and SLO tracking.",
    department_id: sre_dept.id,
    budget_monthly_cents: 5_000,
    mission: "Alert before customers notice problems."
  }
]

for attrs <- teams_data do
  unless Repo.exists?(
           from t in Team,
             where: t.department_id == ^attrs.department_id and t.slug == ^attrs.slug
         ) do
    Repo.insert!(Team.changeset(%Team{}, attrs))
  end
end

api_team = Repo.get_by!(Team, department_id: platform_dept.id, slug: "api-team")
data_team = Repo.get_by!(Team, department_id: platform_dept.id, slug: "data-team")
ui_team = Repo.get_by!(Team, department_id: product_dept.id, slug: "ui-team")
infra_team = Repo.get_by!(Team, department_id: sre_dept.id, slug: "infra-team")

research_ai_dept =
  Repo.get_by!(Department, division_id: research_division.id, slug: "ai-research")

research_team = Repo.get_by!(Team, department_id: research_ai_dept.id, slug: "research-team")

IO.puts("    6 teams: api-team, data-team, ui-team, infra-team, research-team, monitor-team")

# ---------------------------------------------------------------------------
# SECTION 21: Team Memberships
# ---------------------------------------------------------------------------

IO.puts("[21/27] Team memberships...")

# Each agent can only belong to ONE team (unique index on agent_id).
memberships_data = [
  %{team_id: api_team.id, agent_id: orchestrator.id, role: "manager"},
  %{team_id: data_team.id, agent_id: developer.id, role: "manager"},
  %{team_id: ui_team.id, agent_id: reviewer.id, role: "manager"},
  %{team_id: infra_team.id, agent_id: devops.id, role: "manager"},
  %{team_id: research_team.id, agent_id: researcher.id, role: "manager"},
  %{
    team_id: api_team.id,
    agent_id: Repo.get_by!(Agent, workspace_id: workspace.id, slug: "api-monitor").id,
    role: "member"
  }
]

for attrs <- memberships_data do
  unless Repo.exists?(from m in TeamMembership, where: m.agent_id == ^attrs.agent_id) do
    Repo.insert!(TeamMembership.changeset(%TeamMembership{}, attrs))
  end
end

IO.puts("    6 memberships: one per seeded agent")

# ---------------------------------------------------------------------------
# SECTION 22: Workflows
# ---------------------------------------------------------------------------

IO.puts("[22/27] Workflows...")

unless Repo.exists?(
         from w in Workflow,
           where: w.workspace_id == ^workspace.id and w.slug == "daily-standup"
       ) do
  Repo.insert!(
    Workflow.changeset(%Workflow{}, %{
      name: "Daily Standup",
      slug: "daily-standup",
      description:
        "Each morning: summarise completed issues, surface blockers, post to activity feed.",
      workspace_id: workspace.id,
      status: "active",
      trigger_type: "schedule",
      trigger_config: %{cron: "0 9 * * 1-5", timezone: "UTC"},
      created_by: "admin@canopy.dev",
      version: 1
    })
  )
end

standup_workflow =
  Repo.get_by!(Workflow, workspace_id: workspace.id, slug: "daily-standup")

unless Repo.exists?(
         from s in WorkflowStep,
           where: s.workflow_id == ^standup_workflow.id and s.position == 1
       ) do
  Repo.insert!(
    WorkflowStep.changeset(%WorkflowStep{}, %{
      workflow_id: standup_workflow.id,
      agent_id: researcher.id,
      name: "Gather completed issues",
      step_type: "agent_task",
      position: 1,
      config: %{
        prompt: "List all issues completed since yesterday. Include title, status, and assignee."
      },
      timeout_seconds: 120
    })
  )
end

unless Repo.exists?(
         from s in WorkflowStep,
           where: s.workflow_id == ^standup_workflow.id and s.position == 2
       ) do
  Repo.insert!(
    WorkflowStep.changeset(%WorkflowStep{}, %{
      workflow_id: standup_workflow.id,
      agent_id: orchestrator.id,
      name: "Post standup summary",
      step_type: "agent_task",
      position: 2,
      config: %{
        prompt:
          "Format and post the standup summary to the activity feed. Flag any blockers."
      },
      timeout_seconds: 60
    })
  )
end

unless Repo.exists?(
         from w in Workflow,
           where: w.workspace_id == ^workspace.id and w.slug == "security-scan"
       ) do
  Repo.insert!(
    Workflow.changeset(%Workflow{}, %{
      name: "Security Scan",
      slug: "security-scan",
      description: "Weekly OWASP Top 10 review of open PRs and dependency updates.",
      workspace_id: workspace.id,
      status: "active",
      trigger_type: "schedule",
      trigger_config: %{cron: "0 2 * * 1", timezone: "UTC"},
      created_by: "admin@canopy.dev",
      version: 1
    })
  )
end

security_workflow =
  Repo.get_by!(Workflow, workspace_id: workspace.id, slug: "security-scan")

unless Repo.exists?(
         from s in WorkflowStep,
           where: s.workflow_id == ^security_workflow.id and s.position == 1
       ) do
  Repo.insert!(
    WorkflowStep.changeset(%WorkflowStep{}, %{
      workflow_id: security_workflow.id,
      agent_id: reviewer.id,
      name: "Run security audit",
      step_type: "agent_task",
      position: 1,
      config: %{
        prompt: "Audit open PRs for OWASP Top 10 issues. Report findings."
      },
      timeout_seconds: 600,
      retry_count: 1,
      on_failure: "skip"
    })
  )
end

IO.puts("    2 workflows (daily-standup, security-scan) with 3 steps total")

# ---------------------------------------------------------------------------
# SECTION 23: Conversations
# ---------------------------------------------------------------------------

IO.puts("[23/27] Conversations...")

unless Repo.exists?(
         from c in Conversation,
           where:
             c.workspace_id == ^workspace.id and
               c.agent_id == ^orchestrator.id and
               c.title == "Architecture planning session"
       ) do
  Repo.insert!(
    Conversation.changeset(%Conversation{}, %{
      title: "Architecture planning session",
      agent_id: orchestrator.id,
      workspace_id: workspace.id,
      user_id: admin.id,
      status: "active",
      message_count: 3,
      metadata: %{topic: "adapter_system"}
    })
  )
end

unless Repo.exists?(
         from c in Conversation,
           where:
             c.workspace_id == ^workspace.id and
               c.agent_id == ^developer.id and
               c.title == "OSA adapter implementation"
       ) do
  Repo.insert!(
    Conversation.changeset(%Conversation{}, %{
      title: "OSA adapter implementation",
      agent_id: developer.id,
      workspace_id: workspace.id,
      user_id: admin.id,
      status: "archived",
      message_count: 12,
      metadata: %{topic: "adapter_implementation"}
    })
  )
end

IO.puts("    2 conversations (architecture planning active, OSA implementation archived)")

# Seed messages for each conversation so the messages table is not empty.
planning_conv =
  Repo.one!(
    from c in Conversation,
      where:
        c.workspace_id == ^workspace.id and
          c.title == "Architecture planning session"
  )

impl_conv =
  Repo.one!(
    from c in Conversation,
      where:
        c.workspace_id == ^workspace.id and
          c.title == "OSA adapter implementation"
  )

now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

planning_messages = [
  %{
    conversation_id: planning_conv.id,
    role: "user",
    content: "What adapter pattern should we use for the multi-provider integration?",
    content_type: "text",
    inserted_at: now,
    updated_at: now
  },
  %{
    conversation_id: planning_conv.id,
    role: "agent",
    content:
      "I recommend a strategy pattern with a common AdapterBehaviour. Each provider implements connect/2, execute/2, and disconnect/1. This keeps the dispatch layer provider-agnostic.",
    content_type: "text",
    inserted_at: now,
    updated_at: now
  },
  %{
    conversation_id: planning_conv.id,
    role: "user",
    content: "Good — draft the behaviour module and one concrete adapter for Claude Code.",
    content_type: "text",
    inserted_at: now,
    updated_at: now
  }
]

impl_messages = [
  %{
    conversation_id: impl_conv.id,
    role: "user",
    content: "Start implementing the OSA adapter based on the architecture plan.",
    content_type: "text",
    inserted_at: now,
    updated_at: now
  },
  %{
    conversation_id: impl_conv.id,
    role: "agent",
    content:
      "Created lib/canopy/adapters/osa.ex implementing AdapterBehaviour. It wraps the local CLI subprocess with JSON-RPC framing.",
    content_type: "text",
    inserted_at: now,
    updated_at: now
  },
  %{
    conversation_id: impl_conv.id,
    role: "user",
    content: "Add error handling for timeouts and process crashes.",
    content_type: "text",
    inserted_at: now,
    updated_at: now
  },
  %{
    conversation_id: impl_conv.id,
    role: "agent",
    content:
      "Done. Added a GenServer monitor on the subprocess PID. On :DOWN we return {:error, :adapter_crashed} and log the exit reason. Timeouts use Process.send_after/3 with a configurable interval defaulting to 30 seconds.",
    content_type: "text",
    inserted_at: now,
    updated_at: now
  },
  %{
    conversation_id: impl_conv.id,
    role: "user",
    content: "Looks solid. Mark this conversation as complete.",
    content_type: "text",
    inserted_at: now,
    updated_at: now
  }
]

for msg <- planning_messages ++ impl_messages do
  Repo.insert!(
    ConversationMessage.changeset(%ConversationMessage{}, msg),
    on_conflict: :nothing
  )
end

IO.puts("    8 messages (3 in planning, 5 in implementation)")

# ---------------------------------------------------------------------------
# SECTION 24: Datasets
# ---------------------------------------------------------------------------

IO.puts("[24/27] Datasets...")

datasets_data = [
  %{
    name: "Session Performance Log",
    slug: "session-performance-log",
    description: "Time-series export of agent session durations, token counts, and cost.",
    source_type: "agent_generated",
    format: "json",
    workspace_id: workspace.id,
    created_by_agent_id: orchestrator.id,
    row_count: 840,
    size_bytes: 512_000,
    status: "active",
    tags: ["performance", "sessions", "tokens"]
  },
  %{
    name: "Issue Velocity Export",
    slug: "issue-velocity-export",
    description: "Weekly export of issue throughput per agent and project.",
    source_type: "agent_generated",
    format: "csv",
    workspace_id: workspace.id,
    created_by_agent_id: researcher.id,
    row_count: 156,
    size_bytes: 48_200,
    status: "active",
    tags: ["issues", "velocity", "weekly"]
  }
]

for attrs <- datasets_data do
  unless Repo.exists?(
           from d in Dataset,
             where: d.workspace_id == ^workspace.id and d.slug == ^attrs.slug
         ) do
    Repo.insert!(Dataset.changeset(%Dataset{}, attrs))
  end
end

IO.puts("    2 datasets: session-performance-log (json), issue-velocity-export (csv)")

# ---------------------------------------------------------------------------
# SECTION 25: Notifications
# ---------------------------------------------------------------------------

IO.puts("[25/27] Notifications...")

notifications_data = [
  %{
    workspace_id: workspace.id,
    recipient_type: "user",
    recipient_id: admin.id,
    sender_type: "agent",
    sender_id: orchestrator.id,
    category: "approval",
    severity: "info",
    title: "Approval required: Deploy v2.1 to production",
    body:
      "Orchestrator has requested approval to deploy Canopy v2.1. Review and approve or reject.",
    action_url: "/approvals",
    action_label: "Review"
  },
  %{
    workspace_id: workspace.id,
    recipient_type: "user",
    recipient_id: admin.id,
    sender_type: "system",
    category: "budget",
    severity: "warning",
    title: "Workspace budget at 72%",
    body: "OSA Development workspace has consumed $144 of its $200 monthly budget.",
    action_url: "/budget",
    action_label: "View Budget"
  },
  %{
    workspace_id: workspace.id,
    recipient_type: "agent",
    recipient_id: developer.id,
    sender_type: "system",
    category: "task",
    severity: "info",
    title: "New issue assigned: Implement OSA adapter",
    body: "You have been assigned to implement the OSA adapter. Priority: high.",
    action_url: "/issues",
    action_label: "View Issue"
  },
  %{
    workspace_id: workspace.id,
    recipient_type: "broadcast",
    sender_type: "system",
    category: "system",
    severity: "info",
    title: "Sprint 01 started",
    body: "Sprint 01 is now active. 6 issues are in scope. Goal: Launch MVP.",
    action_url: "/projects"
  },
  %{
    workspace_id: workspace.id,
    recipient_type: "user",
    recipient_id: admin.id,
    sender_type: "agent",
    sender_id: devops.id,
    category: "alert",
    severity: "error",
    title: "API health check failed",
    body: "API Monitor reported /api/health returned 503 after 3 retries.",
    action_url: "/activity",
    action_label: "View Activity"
  }
]

for attrs <- notifications_data do
  Repo.insert!(
    Notification.changeset(%Notification{}, attrs),
    on_conflict: :nothing
  )
end

IO.puts("    5 notifications: approval request, budget warning, task assignment, broadcast, alert")

# ---------------------------------------------------------------------------
# SECTION 26: Library Items
# ---------------------------------------------------------------------------

IO.puts("[26/27] Library items...")

library_items_data = [
  %{
    name: "Enterprise Agent Hierarchy",
    slug: "enterprise-agent-hierarchy",
    description:
      "Full org structure: CEO, CTO, VP Engineering, plus frontend, backend, reviewer, devops, and QA agents. Includes division/department/team setup.",
    category: "company_template",
    subcategory: "enterprise",
    version: "2.0.0",
    status: "published",
    visibility: "organization",
    icon: "building",
    config: %{
      agent_count: 15,
      divisions: ["engineering", "operations", "research"],
      requires_adapter: "claude-code"
    },
    tags: ["enterprise", "hierarchy", "org-structure"],
    install_count: 42,
    organization_id: miosa_org.id,
    readme:
      "Deploy a complete enterprise agent hierarchy with Division > Department > Team > Agent structure."
  },
  %{
    name: "Full-Stack Dev Team",
    slug: "fullstack-dev-team",
    description:
      "Orchestrator + frontend, backend, reviewer, and devops agents pre-configured for software development.",
    category: "team_template",
    subcategory: "development",
    version: "1.2.0",
    status: "published",
    visibility: "organization",
    icon: "code",
    config: %{
      agent_count: 5,
      adapters: ["osa", "claude-code", "bash"],
      skills: ["code_generation", "pr_review", "deployment"]
    },
    tags: ["development", "full-stack", "team"],
    install_count: 128,
    organization_id: miosa_org.id
  },
  %{
    name: "Research Assistant Pack",
    slug: "research-assistant-pack",
    description:
      "Orchestrator + researcher + writer agents tuned for document synthesis and report generation.",
    category: "team_template",
    subcategory: "research",
    version: "1.0.0",
    status: "published",
    visibility: "public",
    icon: "magnifier",
    config: %{
      agent_count: 3,
      adapters: ["osa", "claude-code"],
      skills: ["web_search"]
    },
    tags: ["research", "writing", "synthesis"],
    install_count: 67,
    organization_id: miosa_org.id
  },
  %{
    name: "Budget Enforcement Skill",
    slug: "budget-enforcement-skill",
    description:
      "Skill that monitors token spend and fires warnings at configurable thresholds.",
    category: "skill",
    subcategory: "governance",
    version: "1.1.0",
    status: "published",
    visibility: "organization",
    icon: "currency",
    config: %{
      warning_pct: 80,
      hard_stop_pct: 100,
      notify_channel: "activity_feed"
    },
    tags: ["budget", "governance", "monitoring"],
    install_count: 89,
    organization_id: miosa_org.id
  },
  %{
    name: "Daily Standup Workflow",
    slug: "daily-standup-workflow",
    description:
      "Automated morning standup: gather completed issues, flag blockers, post summary.",
    category: "workflow_template",
    subcategory: "operations",
    version: "1.0.0",
    status: "published",
    visibility: "organization",
    icon: "calendar",
    config: %{
      trigger: "0 9 * * 1-5",
      steps: ["gather_issues", "post_summary"],
      requires_agents: ["researcher", "orchestrator"]
    },
    tags: ["workflow", "standup", "daily", "automation"],
    install_count: 34,
    organization_id: miosa_org.id
  },
  %{
    name: "Minimal Agent",
    slug: "minimal-agent",
    description: "Single bash agent with no dependencies. Good baseline for custom builds.",
    category: "agent_template",
    subcategory: "starter",
    version: "1.0.0",
    status: "published",
    visibility: "public",
    icon: "agent",
    config: %{
      adapter: "bash",
      model: "bash",
      role: "worker"
    },
    tags: ["minimal", "bash", "starter"],
    install_count: 203,
    organization_id: miosa_org.id
  },
  %{
    name: "Micro Dev Team",
    slug: "micro-dev-team",
    description: "Lightweight 3-agent setup: orchestrator, developer, reviewer.",
    category: "team_template",
    subcategory: "development",
    version: "1.0.0",
    status: "published",
    visibility: "organization",
    icon: "users",
    config: %{
      agent_count: 3,
      adapters: ["osa", "claude-code"]
    },
    tags: ["micro", "development", "lean"],
    install_count: 91,
    organization_id: miosa_org.id
  },
  %{
    name: "Small Dev Team",
    slug: "small-dev-team",
    description: "Four agents: orchestrator, frontend, backend, devops.",
    category: "team_template",
    subcategory: "development",
    version: "1.0.0",
    status: "published",
    visibility: "organization",
    icon: "users",
    config: %{
      agent_count: 4,
      adapters: ["osa", "claude-code", "bash"]
    },
    tags: ["small", "development"],
    install_count: 55,
    organization_id: miosa_org.id
  },
  %{
    name: "CI/CD Workflow Template",
    slug: "ci-cd-workflow",
    description: "Automated build, test, and deploy pipeline triggered on push.",
    category: "workflow_template",
    subcategory: "devops",
    version: "1.0.0",
    status: "published",
    visibility: "organization",
    icon: "rocket",
    config: %{
      trigger: "webhook",
      steps: ["build", "test", "deploy"],
      requires_agents: ["devops"]
    },
    tags: ["ci-cd", "devops", "automation", "workflow"],
    install_count: 47,
    organization_id: miosa_org.id
  },
  %{
    name: "Security Audit Skill",
    slug: "security-audit-skill",
    description: "OWASP Top 10 review skill. Runs weekly or on demand.",
    category: "skill",
    subcategory: "security",
    version: "1.0.0",
    status: "published",
    visibility: "organization",
    icon: "shield",
    config: %{
      checklist: "owasp_top_10",
      output_format: "report",
      notify_on_critical: true
    },
    tags: ["security", "owasp", "audit"],
    install_count: 38,
    organization_id: miosa_org.id
  }
]

for attrs <- library_items_data do
  unless Repo.exists?(
           from l in LibraryItem,
             where:
               l.organization_id == ^miosa_org.id and
                 l.slug == ^attrs.slug and
                 l.category == ^attrs.category
         ) do
    Repo.insert!(LibraryItem.changeset(%LibraryItem{}, attrs))
  end
end

IO.puts("    10 library items: 3 team_templates, 2 workflow_templates, 2 skills, 2 agent/company templates, 1 small dev team")

# ---------------------------------------------------------------------------
# SECTION 27: Reports
# ---------------------------------------------------------------------------

IO.puts("[27/27] Reports...")

reports_data = [
  %{
    name: "Weekly Agent Performance",
    description:
      "Token usage, session duration, and cost per agent over the past 7 days.",
    report_type: "agent_performance",
    config: %{
      lookback_days: 7,
      group_by: "agent",
      metrics: ["tokens_used", "session_count", "cost_cents", "avg_duration_ms"]
    },
    schedule: "0 8 * * 1",
    format: "table",
    status: "active",
    tags: ["performance", "weekly", "agents"],
    workspace_id: workspace.id
  },
  %{
    name: "Monthly Cost Analysis",
    description: "Budget consumption breakdown by workspace, agent, and policy scope.",
    report_type: "cost_analysis",
    config: %{
      lookback_days: 30,
      group_by: "scope",
      include_incidents: true
    },
    schedule: "0 9 1 * *",
    format: "chart",
    status: "active",
    tags: ["cost", "budget", "monthly"],
    workspace_id: workspace.id
  }
]

for attrs <- reports_data do
  unless Repo.exists?(
           from r in Report,
             where: r.workspace_id == ^workspace.id and r.name == ^attrs.name
         ) do
    Repo.insert!(Report.changeset(%Report{}, attrs))
  end
end

IO.puts("    2 reports: Weekly Agent Performance (table), Monthly Cost Analysis (chart)")

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

IO.puts("""

=== Seed complete ===

  Users         admin@canopy.dev (admin), dev@canopy.dev (member)
  Workspace     \"OSA Development\"
  Agents        6  (orchestrator, researcher, developer, reviewer, devops, api-monitor)
  Schedules     3  (all disabled)
  Projects      2  (Canopy Platform, Infrastructure)
  Goals         4  (Launch MVP + child, Setup CI/CD, Security Audit)
  Issues        6  (todo x2, in_progress x1, in_review x1, backlog x2)
  Budgets       2  (agent $50/mo, workspace $200/mo)
  Skills        4  (3 enabled, 1 disabled)
  Events        8  activity entries
  Integrations  2  (anthropic connected, github disconnected)
  Orgs          2  (MIOSA Labs enterprise, Acme Corp pro)
  Memberships   2  (admin: owner of MIOSA Labs, admin of Acme Corp)
  Secrets       3  (OPENAI_API_KEY, GITHUB_TOKEN, ANTHROPIC_API_KEY)
  Labels        5  (bug, feature, urgent, documentation, enhancement)
  Approvals     2  (1 pending, 1 approved)
  Plugins       3  (github enabled, slack enabled, jira disabled)
  Templates     2  (Full-Stack Development Team, Research Assistant)
  Divisions     3  (Engineering, Operations, Research)
  Departments   5  (Platform Eng, Product Eng, SRE, AI Research, Knowledge Eng)
  Teams         6  (api-team, data-team, ui-team, infra-team, research-team, monitor-team)
  Memberships   6  (one per seeded agent)
  Workflows     2  (daily-standup active, security-scan active)
  Wf Steps      3  (standup x2, security x1)
  Conversations 2  (planning active, implementation archived)
  Messages      8  (3 in planning, 5 in implementation)
  Datasets      2  (session-performance-log, issue-velocity-export)
  Notifications 5  (approval, budget warn, task, broadcast, alert)
  Library Items 10 (templates, skills, workflows)
  Reports       2  (weekly performance, monthly cost)
""")

# end of CANOPY_SEED_DEMO guard
end
