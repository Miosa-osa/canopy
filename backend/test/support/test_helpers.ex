defmodule Canopy.TestHelpers do
  @moduledoc "Factory functions and auth helpers for tests."

  alias Canopy.Repo
  alias Canopy.Schemas.{User, Workspace, Agent, BudgetPolicy, CostEvent, Approval, Team, TeamMembership, Department, Division, Organization}

  # ── Auth ──────────────────────────────────────────────────────────────────────

  @doc "Create an authenticated connection with a fresh user."
  def authenticated_conn(conn) do
    user = insert_user()
    token = generate_token(user)

    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
    |> Plug.Conn.put_req_header("content-type", "application/json")
  end

  @doc "Create an authenticated connection for a specific user."
  def authenticated_conn(conn, user) do
    token = generate_token(user)

    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
    |> Plug.Conn.put_req_header("content-type", "application/json")
  end

  def generate_token(user) do
    {:ok, token, _claims} = Canopy.Guardian.encode_and_sign(user)
    token
  end

  # ── Factories ─────────────────────────────────────────────────────────────────

  def insert_user(attrs \\ %{}) do
    default = %{
      name: "Test User #{unique_id()}",
      email: "test-#{unique_id()}@canopy.test",
      password: "testpassword123",
      role: "admin"
    }

    %User{}
    |> User.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end

  def insert_workspace(user, attrs \\ %{}) do
    default = %{
      name: "Test Workspace #{unique_id()}",
      path: "/tmp/canopy-test-#{unique_id()}",
      status: "active",
      owner_id: user.id
    }

    %Workspace{}
    |> Workspace.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end

  def insert_agent(workspace, attrs \\ %{}) do
    slug = "agent-#{unique_id()}"

    default = %{
      slug: slug,
      name: "Agent #{slug}",
      role: "developer",
      adapter: "bash",
      model: "claude-sonnet-4-6",
      status: "idle",
      workspace_id: workspace.id
    }

    %Agent{}
    |> Agent.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end

  def insert_organization(attrs \\ %{}) do
    uid = unique_id()

    default = %{
      name: "Test Org #{uid}",
      slug: "org-#{uid}"
    }

    %Organization{}
    |> Organization.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end

  def insert_division(org, attrs \\ %{}) do
    uid = unique_id()

    default = %{
      name: "Test Division #{uid}",
      slug: "div-#{uid}",
      organization_id: org.id
    }

    %Division{}
    |> Division.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end

  def insert_department(division, attrs \\ %{}) do
    uid = unique_id()

    default = %{
      name: "Test Department #{uid}",
      slug: "dept-#{uid}",
      division_id: division.id
    }

    %Department{}
    |> Department.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end

  def insert_team(department, attrs \\ %{}) do
    uid = unique_id()

    default = %{
      name: "Test Team #{uid}",
      slug: "team-#{uid}",
      department_id: department.id
    }

    %Team{}
    |> Team.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end

  def insert_team_membership(team, agent, attrs \\ %{}) do
    default = %{
      team_id: team.id,
      agent_id: agent.id,
      role: "member"
    }

    %TeamMembership{}
    |> TeamMembership.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end

  def insert_budget_policy(scope_type, scope_id, attrs \\ %{}) do
    default = %{
      scope_type: scope_type,
      scope_id: scope_id,
      monthly_limit_cents: 100_000,
      warning_threshold_pct: 80,
      hard_stop: true
    }

    %BudgetPolicy{}
    |> BudgetPolicy.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end

  def insert_cost_event(agent, attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    default = %{
      agent_id: agent.id,
      model: agent.model || "claude-sonnet-4-6",
      tokens_input: 1000,
      tokens_output: 500,
      tokens_cache: 0,
      cost_cents: 100,
      inserted_at: now
    }

    %CostEvent{}
    |> CostEvent.changeset(Map.merge(default, attrs))
    |> Ecto.Changeset.put_change(:inserted_at, now)
    |> Repo.insert!()
  end

  def insert_approval(workspace, attrs \\ %{}) do
    default = %{
      title: "Test Approval #{unique_id()}",
      status: "pending",
      workspace_id: workspace.id
    }

    %Approval{}
    |> Approval.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end

  # ── Helpers ───────────────────────────────────────────────────────────────────

  defp unique_id, do: :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
end
