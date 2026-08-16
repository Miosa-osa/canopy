# Seed data for canopy_dev.
#
# Idempotent — safe to run repeatedly. Uses `upsert_by: :type` so reruns update
# metadata without creating duplicates.
#
# Invoke:    mix run priv/repo/seeds.exs
# Or alias:  mix ecto.setup (runs migrate + seeds together)

alias Canopy.Repo
alias Canopy.Runtimes.Runtime
alias Canopy.Agents.Template

IO.puts("Seeding runtime catalog...")

# Full coding-agent ecosystem catalog.
# `installed`, `version`, `binary_path` stay nil until detection runs.
# Idempotent: uses Repo.get_by + insert_or_update.
# Auth profiles ─────────────────────────────────────────────────────────────

auth_profiles = %{
  "claude-local" => %{
    "methods" => ["cli_login", "api_key"],
    "cli_login" => %{
      "command" => "claude auth login",
      "detect_command" => "claude auth status",
      "detect_success_pattern" => "\"loggedIn\": true"
    },
    "api_key" => %{
      "env_var" => "ANTHROPIC_API_KEY",
      "signup_url" => "https://console.anthropic.com/settings/keys",
      "placeholder" => "sk-ant-..."
    }
  },
  "codex-local" => %{
    "methods" => ["subscription_detect", "api_key"],
    "subscription_detect" => %{
      # codex stores credentials at ~/.codex/auth.json (not credentials.json)
      "check_path" => "~/.codex/auth.json",
      "alt_env_var" => "OPENAI_API_KEY"
    },
    "api_key" => %{
      "env_var" => "OPENAI_API_KEY",
      "signup_url" => "https://platform.openai.com/api-keys",
      "placeholder" => "sk-..."
    }
  },
  "gemini-cli" => %{
    "methods" => ["subscription_detect", "cli_login", "api_key"],
    "subscription_detect" => %{
      "check_path" => "~/.config/gemini/credentials.json",
      "alt_env_var" => "GEMINI_API_KEY"
    },
    "cli_login" => %{
      "command" => "gemini auth login",
      "detect_command" => "gemini auth status",
      "detect_success_pattern" => "Logged in"
    },
    "api_key" => %{
      "env_var" => "GEMINI_API_KEY",
      "signup_url" => "https://aistudio.google.com/app/apikey",
      "placeholder" => "AIza..."
    }
  },
  "gemini-local" => %{
    "methods" => ["subscription_detect", "api_key"],
    "subscription_detect" => %{
      "check_path" => "~/.config/gemini/credentials.json",
      "alt_env_var" => "GEMINI_API_KEY"
    },
    "api_key" => %{
      "env_var" => "GEMINI_API_KEY",
      "signup_url" => "https://aistudio.google.com/app/apikey",
      "placeholder" => "AIza..."
    }
  },
  "aider-local" => %{
    "methods" => ["api_key"],
    "api_key" => %{
      "env_var" => "ANTHROPIC_API_KEY",
      "signup_url" => "https://console.anthropic.com/settings/keys",
      "placeholder" => "sk-ant-..."
    }
  },
  "amp" => %{
    "methods" => ["subscription_detect", "cli_login"],
    "subscription_detect" => %{
      "check_path" => "~/.config/sourcegraph/credentials.json"
    },
    "cli_login" => %{
      "command" => "amp auth login",
      "detect_command" => "amp auth status",
      "detect_success_pattern" => "Logged in"
    }
  },
  "continue-cli" => %{
    "methods" => ["api_key"],
    "api_key" => %{
      "env_var" => "ANTHROPIC_API_KEY",
      "signup_url" => "https://console.anthropic.com/settings/keys",
      "placeholder" => "sk-ant-..."
    }
  },
  "cursor-local" => %{
    "methods" => ["subscription_detect"],
    "subscription_detect" => %{
      "check_path" => "~/.cursor/session",
      "alt_env_var" => "ANTHROPIC_API_KEY"
    }
  },
  "cursor-agent" => %{
    "methods" => ["subscription_detect"],
    "subscription_detect" => %{
      "check_path" => "~/.cursor/session"
    }
  },
  "goose" => %{
    "methods" => ["api_key"],
    "api_key" => %{
      "env_var" => "ANTHROPIC_API_KEY",
      "signup_url" => "https://console.anthropic.com/settings/keys",
      "placeholder" => "sk-ant-..."
    }
  },
  "crush" => %{
    "methods" => ["api_key"],
    "api_key" => %{
      "env_var" => "ANTHROPIC_API_KEY",
      "signup_url" => "https://console.anthropic.com/settings/keys",
      "placeholder" => "sk-ant-..."
    }
  },
  "opencode-local" => %{
    "methods" => ["api_key"],
    "api_key" => %{
      "env_var" => "OPENAI_API_KEY",
      "signup_url" => "https://platform.openai.com/api-keys",
      "placeholder" => "sk-..."
    }
  },
  "opendevin" => %{
    "methods" => ["api_key"],
    "api_key" => %{
      "env_var" => "ANTHROPIC_API_KEY",
      "signup_url" => "https://console.anthropic.com/settings/keys",
      "placeholder" => "sk-ant-..."
    }
  },
  "gpt-engineer" => %{
    "methods" => ["api_key"],
    "api_key" => %{
      "env_var" => "OPENAI_API_KEY",
      "signup_url" => "https://platform.openai.com/api-keys",
      "placeholder" => "sk-..."
    }
  },
  "cline" => %{
    "methods" => ["api_key"],
    "api_key" => %{
      "env_var" => "ANTHROPIC_API_KEY",
      "signup_url" => "https://console.anthropic.com/settings/keys",
      "placeholder" => "sk-ant-..."
    }
  },
  "anthropic-api" => %{
    "methods" => ["api_key"],
    "api_key" => %{
      "env_var" => "ANTHROPIC_API_KEY",
      "signup_url" => "https://console.anthropic.com/settings/keys",
      "placeholder" => "sk-ant-..."
    }
  },
  "openai-api" => %{
    "methods" => ["api_key"],
    "api_key" => %{
      "env_var" => "OPENAI_API_KEY",
      "signup_url" => "https://platform.openai.com/api-keys",
      "placeholder" => "sk-..."
    }
  },
  "groq-api" => %{
    "methods" => ["api_key"],
    "api_key" => %{
      "env_var" => "GROQ_API_KEY",
      "signup_url" => "https://console.groq.com/keys",
      "placeholder" => "gsk_..."
    }
  },
  "mistral-api" => %{
    "methods" => ["api_key"],
    "api_key" => %{
      "env_var" => "MISTRAL_API_KEY",
      "signup_url" => "https://console.mistral.ai/api-keys",
      "placeholder" => "..."
    }
  },
  "ollama" => %{
    "methods" => [],
    "note" => "Ollama runs locally with no authentication required"
  },
  "llamacpp" => %{
    "methods" => [],
    "note" => "llama.cpp runs locally with no authentication required"
  }
}

runtimes = [
  # ── Coding CLI agents ───────────────────────────────────────────────────────
  %{
    type: "claude-local",
    kind: "cli",
    name: "Claude Code",
    enabled: true,
    capabilities: ["streaming", "tool_calls", "thinking", "resume", "skills_injection"]
  },
  %{
    type: "codex-local",
    kind: "cli",
    name: "OpenAI Codex CLI",
    enabled: true,
    capabilities: ["streaming", "tool_calls", "resume"]
  },
  %{
    type: "gemini-cli",
    kind: "cli",
    name: "Google Gemini CLI",
    enabled: true,
    capabilities: ["streaming", "tool_calls", "thinking"]
  },
  %{
    type: "gemini-local",
    kind: "cli",
    name: "Google Gemini (legacy slug)",
    enabled: true,
    capabilities: ["streaming", "tool_calls", "thinking"]
  },
  %{
    type: "amp",
    kind: "cli",
    name: "Sourcegraph Amp",
    enabled: true,
    capabilities: ["streaming", "tool_calls"]
  },
  %{
    type: "cline",
    kind: "cli",
    name: "Cline (Claude Dev)",
    enabled: true,
    capabilities: ["streaming", "tool_calls"]
  },
  %{
    type: "aider-local",
    kind: "cli",
    name: "Aider",
    enabled: true,
    capabilities: ["streaming", "tool_calls"]
  },
  %{
    type: "cursor-local",
    kind: "cli",
    name: "Cursor Agent",
    enabled: true,
    capabilities: ["streaming", "tool_calls"]
  },
  %{
    type: "cursor-agent",
    kind: "cli",
    name: "Cursor Agent CLI",
    enabled: true,
    capabilities: ["streaming", "tool_calls"]
  },
  %{
    type: "continue-cli",
    kind: "cli",
    name: "Continue CLI",
    enabled: true,
    capabilities: ["streaming", "tool_calls"]
  },
  %{
    type: "goose",
    kind: "cli",
    name: "Goose (Block)",
    enabled: true,
    capabilities: ["streaming", "tool_calls"]
  },
  %{
    type: "crush",
    kind: "cli",
    name: "Crush (Charm)",
    enabled: true,
    capabilities: ["streaming", "tool_calls"]
  },
  %{
    type: "opencode-local",
    kind: "cli",
    name: "OpenCode",
    enabled: true,
    capabilities: ["streaming", "tool_calls"]
  },
  %{
    type: "opendevin",
    kind: "cli",
    name: "OpenDevin",
    enabled: true,
    capabilities: ["streaming", "tool_calls"]
  },
  %{
    type: "gpt-engineer",
    kind: "cli",
    name: "GPT Engineer",
    enabled: true,
    capabilities: ["streaming", "tool_calls"]
  },
  %{
    type: "smol-developer",
    kind: "cli",
    name: "Smol Developer",
    enabled: true,
    capabilities: ["streaming"]
  },
  %{
    type: "windsurf-local",
    kind: "cli",
    name: "Windsurf",
    enabled: true,
    capabilities: ["streaming", "tool_calls"]
  },
  # ── Legacy / other CLI entries ───────────────────────────────────────────────
  %{
    type: "pi-local",
    kind: "cli",
    name: "Pi",
    enabled: true,
    capabilities: ["streaming"]
  },
  %{
    type: "hermes-local",
    kind: "cli",
    name: "Hermes",
    enabled: true,
    capabilities: ["streaming", "tool_calls"]
  },
  # ── Local model runners ──────────────────────────────────────────────────────
  %{
    type: "ollama",
    kind: "local_model",
    name: "Ollama",
    enabled: true,
    capabilities: ["streaming", "local_models", "model_management"]
  },
  %{
    type: "llamacpp",
    kind: "local_model",
    name: "llama.cpp",
    enabled: true,
    capabilities: ["streaming", "local_models"]
  },
  # ── Hosted API runtimes (no binary — always installed) ───────────────────────
  %{
    type: "anthropic-api",
    kind: "api",
    name: "Anthropic API",
    enabled: true,
    installed: true,
    capabilities: ["streaming", "tool_calls", "thinking"]
  },
  %{
    type: "openai-api",
    kind: "api",
    name: "OpenAI API",
    enabled: true,
    installed: true,
    capabilities: ["streaming", "tool_calls"]
  },
  %{
    type: "groq-api",
    kind: "api",
    name: "Groq API",
    enabled: true,
    installed: true,
    capabilities: ["streaming", "tool_calls"]
  },
  %{
    type: "mistral-api",
    kind: "api",
    name: "Mistral API",
    enabled: true,
    installed: true,
    capabilities: ["streaming", "tool_calls"]
  }
]

for attrs <- runtimes do
  auth_profile = Map.get(auth_profiles, attrs.type)
  attrs_with_profile = Map.put(attrs, :auth_profile, auth_profile)

  case Repo.get_by(Runtime, type: attrs.type) do
    nil ->
      %Runtime{}
      |> Runtime.changeset(attrs_with_profile)
      |> Repo.insert!()

      IO.puts("  inserted: #{attrs.type}")

    existing ->
      existing
      |> Runtime.changeset(
        Map.take(attrs_with_profile, [:name, :kind, :enabled, :capabilities, :auth_profile])
      )
      |> Repo.update!()

      IO.puts("  updated:  #{attrs.type}")
  end
end

IO.puts("Done. #{length(runtimes)} runtimes seeded.")

# ---------------------------------------------------------------------------
# Default workspace + demo content
# ---------------------------------------------------------------------------

alias Canopy.Workspaces
alias Canopy.Workspaces.Workspace
alias Canopy.Tasks
alias Canopy.Tasks.Task
alias Canopy.Channels
alias Canopy.Channels.Channel
alias Canopy.Docs
alias Canopy.Docs.Document

IO.puts("\nSeeding default workspace...")

ws_slug = "default"
ws_root = Path.join(System.tmp_dir!(), "canopy-default-workspace")

workspace =
  case Workspaces.get_by_slug(ws_slug) do
    {:ok, existing} ->
      IO.puts("  workspace exists: #{ws_slug}")
      existing

    {:error, :not_found} ->
      {:ok, ws} =
        Workspaces.create(%{
          slug: ws_slug,
          name: "Default",
          description: "Your starting workspace",
          root_path: ws_root
        })

      IO.puts("  inserted workspace: #{ws_slug}")
      ws
  end

# ── Demo tasks ──────────────────────────────────────────────────────────────

IO.puts("Seeding demo tasks...")

demo_tasks = [
  %{
    title: "Set up project repository",
    description: "Initialize Git, configure CI, add README.",
    status: "done",
    priority: 2,
    workspace_slug: workspace.slug,
    assignee_type: "agent",
    assignee_id: "account-strategist-revenue",
    due_at: ~U[2026-04-10 18:00:00Z]
  },
  %{
    title: "Design system tokens",
    description: "Define OKLCh color ramps, spacing scale, and typography.",
    status: "done",
    priority: 3,
    workspace_slug: workspace.slug,
    assignee_type: "agent",
    assignee_id: "ui-designer-design",
    due_at: ~U[2026-04-12 18:00:00Z]
  },
  %{
    title: "Write API spec for agents endpoint",
    description: "OpenAPISpex schema covering list, hire, fire, and detail.",
    status: "todo",
    priority: 3,
    workspace_slug: workspace.slug,
    assignee_type: "agent",
    assignee_id: "backend-engineer-engineering",
    due_at: ~U[2026-04-22 18:00:00Z]
  },
  %{
    title: "Build WorkspaceSwitcher component",
    description: "Popover with search, keyboard nav, and localStorage persistence.",
    status: "todo",
    priority: 2,
    workspace_slug: workspace.slug,
    assignee_type: "agent",
    assignee_id: "frontend-engineer-engineering",
    due_at: ~U[2026-04-23 18:00:00Z]
  },
  %{
    title: "Integrate TanStack Query",
    description: "Wire all page-level queries through the canonical writable+untrack bridge.",
    status: "in_progress",
    priority: 2,
    workspace_slug: workspace.slug,
    assignee_type: "agent",
    assignee_id: "fullstack-engineer-engineering",
    due_at: ~U[2026-04-21 18:00:00Z]
  },
  %{
    title: "Write seed data for demo content",
    description: "Populate workspace, tasks, channels, and documents for first launch.",
    status: "in_progress",
    priority: 1,
    workspace_slug: workspace.slug,
    assignee_type: "agent",
    assignee_id: "account-strategist-revenue",
    due_at: ~U[2026-04-20 18:00:00Z]
  },
  %{
    title: "KanbanBoard drag-and-drop",
    description: "Implement column drop zones with optimistic status updates.",
    status: "todo",
    priority: 2,
    workspace_slug: workspace.slug,
    assignee_type: "agent",
    assignee_id: "frontend-engineer-engineering",
    due_at: ~U[2026-04-25 18:00:00Z]
  },
  %{
    title: "Analytics dashboard charts",
    description: "Session-count area chart and tasks-completion bar chart via layerchart.",
    status: "todo",
    priority: 1,
    workspace_slug: workspace.slug,
    assignee_type: "agent",
    assignee_id: "data-analyst-operations",
    due_at: ~U[2026-04-28 18:00:00Z]
  }
]

for attrs <- demo_tasks do
  existing =
    Repo.get_by(Task, title: attrs.title, workspace_slug: workspace.slug)

  if existing do
    IO.puts("  task exists: #{attrs.title}")
  else
    {:ok, _} = Tasks.create(attrs)
    IO.puts("  inserted task: #{attrs.title}")
  end
end

# ── Demo channels ────────────────────────────────────────────────────────────

IO.puts("Seeding demo channels...")

demo_channels = [
  %{
    slug: "general",
    name: "general",
    description: "Team-wide announcements and discussion",
    visibility: "public",
    workspace_slug: workspace.slug,
    icon: "hash"
  },
  %{
    slug: "engineering",
    name: "engineering",
    description: "Backend, frontend, and infrastructure topics",
    visibility: "public",
    workspace_slug: workspace.slug,
    icon: "code"
  },
  %{
    slug: "design",
    name: "design",
    description: "UI/UX, design system, and visual assets",
    visibility: "public",
    workspace_slug: workspace.slug,
    icon: "layers"
  }
]

for attrs <- demo_channels do
  existing = Repo.get_by(Channel, slug: attrs.slug)

  if existing do
    IO.puts("  channel exists: #{attrs.slug}")
  else
    {:ok, _} = Channels.create(attrs)
    IO.puts("  inserted channel: #{attrs.slug}")
  end
end

# ── Demo documents ───────────────────────────────────────────────────────────

IO.puts("Seeding demo documents...")

demo_docs = [
  %{
    slug: "getting-started",
    workspace_slug: workspace.slug,
    title: "Getting Started",
    body_json: %{
      "type" => "doc",
      "content" => [
        %{
          "type" => "paragraph",
          "content" => [%{"type" => "text", "text" => "Welcome to your Canopy workspace."}]
        }
      ]
    },
    body_text: "Welcome to your Canopy workspace.",
    author_type: "user",
    author_id: "seed",
    last_editor_type: "user",
    last_editor_id: "seed",
    published: true,
    tags: ["onboarding"]
  },
  %{
    slug: "workspace-protocol",
    workspace_slug: workspace.slug,
    title: "Workspace Protocol",
    body_json: %{
      "type" => "doc",
      "content" => [
        %{
          "type" => "paragraph",
          "content" => [
            %{
              "type" => "text",
              "text" => "Describes the file layout and agent assignment conventions."
            }
          ]
        }
      ]
    },
    body_text: "Describes the file layout and agent assignment conventions.",
    author_type: "user",
    author_id: "seed",
    last_editor_type: "user",
    last_editor_id: "seed",
    published: false,
    tags: ["protocol", "reference"]
  }
]

for attrs <- demo_docs do
  existing = Repo.get_by(Document, slug: attrs.slug, workspace_slug: workspace.slug)

  if existing do
    IO.puts("  document exists: #{attrs.slug}")
  else
    {:ok, _} = Docs.create(attrs)
    IO.puts("  inserted document: #{attrs.slug}")
  end
end

IO.puts("\nDemo content seeded for workspace '#{workspace.slug}'.")

# ---------------------------------------------------------------------------
# Demo Issues
# ---------------------------------------------------------------------------

alias Canopy.Issues
alias Canopy.Issues.Issue, as: IssueSchema

IO.puts("\nSeeding demo issues...")

demo_issues = [
  %{
    title: "Implement agent heartbeat endpoint",
    description: "Add GET /api/v1/agents/:slug/heartbeats with pagination.",
    status: "open",
    priority: 3,
    workspace_slug: workspace.slug,
    assignee_type: "agent",
    assignee_id: "backend-engineer-engineering",
    labels: ["api", "backend"]
  },
  %{
    title: "Fix session event SSE reconnect",
    description: "Clients lose the SSE stream after 30s. Add Last-Event-ID support.",
    status: "in_progress",
    priority: 4,
    workspace_slug: workspace.slug,
    assignee_type: "agent",
    assignee_id: "backend-engineer-engineering",
    labels: ["bug", "streaming"]
  },
  %{
    title: "Migrate tasks Kanban to SvelteKit page",
    description: "Extract the Kanban board from the monolith into its own route.",
    status: "backlog",
    priority: 2,
    workspace_slug: workspace.slug,
    labels: ["frontend"]
  },
  %{
    title: "Add labels filter to issues list",
    description: "Support ?labels=bug,frontend on GET /api/v1/issues.",
    status: "open",
    priority: 1,
    workspace_slug: workspace.slug,
    labels: ["enhancement"]
  },
  %{
    title: "OpenAPI spec for Issues, Goals, Routines",
    description: "Verify all new schemas render correctly in SwaggerUI.",
    status: "in_review",
    priority: 2,
    workspace_slug: workspace.slug,
    assignee_type: "agent",
    assignee_id: "backend-engineer-engineering",
    labels: ["docs", "api"]
  }
]

for attrs <- demo_issues do
  existing = Repo.get_by(IssueSchema, title: attrs.title, workspace_slug: workspace.slug)

  if existing do
    IO.puts("  issue exists: #{attrs.title}")
  else
    {:ok, _} = Issues.create(attrs)
    IO.puts("  inserted issue: #{attrs.title}")
  end
end

# ---------------------------------------------------------------------------
# Demo Goals
# ---------------------------------------------------------------------------

alias Canopy.Goals
alias Canopy.Goals.Goal, as: GoalSchema

IO.puts("\nSeeding demo goals...")

demo_goals = [
  %{
    title: "Launch Canopy v1.0 to first 10 workspaces",
    description: "Full platform feature-complete: sessions, tasks, issues, goals, routines.",
    status: "active",
    priority: 4,
    workspace_slug: workspace.slug,
    progress_pct: 35,
    success_criteria: "10 workspaces active, all core APIs green, SSE streaming stable."
  },
  %{
    title: "Integrate RAG knowledge base into agent context",
    description: "Agents auto-inject relevant KB chunks into their system prompt.",
    status: "proposed",
    priority: 3,
    workspace_slug: workspace.slug,
    progress_pct: 0,
    success_criteria: "Agents reference KB docs in at least 80% of relevant sessions."
  },
  %{
    title: "Ship Routines scheduler GenServer",
    description: "Cron-based routine firing with Oban or a native GenServer.",
    status: "proposed",
    priority: 2,
    workspace_slug: workspace.slug,
    progress_pct: 0,
    success_criteria: "Routines fire within ±60s of their cron schedule."
  }
]

for attrs <- demo_goals do
  existing = Repo.get_by(GoalSchema, title: attrs.title, workspace_slug: workspace.slug)

  if existing do
    IO.puts("  goal exists: #{attrs.title}")
  else
    {:ok, _} = Goals.create(attrs)
    IO.puts("  inserted goal: #{attrs.title}")
  end
end

# ---------------------------------------------------------------------------
# Demo Routines
# ---------------------------------------------------------------------------

alias Canopy.Routines
alias Canopy.Routines.Routine, as: RoutineSchema

IO.puts("\nSeeding demo routines...")

demo_routines = [
  %{
    name: "Daily standup issue",
    description: "Creates a standup issue every weekday morning.",
    cron: "0 9 * * 1-5",
    prompt_template:
      "Create a standup summary issue for workspace {{workspace}} on {{date}}. Summarize active sessions, blocked issues, and next steps.",
    creates: "issue",
    target_agent_id: "backend-engineer-engineering",
    workspace_slug: workspace.slug,
    enabled: true
  },
  %{
    name: "Weekly progress goal review",
    description: "Creates a weekly goal review task every Monday.",
    cron: "0 10 * * 1",
    prompt_template:
      "Review all active goals in {{workspace}} for the week of {{date}}. Update progress_pct and flag any blocked goals.",
    creates: "task",
    target_agent_id: "account-strategist-revenue",
    workspace_slug: workspace.slug,
    enabled: true
  }
]

for attrs <- demo_routines do
  existing = Repo.get_by(RoutineSchema, name: attrs.name, workspace_slug: workspace.slug)

  if existing do
    IO.puts("  routine exists: #{attrs.name}")
  else
    {:ok, _} = Routines.create(attrs)
    IO.puts("  inserted routine: #{attrs.name}")
  end
end

IO.puts("\nDone seeding issues, goals, and routines.")

# ---------------------------------------------------------------------------
# Demo Projects
# ---------------------------------------------------------------------------

alias Canopy.Projects
alias Canopy.Projects.Project, as: ProjectSchema

IO.puts("\nSeeding demo projects...")

demo_projects = [
  %{
    slug: "canopy-launch",
    name: "Canopy Launch",
    description: "Ship Canopy v1.0 — sessions, tasks, issues, goals, routines, projects.",
    workspace_slug: workspace.slug,
    status: "active",
    color: "#7bd88f",
    icon: "Rocket",
    owner_type: "agent",
    owner_id: "backend-engineer-engineering"
  },
  %{
    slug: "miosa-v2",
    name: "MIOSA v2",
    description: "Platform rebuild — Firecracker VMs, multi-tenant compute, billing.",
    workspace_slug: workspace.slug,
    status: "active",
    color: "#6dcff6",
    icon: "Server",
    owner_type: "agent",
    owner_id: "fullstack-engineer-engineering"
  },
  %{
    slug: "docs-refresh",
    name: "Docs refresh",
    description: "Audit and rewrite all public docs for the v1.0 release.",
    workspace_slug: workspace.slug,
    status: "paused",
    color: "#f6a623",
    icon: "BookOpen"
  }
]

for attrs <- demo_projects do
  existing = Repo.get_by(ProjectSchema, slug: attrs.slug)

  if existing do
    IO.puts("  project exists: #{attrs.slug}")
  else
    {:ok, _} = Projects.create(attrs)
    IO.puts("  inserted project: #{attrs.slug}")
  end
end

# Associate a handful of existing issues/tasks/goals to demo projects
IO.puts("  associating demo work items to projects...")

import Ecto.Query, only: [from: 2]

Repo.update_all(
  from(i in IssueSchema,
    where: i.workspace_slug == ^workspace.slug and i.title == "Implement agent heartbeat endpoint"
  ),
  set: [project_slug: "canopy-launch"]
)

Repo.update_all(
  from(i in IssueSchema,
    where: i.workspace_slug == ^workspace.slug and i.title == "Fix session event SSE reconnect"
  ),
  set: [project_slug: "canopy-launch"]
)

Repo.update_all(
  from(t in Task,
    where: t.workspace_slug == ^workspace.slug and t.title == "Write API spec for agents endpoint"
  ),
  set: [project_slug: "canopy-launch"]
)

Repo.update_all(
  from(g in GoalSchema,
    where:
      g.workspace_slug == ^workspace.slug and
        g.title == "Launch Canopy v1.0 to first 10 workspaces"
  ),
  set: [project_slug: "canopy-launch"]
)

IO.puts("\nDone seeding projects.")

# ---------------------------------------------------------------------------
# Demo Reviews (human-approval queue)
# ---------------------------------------------------------------------------

alias Canopy.Reviews
alias Canopy.Reviews.Review, as: ReviewSchema

IO.puts("\nSeeding demo reviews...")

now = DateTime.utc_now() |> DateTime.truncate(:second)
expires_at = DateTime.add(now, 86_400, :second)

demo_reviews = [
  # 3 pending artifact reviews
  %{
    kind: "artifact",
    artifact_type: "doc",
    artifact_id: "getting-started",
    artifact_preview:
      "# Getting Started\n\nAgent-generated onboarding guide. Please review for accuracy.",
    workspace_slug: workspace.slug,
    agent_id: "backend-engineer-engineering",
    status: "pending",
    requested_at: now,
    expires_at: expires_at
  },
  %{
    kind: "artifact",
    artifact_type: "task",
    artifact_id: nil,
    artifact_preview: "**Title:** Migrate staging DB to Postgres 16\n**Priority:** High",
    workspace_slug: workspace.slug,
    agent_id: "fullstack-engineer-engineering",
    status: "pending",
    requested_at: DateTime.add(now, -300, :second),
    expires_at: expires_at
  },
  %{
    kind: "artifact",
    artifact_type: "file",
    artifact_id: nil,
    artifact_preview: "```diff\n- old_config: true\n+ new_config: false\n```",
    workspace_slug: workspace.slug,
    agent_id: "backend-engineer-engineering",
    status: "pending",
    requested_at: DateTime.add(now, -600, :second),
    expires_at: expires_at
  },
  # 1 pending tool_call review
  %{
    kind: "tool_call",
    tool_name: "exec_shell",
    tool_args: %{"command" => "mix ecto.drop --quiet", "cwd" => "/app"},
    workspace_slug: workspace.slug,
    session_id: Ecto.UUID.generate(),
    agent_id: "backend-engineer-engineering",
    status: "pending",
    requested_at: DateTime.add(now, -60, :second),
    expires_at: expires_at
  },
  # 1 approved (historical)
  %{
    kind: "artifact",
    artifact_type: "pr",
    artifact_id: "pr-42",
    artifact_preview: "**PR #42:** Add review queue schema + context",
    workspace_slug: workspace.slug,
    agent_id: "backend-engineer-engineering",
    reviewer_id: "roberto",
    status: "approved",
    requested_at: DateTime.add(now, -3600, :second),
    decided_at: DateTime.add(now, -3000, :second),
    expires_at: expires_at
  },
  # 1 rejected (historical)
  %{
    kind: "artifact",
    artifact_type: "doc",
    artifact_id: "bad-doc",
    artifact_preview: "# Outdated notes\n\nThis doc is stale and should not be published.",
    workspace_slug: workspace.slug,
    agent_id: "fullstack-engineer-engineering",
    reviewer_id: "roberto",
    status: "rejected",
    feedback: "This content is outdated. Archive it instead.",
    requested_at: DateTime.add(now, -7200, :second),
    decided_at: DateTime.add(now, -6800, :second),
    expires_at: expires_at
  }
]

for attrs <- demo_reviews do
  # Idempotency: skip if a review with same agent_id, artifact_type/tool_name, and status exists
  lookup_field = if attrs.kind == "tool_call", do: :tool_name, else: :artifact_type
  lookup_val = Map.get(attrs, lookup_field)

  existing =
    Repo.get_by(ReviewSchema,
      workspace_slug: attrs.workspace_slug,
      kind: attrs.kind,
      status: attrs.status,
      agent_id: attrs.agent_id
    )

  if existing && Map.get(existing, lookup_field) == lookup_val do
    IO.puts("  review exists: #{attrs.kind}/#{lookup_val} (#{attrs.status})")
  else
    changeset = ReviewSchema.changeset(%ReviewSchema{}, attrs)

    case Repo.insert(changeset) do
      {:ok, _} -> IO.puts("  inserted review: #{attrs.kind}/#{lookup_val} (#{attrs.status})")
      {:error, cs} -> IO.puts("  WARN: #{inspect(cs.errors)}")
    end
  end
end

IO.puts("\nDone seeding reviews.")

# ---------------------------------------------------------------------------
# Governance: :requires_review rules
# ---------------------------------------------------------------------------

alias Canopy.Governance.Rule, as: GovernanceRule

IO.puts("\nSeeding governance :requires_review rules...")

review_rules = [
  %{
    name: "Review all agent docs",
    description: "Any doc created by an agent goes through human review.",
    kind: "requires_review",
    action: "require_review",
    conditions: %{"match" => "artifact", "artifact_types" => ["doc"]},
    priority: 10,
    enabled: true
  },
  %{
    name: "Review exec_shell tool calls",
    description: "Any exec_shell invocation must be approved before the agent proceeds.",
    kind: "requires_review",
    action: "require_review",
    conditions: %{"match" => "tool_call", "tool_names" => ["exec_shell"]},
    priority: 10,
    enabled: true
  }
]

for attrs <- review_rules do
  case Repo.get_by(GovernanceRule, name: attrs.name) do
    nil ->
      GovernanceRule.changeset(%GovernanceRule{}, Map.drop(attrs, [:kind]))
      |> Repo.insert!()

      IO.puts("  inserted: #{attrs.name}")

    existing ->
      IO.puts("  exists:   #{existing.name}")
  end
end

IO.puts("Done seeding governance rules.")

# ---------------------------------------------------------------------------
# Agent tool capabilities — grant backend-engineer-engineering full access
# ---------------------------------------------------------------------------

alias Canopy.Agents
alias Canopy.Agents.Agent

IO.puts("\nSeeding agent tool capabilities...")

tool_capable_agents = [
  %{
    slug: "backend-engineer-engineering",
    capabilities: ["read_workspace", "write_tasks", "write_issues", "move_card", "spawn_sessions"]
  }
]

for %{slug: slug, capabilities: caps} <- tool_capable_agents do
  case Agents.get_by_slug(slug) do
    {:ok, agent} ->
      existing_caps = get_in(agent.config || %{}, ["capabilities"]) || []
      merged = Enum.uniq(existing_caps ++ caps)
      new_config = Map.merge(agent.config || %{}, %{"capabilities" => merged})

      agent
      |> Agent.changeset(%{config: new_config})
      |> Canopy.Repo.update()
      |> case do
        {:ok, _} -> IO.puts("  updated capabilities: #{slug}")
        {:error, cs} -> IO.puts("  WARN: #{slug} — #{inspect(cs.errors)}")
      end

    {:error, :not_found} ->
      IO.puts("  SKIP: agent #{slug} not seeded yet (run mix canopy.seed.agents first)")
  end
end

IO.puts("Done seeding agent tool capabilities.")

# ---------------------------------------------------------------------------
# Demo: orchestrator agent with requires_hire_approval: true
# ---------------------------------------------------------------------------

IO.puts("\nSeeding hire-approval demo flag...")

case Agents.get_by_slug("backend-engineer-engineering") do
  {:ok, agent} ->
    existing_config = agent.config || %{}

    new_config = Map.put(existing_config, "requires_hire_approval", true)

    agent
    |> Agent.changeset(%{config: new_config})
    |> Canopy.Repo.update()
    |> case do
      {:ok, _} -> IO.puts("  set requires_hire_approval=true on backend-engineer-engineering")
      {:error, cs} -> IO.puts("  WARN: #{inspect(cs.errors)}")
    end

  {:error, :not_found} ->
    IO.puts("  SKIP: backend-engineer-engineering not found (run mix canopy.seed.agents first)")
end

IO.puts("Done.")

# ---------------------------------------------------------------------------
# Skills — 6 representative skills (kind split: prompt | workflow | reference)
# ---------------------------------------------------------------------------

alias Canopy.Skills
alias Canopy.Skills.AgentSkillAssignment

IO.puts("\nSeeding representative skills...")

representative_skills = [
  %{
    "slug" => "code-reviewer",
    "name" => "Code Reviewer",
    "description" =>
      "Systematic code review checklist covering correctness, security, performance, and style.",
    "kind" => "prompt",
    "provider_format" => "generic",
    "source" => "local",
    "tags" => ["review", "quality"],
    "enabled" => true,
    "content" => """
    ## Code Review Protocol

    Apply this checklist to every diff before approving:

    ### Correctness
    - [ ] Logic is correct and handles edge cases
    - [ ] Error conditions are handled, not silently swallowed
    - [ ] No off-by-one errors or unbounded loops

    ### Security
    - [ ] No hardcoded secrets or credentials
    - [ ] Inputs are validated and sanitized before use
    - [ ] SQL / command injection prevented (parameterized queries only)
    - [ ] Auth checks present on every protected path

    ### Performance
    - [ ] No N+1 query patterns
    - [ ] No unnecessary allocations in hot paths
    - [ ] Indexes exist for new query patterns

    ### Maintainability
    - [ ] Names are descriptive and consistent with codebase conventions
    - [ ] Functions are small and have single responsibility
    - [ ] Dead code removed

    ### Output format
    Reply: `APPROVED`, `NEEDS CHANGES`, or `BLOCKED` followed by a bulleted list of issues.
    """
  },
  %{
    "slug" => "tdd-enforcer",
    "name" => "TDD Enforcer",
    "description" =>
      "Workflow that enforces RED → GREEN → REFACTOR on every implementation task.",
    "kind" => "workflow",
    "provider_format" => "generic",
    "source" => "local",
    "tags" => ["tdd", "testing", "workflow"],
    "enabled" => true,
    "content" => """
    ## TDD Workflow

    Follow this cycle on every non-trivial implementation task:

    1. **RED** — Write a failing test that describes the desired behavior. Run it. Confirm it fails.
    2. **GREEN** — Write the minimum code to make the test pass. No more.
    3. **REFACTOR** — Clean up: extract functions, rename, remove duplication. Tests must stay green.

    ### Rules
    - Never write production code before a failing test exists.
    - One failing test at a time.
    - If a test is hard to write, the design is wrong — simplify the interface first.
    - Commit after each GREEN + REFACTOR cycle.
    """
  },
  %{
    "slug" => "elixir-style-guide",
    "name" => "Elixir Style Guide",
    "description" =>
      "Reference for idiomatic Elixir: naming, pipe operator, pattern matching, OTP conventions.",
    "kind" => "reference",
    "provider_format" => "claude",
    "source" => "local",
    "tags" => ["elixir", "style", "reference"],
    "enabled" => true,
    "content" => """
    ## Elixir Style Reference

    ### Naming
    - Modules: `PascalCase` (`MyApp.UserSession`)
    - Functions: `snake_case` (`get_user/1`)
    - Boolean functions: `?` suffix (`valid?/1`, `authenticated?/1`)
    - Bang functions: `!` suffix for raising variants (`get_user!/1`)

    ### Pipe operator
    - Always start a pipeline on a new line
    - Each pipe step should do exactly one thing
    - Prefer named functions over anonymous fn in pipelines

    ### Pattern matching
    - Use pattern matching in function heads, not `if` chains
    - Guard clauses with `when` for type/value constraints
    - Use `with` for chains where each step can fail independently

    ### OTP conventions
    - `start_link/1` always takes an opts keyword list
    - Public API functions live above `init/handle_*` callbacks
    - State is a struct, not a bare map
    - Use `@impl true` on all GenServer callbacks

    ### Testing
    - `describe` blocks per function or scenario
    - `setup` for shared fixtures, not repeated inserts
    - Async tests where possible (`async: true`)
    """
  },
  %{
    "slug" => "security-auditor",
    "name" => "Security Auditor",
    "description" => "OWASP Top 10 prompt for systematic security review of any change.",
    "kind" => "prompt",
    "provider_format" => "generic",
    "source" => "local",
    "tags" => ["security", "owasp", "review"],
    "enabled" => true,
    "content" => """
    ## Security Audit Protocol

    Evaluate every change against the OWASP Top 10:

    - **A01 Broken Access Control** — Authorization on every endpoint? No IDOR? CORS locked down?
    - **A02 Cryptographic Failures** — TLS everywhere? No hardcoded secrets? Strong algorithms?
    - **A03 Injection** — Parameterized queries only? Input sanitized? No shell interpolation?
    - **A04 Insecure Design** — Fail securely? Threat model reviewed?
    - **A05 Security Misconfiguration** — Secure defaults? No stack traces in production? Headers set?
    - **A06 Vulnerable Components** — Dependencies current? No known CVEs?
    - **A07 Authentication Failures** — Brute force protection? Session management secure?
    - **A08 Data Integrity** — Signed artifacts? CI pipeline secure?
    - **A09 Logging Failures** — Security events logged? No PII/tokens in logs?
    - **A10 SSRF** — URL validation? External calls allowlisted?

    Flag any violation as `CRITICAL`, `MAJOR`, or `MINOR` with file:line reference.
    """
  },
  %{
    "slug" => "git-commit-format",
    "name" => "Git Commit Format",
    "description" =>
      "Reference for conventional commit message format used across this codebase.",
    "kind" => "reference",
    "provider_format" => "generic",
    "source" => "local",
    "tags" => ["git", "commits", "reference"],
    "enabled" => true,
    "content" => """
    ## Git Commit Format

    Use Conventional Commits: `<type>(<scope>): <subject>`

    ### Types
    - `feat` — new feature
    - `fix` — bug fix
    - `refactor` — neither feature nor fix
    - `test` — adding or correcting tests
    - `docs` — documentation only
    - `chore` — build, deps, CI config

    ### Rules
    - Subject: imperative mood, lowercase, no period, ≤ 72 chars
    - Body: explain WHY, not what (the diff shows what)
    - Breaking changes: add `BREAKING CHANGE:` footer
    - One logical change per commit — squash if needed before merge

    ### Examples
    ```
    feat(skills): add agent assignment endpoints
    fix(sessions): prevent double-spawn on resume
    refactor(injection): extract context filter to private fn
    ```
    """
  },
  %{
    "slug" => "debugging-rubric",
    "name" => "Debugging Rubric",
    "description" =>
      "Systematic debugging workflow: REPRODUCE → ISOLATE → HYPOTHESIZE → TEST → FIX → VERIFY → PREVENT.",
    "kind" => "workflow",
    "provider_format" => "generic",
    "source" => "local",
    "tags" => ["debugging", "workflow"],
    "enabled" => true,
    "content" => """
    ## Debugging Rubric

    Follow this sequence — do not skip steps:

    1. **REPRODUCE** — Get exact steps. Confirm it's consistent. Find the minimum reproduction case.
    2. **ISOLATE** — Narrow scope. Check recent changes (`git log`, `git diff`). Identify affected component.
    3. **HYPOTHESIZE** — Form 2–3 ranked theories. Decide how to falsify each.
    4. **TEST** — Test the most likely hypothesis first. Use `dbg()`, logs, or binary search (`git bisect`).
    5. **FIX** — Fix root cause only. Keep change minimal. Do not refactor while fixing.
    6. **VERIFY** — Confirm bug is gone. Check for regressions. Test edge cases.
    7. **PREVENT** — Add a regression test. Update monitoring if warranted.

    ### BEAM-specific traps
    - Mailbox overflow — check `Process.info(pid, :message_queue_len)`
    - ETS race conditions — check table ownership and `:write_concurrency` config
    - Supervisor storms — inspect supervision tree, check restart intensity
    """
  }
]

for attrs <- representative_skills do
  case Skills.upsert(attrs) do
    {:ok, skill} -> IO.puts("  upserted skill: #{skill.slug}")
    {:error, cs} -> IO.puts("  WARN: #{attrs["slug"]} — #{inspect(cs.errors)}")
  end
end

IO.puts("Done seeding representative skills.")

# ---------------------------------------------------------------------------
# Assign 3 skills to backend-engineer-engineering
# ---------------------------------------------------------------------------

IO.puts("\nAssigning skills to backend-engineer-engineering...")

skill_assignments = [
  {"code-reviewer", 0},
  {"elixir-style-guide", 1},
  {"debugging-rubric", 2}
]

for {skill_slug, priority} <- skill_assignments do
  case Canopy.Repo.get_by(AgentSkillAssignment,
         agent_slug: "backend-engineer-engineering",
         skill_slug: skill_slug
       ) do
    nil ->
      case Skills.assign("backend-engineer-engineering", skill_slug, priority: priority) do
        {:ok, _} -> IO.puts("  assigned: #{skill_slug} (priority #{priority})")
        {:error, cs} -> IO.puts("  WARN: #{skill_slug} — #{inspect(cs.errors)}")
      end

    _ ->
      IO.puts("  exists:   #{skill_slug}")
  end
end

IO.puts("Done assigning skills.")

# ---------------------------------------------------------------------------
# Agent template marketplace (20 presets)
# ---------------------------------------------------------------------------

IO.puts("\nSeeding agent templates...")

agent_templates = [
  # ── Engineering (11) ─────────────────────────────────────────────────────
  %{
    slug: "tpl-code-reviewer",
    name: "Code Reviewer",
    description: "Reviews pull requests and surfaces correctness, security, and maintainability issues.",
    category: "engineering",
    icon: "🔍",
    color: "#374151",
    sort_order: 10,
    capabilities: ["read_files", "write_tasks", "post_comments"],
    skill_slugs: [],
    persona_markdown: """
    You are a senior code reviewer with 10+ years of experience across backend, frontend, and infrastructure.

    Your job is to review code changes and surface:
    - Logic bugs and edge cases
    - Security vulnerabilities (injection, auth bypass, secret exposure)
    - Performance anti-patterns (N+1 queries, blocking I/O, unbounded loops)
    - Maintainability issues (naming, coupling, complexity)
    - Missing test coverage for critical paths

    Format your review as:
    - **Summary** — one-paragraph assessment
    - **Critical** — must-fix items (block merge)
    - **Major** — should-fix items (strong suggestion)
    - **Minor** — nice-to-have improvements
    - **Positive** — what was done well

    Be direct. No filler. Reference line numbers when possible.
    """
  },
  %{
    slug: "tpl-qa-engineer",
    name: "QA Engineer",
    description: "Designs test plans, finds edge cases, and validates feature acceptance criteria.",
    category: "engineering",
    icon: "🧪",
    color: "#374151",
    sort_order: 20,
    capabilities: ["read_files", "write_files", "write_tasks"],
    skill_slugs: [],
    persona_markdown: """
    You are a QA Engineer specialized in systematic test planning and exploratory testing.

    Your responsibilities:
    - Analyze features and derive test cases covering happy path, edge cases, and failure modes
    - Write acceptance criteria in Given/When/Then format
    - Design test plans with priority ordering (P0 = blocking, P1 = major, P2 = minor)
    - Identify integration points that need contract testing
    - Surface ambiguous requirements before development starts

    Always ask: what happens when the input is empty? When the network fails? When concurrent requests arrive?
    """
  },
  %{
    slug: "tpl-test-writer",
    name: "Test Writer",
    description: "Writes unit, integration, and E2E tests for existing code.",
    category: "engineering",
    icon: "✅",
    color: "#374151",
    sort_order: 30,
    capabilities: ["read_files", "write_files"],
    skill_slugs: [],
    persona_markdown: """
    You are a test automation engineer who writes high-quality, maintainable tests.

    Your principles:
    - Tests should read like documentation: describe("component", () => { it("should X when Y") })
    - Arrange / Act / Assert structure in every test
    - Mock at the boundary, not deep in the stack
    - Cover: happy path, boundary values, null/undefined inputs, error conditions, async behavior
    - Target 80%+ branch coverage on business logic; don't chase 100% on boilerplate

    Match the testing framework in the existing codebase. Do not introduce new dependencies.
    """
  },
  %{
    slug: "tpl-security-auditor",
    name: "Security Auditor",
    description: "Audits code and infrastructure for OWASP Top 10 and supply chain risks.",
    category: "engineering",
    icon: "🔐",
    color: "#374151",
    sort_order: 40,
    capabilities: ["read_files", "write_tasks", "post_comments"],
    skill_slugs: [],
    persona_markdown: """
    You are a security engineer conducting systematic security audits.

    Audit against the OWASP Top 10:
    1. Broken Access Control — check auth on every endpoint, IDOR vulnerabilities
    2. Cryptographic Failures — TLS, key management, no hardcoded secrets
    3. Injection — parameterized queries, input sanitization
    4. Insecure Design — threat modeling, fail-safe defaults
    5. Security Misconfiguration — headers, error handling, CORS
    6. Vulnerable Components — dependency CVEs, license compliance
    7. Authentication Failures — session management, brute-force protection
    8. Data Integrity — signed artifacts, CI/CD security
    9. Logging Failures — security events logged, no PII in logs
    10. SSRF — URL validation, network segmentation

    Output: severity (Critical/High/Medium/Low), location, description, remediation.
    """
  },
  %{
    slug: "tpl-refactorer",
    name: "Refactorer",
    description: "Improves code structure, removes duplication, and reduces complexity without changing behavior.",
    category: "engineering",
    icon: "♻️",
    color: "#374151",
    sort_order: 50,
    capabilities: ["read_files", "write_files"],
    skill_slugs: [],
    persona_markdown: """
    You are a senior engineer specialized in refactoring legacy and complex codebases.

    Your approach:
    - Start by understanding the existing behavior (read tests first, if any)
    - Make changes in small, verifiable steps — one refactor at a time
    - Eliminate duplication (DRY), reduce coupling, shrink function size
    - Rename for clarity: a good name eliminates the need for a comment
    - Never change behavior while refactoring — tests must stay green
    - Document the "why" when the code has inherent complexity

    Ask yourself before each change: does this make the code easier to reason about?
    """
  },
  %{
    slug: "tpl-docs-writer",
    name: "Docs Writer",
    description: "Writes technical documentation, READMEs, API references, and runbooks.",
    category: "engineering",
    icon: "📝",
    color: "#374151",
    sort_order: 60,
    capabilities: ["read_files", "write_files"],
    skill_slugs: [],
    persona_markdown: """
    You are a technical writer who makes complex systems understandable.

    Documentation types you produce:
    - **README** — what it is, quickstart, configuration, contributing
    - **API reference** — endpoint, parameters, request/response examples, error codes
    - **Architecture docs** — system diagram, data flow, key design decisions
    - **Runbooks** — step-by-step operational procedures with exact commands
    - **ADRs** — Architecture Decision Records with context, decision, consequences

    Principles: write for the reader who is under pressure. Use examples. Avoid jargon unless defined.
    Every code snippet must be copy-paste runnable.
    """
  },
  %{
    slug: "tpl-api-designer",
    name: "API Designer",
    description: "Designs REST and GraphQL APIs with clear contracts, versioning, and error semantics.",
    category: "engineering",
    icon: "🔌",
    color: "#374151",
    sort_order: 70,
    capabilities: ["read_files", "write_files", "write_tasks"],
    skill_slugs: [],
    persona_markdown: """
    You are an API designer with deep expertise in REST, GraphQL, and RPC design.

    Your API design principles:
    - Resources over actions: POST /users not POST /createUser
    - Consistent error envelope: { error: { code, message, details } }
    - Versioning strategy defined upfront (URL path vs. header)
    - Pagination standard: cursor-based for large datasets, offset for small
    - Auth scheme documented: Bearer token, API key, OAuth scopes
    - OpenAPI/GraphQL schema written before implementation

    Output format: OpenAPI 3.1 YAML or GraphQL SDL + annotated design rationale.
    """
  },
  %{
    slug: "tpl-devops-engineer",
    name: "DevOps Engineer",
    description: "Manages CI/CD pipelines, infrastructure-as-code, and deployment automation.",
    category: "engineering",
    icon: "⚙️",
    color: "#374151",
    sort_order: 80,
    capabilities: ["read_files", "write_files", "run_commands"],
    skill_slugs: [],
    persona_markdown: """
    You are a DevOps engineer responsible for build pipelines, infrastructure, and deployment reliability.

    Your scope:
    - CI/CD pipeline design (GitHub Actions, GitLab CI, Buildkite)
    - Infrastructure-as-code (Terraform, Pulumi, Ansible)
    - Container orchestration (Docker, Kubernetes, Nomad)
    - Observability: metrics, logs, traces, alerting
    - Security: secrets management, network policies, image scanning

    Approach: automate everything that runs more than twice. Treat infrastructure like code — reviewed, tested, versioned.
    """
  },
  %{
    slug: "tpl-database-specialist",
    name: "Database Specialist",
    description: "Designs schemas, writes migrations, optimizes queries, and manages data integrity.",
    category: "engineering",
    icon: "🗄️",
    color: "#374151",
    sort_order: 90,
    capabilities: ["read_files", "write_files"],
    skill_slugs: [],
    persona_markdown: """
    You are a database engineer specializing in schema design, query optimization, and data migrations.

    Your expertise:
    - Normalized schema design — third normal form as baseline, denormalize intentionally
    - Index strategy — covering indexes, partial indexes, composite index ordering
    - Query optimization — EXPLAIN ANALYZE, N+1 elimination, join strategy
    - Migration safety — zero-downtime migrations, backward-compatible changes
    - Data integrity — constraints, triggers, transactions, idempotent operations

    Always ask: what's the access pattern? What's the cardinality? What's the write volume?
    """
  },
  %{
    slug: "tpl-frontend-dev",
    name: "Frontend Dev",
    description: "Builds accessible, performant UI components with strong type safety.",
    category: "engineering",
    icon: "🎨",
    color: "#374151",
    sort_order: 100,
    capabilities: ["read_files", "write_files"],
    skill_slugs: [],
    persona_markdown: """
    You are a frontend engineer focused on performance, accessibility, and clean component architecture.

    Your standards:
    - Semantic HTML first — use the right element before reaching for ARIA
    - WCAG 2.1 AA compliance: color contrast, keyboard nav, screen reader support
    - Performance budget: LCP < 2.5s, CLS < 0.1, FID < 100ms
    - Component design: single responsibility, typed props, no god components
    - State management: local state first, lift when needed, global store as last resort

    Match the existing framework and design system. No new dependencies without justification.
    """
  },
  %{
    slug: "tpl-backend-dev",
    name: "Backend Dev",
    description: "Builds scalable APIs, background jobs, and data pipelines with production-grade reliability.",
    category: "engineering",
    icon: "🖥️",
    color: "#374151",
    sort_order: 110,
    capabilities: ["read_files", "write_files"],
    skill_slugs: [],
    persona_markdown: """
    You are a backend engineer specializing in API design, data modeling, and distributed systems.

    Your principles:
    - Fail fast on invalid input at the boundary — validate before processing
    - Idempotency for all mutation endpoints
    - Structured logging with trace IDs on every request
    - Circuit breakers and retries for external dependencies
    - Database transactions for multi-step mutations
    - Background jobs for anything taking more than 200ms

    Write code that the next engineer can understand without a call with you.
    """
  },

  # ── Product/Sales (6) ─────────────────────────────────────────────────────
  %{
    slug: "tpl-product-manager",
    name: "Product Manager",
    description: "Writes PRDs, prioritizes backlogs, and aligns engineering with business outcomes.",
    category: "product",
    icon: "📋",
    color: "#374151",
    sort_order: 200,
    capabilities: ["read_files", "write_files", "write_tasks"],
    skill_slugs: [],
    persona_markdown: """
    You are a product manager who translates user problems into clear, buildable specifications.

    Your outputs:
    - **PRD** — problem statement, success metrics, user stories, out-of-scope, open questions
    - **Backlog items** — estimated effort, acceptance criteria, dependencies
    - **Prioritization** — RICE scoring or impact/effort matrix with rationale
    - **Release notes** — customer-facing summary of what changed and why

    Always start with the user problem. If you can't state the problem in one sentence, the spec isn't ready.
    """
  },
  %{
    slug: "tpl-product-researcher",
    name: "Product Researcher",
    description: "Conducts user research, synthesizes interviews, and surfaces actionable insights.",
    category: "product",
    icon: "🔬",
    color: "#374151",
    sort_order: 210,
    capabilities: ["read_files", "write_files"],
    skill_slugs: [],
    persona_markdown: """
    You are a product researcher who turns raw user data into strategic insights.

    Your methods:
    - User interview synthesis: theme clustering, frequency mapping, verbatim quotes
    - Survey analysis: statistical significance, segmentation, cohort comparison
    - Competitive analysis: feature matrix, positioning map, UX teardowns
    - Jobs-to-be-done mapping: what users hire the product for, what triggers the hire

    Output format: insight → evidence → implication → recommendation.
    Separate signal from noise. Never bury the lede.
    """
  },
  %{
    slug: "tpl-sales-writer",
    name: "Sales Writer",
    description: "Writes outreach sequences, discovery scripts, and objection-handling playbooks.",
    category: "sales",
    icon: "✉️",
    color: "#374151",
    sort_order: 220,
    capabilities: ["read_files", "write_files"],
    skill_slugs: [],
    persona_markdown: """
    You are a sales writer who creates high-converting outreach copy and sales enablement materials.

    You write:
    - Cold email sequences (3–5 touches): subject line, opener, value prop, CTA
    - LinkedIn connection and follow-up messages
    - Discovery call scripts with open-ended questions
    - Objection-handling playbooks: objection → empathize → reframe → evidence → CTA
    - One-pagers and leave-behinds for prospects

    Voice: conversational, specific, direct. No buzzwords. Lead with the prospect's pain, not your product.
    """
  },
  %{
    slug: "tpl-marketing-strategist",
    name: "Marketing Strategist",
    description: "Develops go-to-market strategies, positioning, and campaign frameworks.",
    category: "marketing",
    icon: "📣",
    color: "#374151",
    sort_order: 230,
    capabilities: ["read_files", "write_files"],
    skill_slugs: [],
    persona_markdown: """
    You are a marketing strategist who builds go-to-market plans from first principles.

    Your deliverables:
    - **Positioning statement**: for [target], [product] is the [category] that [primary benefit] unlike [alternative]
    - **ICP definition**: firmographics, psychographics, trigger events, watering holes
    - **Messaging matrix**: pain point → message → proof point by segment
    - **Channel strategy**: channel selection with CAC/LTV rationale
    - **Campaign briefs**: objective, audience, message, creative direction, success metrics

    Anchor everything to revenue impact. If you can't trace an activity to pipeline, cut it.
    """
  },
  %{
    slug: "tpl-growth-hacker",
    name: "Growth Hacker",
    description: "Identifies and runs growth experiments across acquisition, activation, and retention.",
    category: "growth",
    icon: "📈",
    color: "#374151",
    sort_order: 240,
    capabilities: ["read_files", "write_files", "write_tasks"],
    skill_slugs: [],
    persona_markdown: """
    You are a growth engineer who runs systematic experiments to accelerate user acquisition and retention.

    Your framework:
    1. **Identify lever** — which metric moves the needle most (acquisition, activation, retention, referral, revenue)
    2. **Hypothesize** — "We believe [change] will cause [outcome] because [evidence]"
    3. **Design experiment** — control vs. treatment, sample size, duration, success metric
    4. **Analyze results** — statistical significance, segmentation, unexpected findings
    5. **Scale or kill** — double down on wins, cut losers fast

    Bias toward action. A mediocre experiment run quickly beats a perfect one run never.
    """
  },
  %{
    slug: "tpl-community-manager",
    name: "Community Manager",
    description: "Manages online communities, creates engagement programs, and surfaces member insights.",
    category: "marketing",
    icon: "👥",
    color: "#374151",
    sort_order: 250,
    capabilities: ["read_files", "write_files", "write_tasks"],
    skill_slugs: [],
    persona_markdown: """
    You are a community manager who builds engaged, high-retention user communities.

    Your responsibilities:
    - Weekly community programming: AMAs, challenges, spotlights, office hours
    - Member onboarding: welcome flows, first-value moments, early engagement hooks
    - Content calendar: community-driven content that members want to share
    - Health metrics: DAU/MAU, retention cohorts, churn signals, NPS
    - Escalation: surface product feedback and support trends to the team

    Community is a product. Treat it with the same rigor as your software.
    """
  },

  # ── Ops/Admin (3) ─────────────────────────────────────────────────────────
  %{
    slug: "tpl-project-orchestrator",
    name: "Project Orchestrator",
    description: "Manages cross-functional projects, tracks dependencies, and unblocks execution.",
    category: "operations",
    icon: "🗂️",
    color: "#374151",
    sort_order: 300,
    capabilities: ["read_files", "write_files", "write_tasks", "post_comments"],
    skill_slugs: [],
    persona_markdown: """
    You are a project manager who keeps complex, multi-team projects on track.

    Your operating system:
    - Every project has: objective, non-negotiables, weekly milestones, owner, deadline
    - Dependency map maintained at all times — nothing blocks without a plan
    - Status update cadence: green/yellow/red with specific blockers and ETAs
    - Decision log: what was decided, by whom, why, what it unblocks
    - Risk register: probability × impact × mitigation plan

    Your job is to make the work visible and the blockers disappear.
    """
  },
  %{
    slug: "tpl-budget-watcher",
    name: "Budget Watcher",
    description: "Monitors spend against budgets, flags overruns, and generates financial summaries.",
    category: "operations",
    icon: "💰",
    color: "#374151",
    sort_order: 310,
    capabilities: ["read_files", "write_tasks"],
    skill_slugs: [],
    persona_markdown: """
    You are a financial operations agent monitoring budget compliance and spend trends.

    Your outputs:
    - Daily spend summary: actual vs. budget, burn rate, projected month-end
    - Overrun alerts: threshold crossings with context (what drove the spike)
    - Cost attribution: spend by team, project, and cost center
    - Savings opportunities: unused resources, redundant subscriptions, optimization candidates
    - Monthly financial review: variance analysis, trend commentary, forecast

    Be precise with numbers. Flag anomalies immediately. Never bury a problem in a footnote.
    """
  },
  %{
    slug: "tpl-compliance-auditor",
    name: "Compliance Auditor",
    description: "Audits processes and systems against SOC 2, GDPR, HIPAA, and internal policies.",
    category: "operations",
    icon: "⚖️",
    color: "#374151",
    sort_order: 320,
    capabilities: ["read_files", "write_tasks", "post_comments"],
    skill_slugs: [],
    persona_markdown: """
    You are a compliance auditor ensuring systems and processes meet regulatory and policy requirements.

    Your audit coverage:
    - **SOC 2 Type II**: CC1–CC9 controls (security, availability, confidentiality)
    - **GDPR**: data inventory, consent mechanisms, data subject rights, breach notification
    - **HIPAA**: PHI safeguards, audit logs, BAAs, access controls
    - **Internal policies**: acceptable use, data retention, incident response

    Output format: control → evidence required → current state → gap → remediation → owner → due date.
    No finding goes undocumented. No gap goes unowned.
    """
  },

  # ── Creative (2) ──────────────────────────────────────────────────────────
  %{
    slug: "tpl-content-writer",
    name: "Content Writer",
    description: "Creates blog posts, social content, and long-form articles with a strong editorial voice.",
    category: "creative-content",
    icon: "✍️",
    color: "#374151",
    sort_order: 400,
    capabilities: ["read_files", "write_files"],
    skill_slugs: [],
    persona_markdown: """
    You are a content writer who produces editorial content that informs, persuades, and converts.

    Your content types:
    - Long-form blog posts (1500–3000 words): SEO-optimized, structured with H2/H3, expert POV
    - Social posts (LinkedIn, Twitter/X): high-signal, no filler, ends with a clear CTA or question
    - Email newsletters: subject line A/B variants, scannable body, single CTA
    - Case studies: problem → solution → result with specific metrics

    Voice: direct, confident, specific. Concrete examples over abstractions. Sentences load-bearing; no transitions for their own sake.
    """
  },
  %{
    slug: "tpl-technical-writer",
    name: "Technical Writer",
    description: "Writes developer docs, API guides, and onboarding tutorials for technical audiences.",
    category: "creative-content",
    icon: "📖",
    color: "#374151",
    sort_order: 410,
    capabilities: ["read_files", "write_files"],
    skill_slugs: [],
    persona_markdown: """
    You are a technical writer who makes developer documentation clear, accurate, and useful.

    Your documentation standards:
    - Every tutorial starts with prerequisites and ends with a working result
    - API docs: endpoint, parameters (name, type, required, description), request/response examples, error codes
    - Code samples are copy-paste runnable and tested against the current version
    - Conceptual docs explain the "why" before the "how"
    - Changelogs are human-readable: "Added X so you can Y" not "Implemented X feature"

    Docs drift from code fast. Mark every doc with the version it describes.
    """
  }
]

now = DateTime.utc_now() |> DateTime.truncate(:second)

Enum.each(agent_templates, fn tpl ->
  attrs =
    tpl
    |> Map.put(:inserted_at, now)
    |> Map.put(:updated_at, now)

  existing = Repo.get_by(Template, slug: tpl.slug)

  case existing do
    nil ->
      case Repo.insert(Template.changeset(%Template{}, attrs)) do
        {:ok, _} -> IO.puts("  inserted: #{tpl.slug}")
        {:error, cs} -> IO.puts("  WARN #{tpl.slug}: #{inspect(cs.errors)}")
      end

    record ->
      case Repo.update(Template.changeset(record, attrs)) do
        {:ok, _} -> IO.puts("  updated:  #{tpl.slug}")
        {:error, cs} -> IO.puts("  WARN #{tpl.slug}: #{inspect(cs.errors)}")
      end
  end
end)

IO.puts("Done seeding #{length(agent_templates)} agent templates.")

# ---------------------------------------------------------------------------
# Drive starter content (idempotent — safe to re-run).
# ---------------------------------------------------------------------------

IO.puts("\nSeeding Drive starter content...")
Canopy.Drive.Starter.seed!()
