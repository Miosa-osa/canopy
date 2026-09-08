defmodule Canopy.Build.Commands do
  @moduledoc """
  Multi-source slash-command registry for the Build cockpit.

  The Build composer's slash palette pulls commands from five disjoint sources
  and serves them in one normalized shape:

    * `:builtin` — the canonical 10 commands the cockpit ships with.
    * `:runtime` — one command per registered runtime adapter (`/claude`,
      `/codex`, `/gemini`, ...). Spawns the runtime in the active pane.
    * `:drive_workflow` / `:drive_prompt` — Drive entries the user has saved.
    * `:template` — `kind: "workflow"` templates the user can instantiate.
      Workspace and persona templates are skipped — too heavyweight for a
      slash command.
    * `:skill` — enabled skills the user can attach to a conversation.

  The aggregator normalizes every source into the shape:

      %{
        namespace: "build" | "runtimes" | "drive" | "templates" | "skills",
        name: "/<slug>",
        description: "...",
        icon: "Bot" | "FileText" | "GitCommit" | ...,  # lucide-svelte name
        source: "builtin" | "runtime" | "drive_workflow" | "drive_prompt"
              | "template" | "skill",
        source_id: "<id-or-slug>" | nil
      }

  ## Source order (deterministic — frontend groups on this)

      builtin → runtime → drive_workflow → drive_prompt → template → skill

  ## Filtering

  `list/1` takes `:q` (substring on name + description, case-insensitive) and
  `:limit` (capped at 200). Each source is fetched once; filtering is applied
  to the merged list so a `?q=` substring against `description` of one source
  doesn't starve another.

  ## Why a context module (and not just a controller)

  Conductor's tool surface (`build.list_commands` — added later) and the
  HTTP endpoint (`GET /api/v1/build/commands`) both want the same aggregator.
  Keeping it in the context keeps the controller thin and lets tools call it
  directly without round-tripping through the router.
  """

  alias Canopy.Drive
  alias Canopy.Runtimes
  alias Canopy.Skills
  alias Canopy.Templates

  @max_limit 200
  @default_limit 200

  # Canonical 10 built-ins — mirrors the original
  # `desktop/src/lib/design/patterns/build/SlashCommands.svelte` array. Adding
  # a new built-in here automatically lights it up in the palette.
  @builtins [
    %{name: "agent", description: "Start a new conversation", icon: "Bot"},
    %{name: "plan", description: "Prompt the agent to do some research", icon: "Sparkles"},
    %{
      name: "open-file",
      description: "Open a file in the workspace's code editor",
      icon: "FileText"
    },
    %{name: "conversations", description: "Open conversation history", icon: "History"},
    %{name: "prompts", description: "Search saved prompts", icon: "Wand2"},
    %{name: "add-prompt", description: "Add new agent prompt", icon: "Plus"},
    %{name: "add-rule", description: "Add a new global rule for the agent", icon: "BookOpen"},
    %{name: "add-mcp", description: "Add new MCP server", icon: "Plug"},
    %{name: "create-environment", description: "Create a sandbox environment", icon: "GitBranch"},
    %{name: "review", description: "Open code review", icon: "MessageCircle"}
  ]

  @typedoc """
  Normalized command shape. `name` includes the leading slash so the frontend
  can render and dispatch without further synthesis.
  """
  @type command :: %{
          namespace: String.t(),
          name: String.t(),
          description: String.t(),
          icon: String.t(),
          source: String.t(),
          source_id: String.t() | nil
        }

  @doc """
  Aggregates commands from all sources, optionally filtered by a substring
  query. Returns a list of normalized command maps.

  Options:
    * `:q` — substring (case-insensitive) matched against name + description.
      `nil` / `""` returns everything.
    * `:limit` — caps the result; default 200, hard max 200.
  """
  @spec list(keyword()) :: [command()]
  def list(opts \\ []) do
    q = opts |> Keyword.get(:q) |> normalize_query()
    limit = opts |> Keyword.get(:limit, @default_limit) |> clamp_limit()

    [
      builtin_commands(),
      runtime_commands(),
      drive_commands("workflow"),
      drive_commands("prompt"),
      template_commands(),
      skill_commands()
    ]
    |> Enum.concat()
    |> filter_by_query(q)
    |> Enum.take(limit)
  end

  # ---------------------------------------------------------------------------
  # Source: built-ins
  # ---------------------------------------------------------------------------

  @spec builtin_commands() :: [command()]
  defp builtin_commands do
    Enum.map(@builtins, fn %{name: name, description: desc, icon: icon} ->
      %{
        namespace: "build",
        name: "/" <> name,
        description: desc,
        icon: icon,
        source: "builtin",
        source_id: nil
      }
    end)
  end

  # ---------------------------------------------------------------------------
  # Source: runtime adapters
  # ---------------------------------------------------------------------------

  # We synthesize a friendly slash-command for each registered adapter using
  # its `type/0` callback. `claude-local` → `/claude` (drop the `-local`
  # suffix when present so the user types the short form).
  @spec runtime_commands() :: [command()]
  defp runtime_commands do
    Runtimes.list_adapters()
    |> Enum.map(fn mod ->
      type = mod.type()
      slash_name = type |> String.split("-") |> List.first()

      %{
        namespace: "runtimes",
        name: "/" <> slash_name,
        description: "Spawn #{format_runtime_name(type)} in this pane",
        icon: "Bot",
        source: "runtime",
        source_id: type
      }
    end)
  rescue
    # Defensive: registry not booted in some contexts (e.g. unit tests that
    # didn't start it). Don't blow up the whole palette.
    _ -> []
  end

  # ---------------------------------------------------------------------------
  # Source: Drive entries (workflows + prompts)
  # ---------------------------------------------------------------------------

  @spec drive_commands(String.t()) :: [command()]
  defp drive_commands(kind) when kind in ["workflow", "prompt"] do
    Drive.list(kind: kind, archived: false, limit: @max_limit)
    |> Enum.map(fn entry ->
      %{
        namespace: "drive",
        name: "/" <> entry.slug,
        description: entry.name || entry.slug,
        icon: drive_icon(kind),
        source: "drive_" <> kind,
        source_id: entry.id
      }
    end)
  end

  defp drive_icon("workflow"), do: "GitCommit"
  defp drive_icon("prompt"), do: "Wand2"

  # ---------------------------------------------------------------------------
  # Source: Templates (workflow kind only — workspace/persona are too
  # heavyweight to instantiate from a slash palette)
  # ---------------------------------------------------------------------------

  @spec template_commands() :: [command()]
  defp template_commands do
    Templates.list_templates(kind: "workflow", limit: @max_limit)
    |> Enum.map(fn t ->
      %{
        namespace: "templates",
        name: "/" <> t.slug,
        description: t.description || "Instantiate #{t.name}",
        icon: "LayoutTemplate",
        source: "template",
        source_id: t.slug
      }
    end)
  end

  # ---------------------------------------------------------------------------
  # Source: Skills (enabled only)
  # ---------------------------------------------------------------------------

  @spec skill_commands() :: [command()]
  defp skill_commands do
    case Skills.list(enabled: true) do
      {:ok, skills} ->
        Enum.map(skills, fn s ->
          %{
            namespace: "skills",
            name: "/use-" <> s.slug,
            description: s.description || "Apply #{s.name} skill to this conversation",
            icon: "Zap",
            source: "skill",
            source_id: s.slug
          }
        end)

      _ ->
        []
    end
  end

  # ---------------------------------------------------------------------------
  # Filtering
  # ---------------------------------------------------------------------------

  defp normalize_query(nil), do: nil
  defp normalize_query(""), do: nil

  defp normalize_query(s) when is_binary(s) do
    s
    |> String.trim()
    |> String.downcase()
    |> case do
      "" -> nil
      v -> v
    end
  end

  defp filter_by_query(commands, nil), do: commands

  defp filter_by_query(commands, needle) do
    Enum.filter(commands, fn cmd ->
      name_match? = String.contains?(String.downcase(cmd.name), needle)
      desc_match? = String.contains?(String.downcase(cmd.description || ""), needle)
      name_match? or desc_match?
    end)
  end

  defp clamp_limit(n) when is_integer(n) and n > 0, do: min(n, @max_limit)
  defp clamp_limit(_), do: @default_limit

  # ---------------------------------------------------------------------------
  # Display helpers
  # ---------------------------------------------------------------------------

  # claude-local → "Claude Code"
  # codex-local  → "Codex Local"
  # gemini-local → "Gemini Local"
  defp format_runtime_name("claude-local"), do: "Claude Code"
  defp format_runtime_name("codex-local"), do: "Codex"
  defp format_runtime_name("gemini-local"), do: "Gemini"

  defp format_runtime_name(type) when is_binary(type) do
    type
    |> String.split("-")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
