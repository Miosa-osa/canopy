defmodule CanopyWeb.AgentSkillsController do
  @moduledoc """
  HTTP API for agent ↔ skill assignments.

  Routes:
    GET    /api/v1/agents/:slug/skills             — list assigned skills with joined skill data
    POST   /api/v1/agents/:slug/skills             — assign a skill {skill_slug, priority?}
    DELETE /api/v1/agents/:slug/skills/:skill_slug — remove an assignment
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Agents
  alias Canopy.Skills
  alias CanopyWeb.Schemas.RuntimeSchema
  alias CanopyWeb.Schemas.SkillSchema

  action_fallback CanopyWeb.FallbackController

  tags ["agents", "skills"]

  operation :index,
    summary: "List skill assignments for an agent",
    description: "Returns all skill assignments for the given agent, with joined skill data.",
    parameters: [
      slug: [in: :path, description: "Agent slug", type: :string, required: true]
    ],
    responses: [
      ok: {"Assignment list", "application/json", SkillSchema.AgentSkillAssignmentList},
      not_found: {"Not found", "application/json", RuntimeSchema.ErrorResponse}
    ]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, %{"slug" => agent_slug}) do
    with {:ok, _agent} <- Agents.get_by_slug(agent_slug),
         {:ok, assignments} <- Skills.list_assignments(agent_slug) do
      json(conn, %{data: assignments})
    end
  end

  operation :create,
    summary: "Assign a skill to an agent",
    description: """
    Assigns the specified skill to the agent. If already assigned, returns 422 with
    a 'skill already assigned to this agent' message.
    """,
    parameters: [
      slug: [in: :path, description: "Agent slug", type: :string, required: true]
    ],
    request_body:
      {"Assign request", "application/json", SkillSchema.AssignSkillRequest, required: true},
    responses: [
      created: {"Created assignment", "application/json", SkillSchema.AgentSkillAssignment},
      not_found: {"Agent not found", "application/json", RuntimeSchema.ErrorResponse},
      unprocessable_entity:
        {"Already assigned or invalid", "application/json", RuntimeSchema.ErrorResponse}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"slug" => agent_slug, "skill_slug" => skill_slug} = params) do
    priority = Map.get(params, "priority", 0)

    with {:ok, _agent} <- Agents.get_by_slug(agent_slug),
         {:ok, _skill} <- Skills.get_by_slug(skill_slug),
         {:ok, assignment} <- Skills.assign(agent_slug, skill_slug, priority: priority) do
      conn
      |> put_status(:created)
      |> json(assignment)
    end
  end

  def create(conn, %{"slug" => _}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "missing_skill_slug", message: "skill_slug is required"})
  end

  operation :delete,
    summary: "Remove a skill assignment from an agent",
    description: "Removes the skill assignment. Returns 404 if the assignment does not exist.",
    parameters: [
      slug: [in: :path, description: "Agent slug", type: :string, required: true],
      skill_slug: [in: :path, description: "Skill slug", type: :string, required: true]
    ],
    responses: [
      no_content: "Assignment removed",
      not_found: {"Not found", "application/json", RuntimeSchema.ErrorResponse}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"slug" => agent_slug, "skill_slug" => skill_slug}) do
    with {:ok, _} <- Skills.unassign(agent_slug, skill_slug) do
      send_resp(conn, :no_content, "")
    end
  end
end
