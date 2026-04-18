defmodule CanopyWeb.AgentsController do
  @moduledoc """
  HTTP API for Canopy agent personas.

  Routes:
    GET    /api/v1/agents             — list agents (optional ?hired=true|false filter)
    GET    /api/v1/agents/:slug       — get agent detail with persona markdown
    POST   /api/v1/agents/:slug/hire  — hire an agent (hired: true)
    DELETE /api/v1/agents/:slug/hire  — fire an agent (hired: false)
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Agents
  alias CanopyWeb.Schemas.AgentSchema

  action_fallback CanopyWeb.FallbackController

  tags ["agents"]

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
    {:ok, agents} = Agents.list(hired: hired_filter)
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
      persona_content = read_persona(agent.persona_path)

      body =
        agent
        |> Map.from_struct()
        |> Map.drop([:__meta__])
        |> Map.put(:persona_content, persona_content)

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

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec parse_hired_filter(String.t() | nil) :: boolean() | nil
  defp parse_hired_filter("true"), do: true
  defp parse_hired_filter("false"), do: false
  defp parse_hired_filter(_other), do: nil

  @spec read_persona(String.t() | nil) :: String.t() | nil
  defp read_persona(nil), do: nil

  defp read_persona(relative_path) do
    path = Path.join(:code.priv_dir(:canopy), Path.join("agents", relative_path))

    case File.read(path) do
      {:ok, content} -> content
      {:error, _reason} -> nil
    end
  end
end
