defmodule CanopyWeb.AgentKanbanController do
  @moduledoc """
  HTTP API for the Agent Kanban board.

  All operations route through `Canopy.Tasks` / `Canopy.Tasks.Kanban` —
  controllers never touch `Canopy.Repo` directly.

  Routes:

      GET  /api/v1/agent-kanban/board
        ?workspace_slug=<slug>            — full 4-column board
      POST /api/v1/agent-kanban/claim     — manual claim
      POST /api/v1/agent-kanban/release/:task_id
      POST /api/v1/agent-kanban/complete/:task_id
      GET  /api/v1/agent-kanban/idle-agents — agents with auto-pickup on
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Agents
  alias Canopy.Agents.Agent
  alias Canopy.Repo
  alias Canopy.Sessions.Session
  alias Canopy.Tasks.Kanban
  alias CanopyWeb.Schemas.AgentKanbanSchema

  import Ecto.Query, only: [from: 2]

  action_fallback CanopyWeb.FallbackController

  tags ["agent-kanban"]

  # ---------------------------------------------------------------------------
  # GET /agent-kanban/board
  # ---------------------------------------------------------------------------

  operation :board,
    summary: "Get the full agent-kanban board",
    parameters: [
      workspace_slug: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [
      ok: {"Board", "application/json", AgentKanbanSchema.BoardResponse}
    ]

  @spec board(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def board(conn, params) do
    opts =
      []
      |> maybe_opt(:workspace_slug, params["workspace_slug"])
      |> maybe_opt(:limit, parse_int(params["limit"]))

    json(conn, %{data: Kanban.board(opts)})
  end

  # ---------------------------------------------------------------------------
  # POST /agent-kanban/claim
  # ---------------------------------------------------------------------------

  operation :claim,
    summary: "Manually claim a task for an agent",
    request_body: {"Claim params", "application/json", AgentKanbanSchema.ClaimRequest},
    responses: [
      ok: {"Claimed task", "application/json", AgentKanbanSchema.TaskResponse},
      conflict: {"Already claimed", "application/json", AgentKanbanSchema.ErrorResponse},
      not_found: {"Not found", "application/json", AgentKanbanSchema.ErrorResponse},
      unprocessable_entity: {"Validation", "application/json", AgentKanbanSchema.ErrorResponse}
    ]

  @spec claim(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def claim(conn, %{"agent_slug" => agent_slug, "task_id" => task_id})
      when is_binary(agent_slug) and is_binary(task_id) do
    case Kanban.claim_task(task_id, agent_slug) do
      {:ok, task} ->
        json(conn, %{data: task})

      {:error, :already_claimed} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "already_claimed", message: "Task is already claimed by another agent"})

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  def claim(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_params", message: "agent_slug and task_id are required"})
  end

  # ---------------------------------------------------------------------------
  # POST /agent-kanban/release/:task_id
  # ---------------------------------------------------------------------------

  operation :release,
    summary: "Release a task back to the Backlog column",
    parameters: [task_id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Released task", "application/json", AgentKanbanSchema.TaskResponse},
      not_found: {"Not found", "application/json", AgentKanbanSchema.ErrorResponse}
    ]

  @spec release(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def release(conn, %{"task_id" => task_id}) do
    with {:ok, task} <- Kanban.release_task(task_id) do
      json(conn, %{data: task})
    end
  end

  # ---------------------------------------------------------------------------
  # POST /agent-kanban/complete/:task_id
  # ---------------------------------------------------------------------------

  operation :complete,
    summary: "Mark a task done and record the producing session",
    parameters: [task_id: [in: :path, type: :string, required: true]],
    request_body:
      {"Complete params (optional)", "application/json", AgentKanbanSchema.CompleteRequest,
       required: false},
    responses: [
      ok: {"Completed task", "application/json", AgentKanbanSchema.TaskResponse},
      not_found: {"Not found", "application/json", AgentKanbanSchema.ErrorResponse}
    ]

  @spec complete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def complete(conn, %{"task_id" => task_id} = params) do
    session_id = params["session_id"]

    with {:ok, task} <- Kanban.complete_task(task_id, session_id) do
      json(conn, %{data: task})
    end
  end

  # ---------------------------------------------------------------------------
  # GET /agent-kanban/idle-agents
  # ---------------------------------------------------------------------------

  operation :idle_agents,
    summary: "List hired agents with auto-pickup enabled",
    responses: [
      ok: {"Idle agents", "application/json", AgentKanbanSchema.IdleAgentsResponse}
    ]

  @spec idle_agents(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def idle_agents(conn, _params) do
    {:ok, agents} = Agents.list_hired()

    rows =
      agents
      |> Enum.filter(&auto_pickup_enabled?/1)
      |> Enum.map(&serialize_idle_agent/1)

    json(conn, %{data: rows, count: length(rows)})
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec serialize_idle_agent(Agent.t()) :: map()
  defp serialize_idle_agent(%Agent{} = agent) do
    %{
      slug: agent.slug,
      name: agent.name,
      category: agent.category,
      capabilities: capabilities(agent),
      active_session_count: active_session_count(agent.slug),
      auto_pickup_enabled: true
    }
  end

  defp capabilities(%Agent{config: cfg}) when is_map(cfg) do
    case Map.get(cfg, "capabilities") do
      list when is_list(list) -> Enum.filter(list, &is_binary/1)
      _ -> []
    end
  end

  defp capabilities(_), do: []

  defp auto_pickup_enabled?(%Agent{config: cfg}) when is_map(cfg) do
    Map.get(cfg, "auto_pickup") in [true, "true"]
  end

  defp auto_pickup_enabled?(_), do: false

  defp active_session_count(agent_slug) do
    Repo.aggregate(
      from(s in Session,
        where: s.agent_slug == ^agent_slug and s.status in ["pending", "running"]
      ),
      :count,
      :id
    )
  end

  defp maybe_opt(opts, _key, nil), do: opts
  defp maybe_opt(opts, _key, ""), do: opts
  defp maybe_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(v) when is_integer(v), do: v

  defp parse_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_int(_), do: nil
end
