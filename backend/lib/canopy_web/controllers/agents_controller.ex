defmodule CanopyWeb.AgentsController do
  @moduledoc """
  HTTP API for Canopy agent personas.

  Routes:
    POST   /api/v1/agents                    — create a user-defined agent (hired: true)
    GET    /api/v1/agents                    — list agents (optional ?hired=true|false filter)
    GET    /api/v1/agents/:slug              — get agent detail with persona markdown
    PUT    /api/v1/agents/:slug/persona      — update persona markdown file
    POST   /api/v1/agents/:slug/hire         — hire an agent (hired: true)
    DELETE /api/v1/agents/:slug/hire         — fire an agent (hired: false)
    GET    /api/v1/agents/:slug/heartbeats   — list next scheduled heartbeat Oban jobs
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import Ecto.Query, only: [from: 2]

  alias Canopy.Agents
  alias Canopy.Repo
  alias CanopyWeb.Schemas.AgentSchema

  action_fallback CanopyWeb.FallbackController

  tags ["agents"]

  operation :create,
    summary: "Create a user-defined agent",
    description: """
    Creates a new agent from the supplied attributes and immediately hires it
    (hired: true) so it is available for use right away.

    The slug must be unique; a conflict returns 422 with changeset errors.
    If `persona_path` is not supplied it defaults to `"user/{slug}.md"`.
    """,
    request_body:
      {"Create agent", "application/json", AgentSchema.CreateAgentRequest, required: true},
    responses: [
      created: {"Created agent", "application/json", AgentSchema.AgentDetail},
      unprocessable_entity:
        {"Validation failure", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    slug = Map.get(params, "slug", "")

    attrs =
      params
      |> Map.put_new("persona_path", "user/#{slug}.md")

    with {:ok, agent} <- Agents.create(attrs) do
      body =
        agent
        |> Map.from_struct()
        |> Map.drop([:__meta__])
        |> Map.put(:persona_content, agent.persona_markdown)

      conn
      |> put_status(:created)
      |> json(body)
    end
  end

  operation :sync_workspace,
    summary: "Sync workspace-local agents",
    description: "Imports `.canopy/agents/**/*.md` from a workspace into runtime agent rows.",
    parameters: [
      workspace_slug: [in: :path, description: "Workspace slug", type: :string, required: true]
    ],
    responses: [
      ok: {"Sync result", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found:
        {"Workspace not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec sync_workspace(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def sync_workspace(conn, %{"workspace_slug" => workspace_slug}) do
    with {:ok, result} <- Agents.sync_workspace(workspace_slug) do
      json(conn, %{data: result})
    end
  end

  operation :index,
    summary: "List agents",
    description: "Returns all agents. Pass ?hired=true to filter to hired agents only.",
    parameters: [
      hired: [
        in: :query,
        description: "Filter by hired status. true | false | omit for all.",
        type: :string,
        required: false
      ]
    ],
    responses: [
      ok: {"Agent list", "application/json", AgentSchema.AgentList}
    ]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    hired_filter = parse_hired_filter(Map.get(params, "hired"))

    opts =
      []
      |> maybe_put(:hired, hired_filter)
      |> maybe_put(:category, Map.get(params, "category"))
      |> maybe_put(:query, Map.get(params, "q"))

    {:ok, agents} = Agents.list(opts)
    json(conn, %{data: agents})
  end

  operation :show,
    summary: "Get agent detail",
    description: """
    Returns a single agent by slug, including the raw persona markdown content
    if the file exists under priv/agents/.
    """,
    parameters: [
      slug: [in: :path, description: "Agent slug", type: :string, required: true]
    ],
    responses: [
      ok: {"Agent detail", "application/json", AgentSchema.AgentDetail},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"slug" => slug}) do
    with {:ok, agent} <- Agents.get_by_slug(slug) do
      # Read persona_markdown from the DB row — no filesystem access at runtime.
      # persona_path is a backward reference to the seed source file only.
      persona_content =
        case agent.persona_markdown do
          nil -> nil
          "" -> nil
          content -> content
        end

      body =
        agent
        |> Map.from_struct()
        |> Map.drop([:__meta__])
        |> Map.put(:persona_content, persona_content)

      json(conn, body)
    end
  end

  operation :update_persona,
    summary: "Update agent persona markdown",
    description: """
    Overwrites the persona markdown file for the given agent slug.
    Returns the updated AgentDetail shape (with persona_content reflecting the new content).
    """,
    parameters: [
      slug: [in: :path, description: "Agent slug", type: :string, required: true]
    ],
    request_body:
      {"Persona markdown", "application/json", AgentSchema.UpdatePersonaRequest, required: true},
    responses: [
      ok: {"Updated agent detail", "application/json", AgentSchema.AgentDetail},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse},
      unprocessable_entity:
        {"Write failed", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec update_persona(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_persona(conn, %{"slug" => slug, "persona_markdown" => md}) do
    with {:ok, updated_agent} <- Agents.update_persona(slug, md) do
      # Return persona_content from the updated DB row — response shape unchanged.
      body =
        updated_agent
        |> Map.from_struct()
        |> Map.drop([:__meta__])
        |> Map.put(:persona_content, updated_agent.persona_markdown)

      json(conn, body)
    end
  end

  def update_persona(conn, %{"slug" => slug}) do
    with {:ok, updated_agent} <- Agents.update_persona(slug, "") do
      body =
        updated_agent
        |> Map.from_struct()
        |> Map.drop([:__meta__])
        |> Map.put(:persona_content, updated_agent.persona_markdown)

      json(conn, body)
    end
  end

  operation :hire,
    summary: "Hire an agent",
    description: "Sets hired: true for the given agent slug.",
    parameters: [
      slug: [in: :path, description: "Agent slug", type: :string, required: true]
    ],
    responses: [
      ok: {"Hired agent", "application/json", AgentSchema.HireResponse},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec hire(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def hire(conn, %{"slug" => slug}) do
    with {:ok, agent} <- Agents.hire(slug) do
      json(conn, %{data: agent})
    end
  end

  operation :fire,
    summary: "Fire an agent",
    description: "Sets hired: false for the given agent slug.",
    parameters: [
      slug: [in: :path, description: "Agent slug", type: :string, required: true]
    ],
    responses: [
      ok: {"Fired agent", "application/json", AgentSchema.HireResponse},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec fire(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def fire(conn, %{"slug" => slug}) do
    with {:ok, agent} <- Agents.fire(slug) do
      json(conn, %{data: agent})
    end
  end

  operation :heartbeats,
    summary: "List upcoming heartbeat jobs",
    description: """
    Returns the next scheduled Oban heartbeat jobs for the given agent slug.
    Only jobs in `scheduled` or `available` state are returned, ordered by
    `scheduled_at` ascending. Maximum 5 results.
    """,
    parameters: [
      slug: [in: :path, description: "Agent slug", type: :string, required: true]
    ],
    responses: [
      ok: {"Heartbeat list", "application/json", AgentSchema.HeartbeatList},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec heartbeats(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def heartbeats(conn, %{"slug" => slug}) do
    with {:ok, _agent} <- Agents.get_by_slug(slug) do
      jobs =
        Repo.all(
          from(j in Oban.Job,
            where:
              j.queue == "heartbeats" and
                j.state in ["scheduled", "available"] and
                fragment("?->>'agent_slug' = ?", j.args, ^slug),
            order_by: [asc: j.scheduled_at],
            limit: 5,
            select: %{
              id: j.id,
              state: j.state,
              scheduled_at: j.scheduled_at,
              args: j.args,
              attempt: j.attempt,
              max_attempts: j.max_attempts
            }
          )
        )

      json(conn, %{data: jobs})
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec parse_hired_filter(String.t() | nil) :: boolean() | nil
  defp parse_hired_filter("true"), do: true
  defp parse_hired_filter("false"), do: false
  defp parse_hired_filter(_other), do: nil

  @spec maybe_put(keyword(), atom(), term()) :: keyword()
  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
