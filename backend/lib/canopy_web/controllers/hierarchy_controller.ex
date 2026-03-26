defmodule CanopyWeb.HierarchyController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{Organization, Division, Department, Team, TeamMembership, Agent}
  import Ecto.Query

  @doc """
  GET /api/v1/hierarchy?organization_id=X

  Returns the full 5-layer organizational tree:
  Organization → Divisions → Departments → Teams → Agents

  Uses 4 flat queries grouped in Elixir (no recursive CTE — fixed depth).
  """
  def show(conn, params) do
    organization_id = params["organization_id"]

    cond do
      is_nil(organization_id) or organization_id == "" ->
        conn |> put_status(400) |> json(%{error: "organization_id is required"})

      true ->
        case Ecto.UUID.cast(organization_id) do
          :error ->
            conn |> put_status(400) |> json(%{error: "invalid organization_id format"})

          {:ok, uuid} ->
            case Repo.get(Organization, uuid) do
              nil ->
                conn |> put_status(404) |> json(%{error: "organization_not_found"})

              org ->
                render_hierarchy(conn, org)
            end
        end
    end
  end

  defp render_hierarchy(conn, org) do
    user_workspace_ids = conn.assigns[:user_workspace_ids] || []

    # 1. Fetch all divisions
    divisions =
      Repo.all(from d in Division, where: d.organization_id == ^org.id, order_by: [asc: d.name])

    division_ids = Enum.map(divisions, & &1.id)

    # 2. Fetch all departments in those divisions
    departments =
      if division_ids == [] do
        []
      else
        Repo.all(
          from d in Department, where: d.division_id in ^division_ids, order_by: [asc: d.name]
        )
      end

    department_ids = Enum.map(departments, & &1.id)

    # 3. Fetch all teams in those departments
    teams =
      if department_ids == [] do
        []
      else
        Repo.all(
          from t in Team, where: t.department_id in ^department_ids, order_by: [asc: t.name]
        )
      end

    team_ids = Enum.map(teams, & &1.id)

    # 4. Fetch all agents in those teams (via team_memberships) — filtered by workspace
    agent_memberships =
      if team_ids == [] do
        []
      else
        query =
          from tm in TeamMembership,
            join: a in Agent,
            on: tm.agent_id == a.id,
            where: tm.team_id in ^team_ids,
            order_by: [asc: a.name],
            select: %{
              team_id: tm.team_id,
              team_role: tm.role,
              id: a.id,
              name: a.name,
              slug: a.slug,
              role: a.role,
              status: a.status,
              adapter: a.adapter,
              model: a.model,
              avatar_emoji: a.avatar_emoji
            }

        query =
          if user_workspace_ids != [] do
            where(query, [_tm, a], a.workspace_id in ^user_workspace_ids)
          else
            query
          end

        Repo.all(query)
      end

    # Assemble bottom-up
    agents_by_team = Enum.group_by(agent_memberships, & &1.team_id)

    teams_with_agents =
      Enum.map(teams, fn t ->
        %{
          id: t.id,
          name: t.name,
          slug: t.slug,
          description: t.description,
          manager_agent_id: t.manager_agent_id,
          budget_monthly_cents: t.budget_monthly_cents,
          budget_enforcement: t.budget_enforcement,
          signal: t.signal,
          agents: Map.get(agents_by_team, t.id, [])
        }
      end)

    teams_by_dept =
      Enum.group_by(teams_with_agents, fn t ->
        # Need the raw team to get department_id
        team = Enum.find(teams, &(&1.id == t.id))
        team.department_id
      end)

    depts_with_teams =
      Enum.map(departments, fn d ->
        %{
          id: d.id,
          name: d.name,
          slug: d.slug,
          description: d.description,
          head_agent_id: d.head_agent_id,
          budget_monthly_cents: d.budget_monthly_cents,
          budget_enforcement: d.budget_enforcement,
          signal: d.signal,
          teams: Map.get(teams_by_dept, d.id, [])
        }
      end)

    depts_by_div =
      Enum.group_by(depts_with_teams, fn d ->
        dept = Enum.find(departments, &(&1.id == d.id))
        dept.division_id
      end)

    divs_with_depts =
      Enum.map(divisions, fn d ->
        %{
          id: d.id,
          name: d.name,
          slug: d.slug,
          description: d.description,
          head_agent_id: d.head_agent_id,
          budget_monthly_cents: d.budget_monthly_cents,
          budget_enforcement: d.budget_enforcement,
          signal: d.signal,
          departments: Map.get(depts_by_div, d.id, [])
        }
      end)

    json(conn, %{
      organization: %{
        id: org.id,
        name: org.name,
        slug: org.slug,
        mission: org.mission,
        budget_monthly_cents: org.budget_monthly_cents,
        budget_per_agent_cents: org.budget_per_agent_cents,
        budget_enforcement: org.budget_enforcement,
        governance: org.governance,
        divisions: divs_with_depts
      }
    })
  end
end
