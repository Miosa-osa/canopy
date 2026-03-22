defmodule CanopyWeb.TeamController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{Team, TeamMembership, Agent}
  import Ecto.Query

  def index(conn, params) do
    department_id = params["department_id"]

    query = from t in Team, order_by: [asc: t.name]
    query = if department_id, do: where(query, [t], t.department_id == ^department_id), else: query

    teams = Repo.all(query)
    json(conn, %{teams: Enum.map(teams, &serialize/1)})
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(Team, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      team ->
        members =
          Repo.all(
            from tm in TeamMembership,
              join: a in Agent, on: tm.agent_id == a.id,
              where: tm.team_id == ^id,
              select: %{
                id: tm.id,
                agent_id: a.id,
                agent_name: a.name,
                agent_slug: a.slug,
                role: tm.role,
                inserted_at: tm.inserted_at
              }
          )

        json(conn, %{team: serialize(team) |> Map.put(:members, members)})
    end
  end

  def create(conn, params) do
    changeset = Team.changeset(%Team{}, params)

    case Repo.insert(changeset) do
      {:ok, team} ->
        Canopy.EventBus.broadcast(
          "department:#{team.department_id}",
          %{event: "team.created", team_id: team.id, name: team.name}
        )

        conn |> put_status(201) |> json(%{team: serialize(team)})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Repo.get(Team, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      team ->
        changeset = Team.changeset(team, params)

        case Repo.update(changeset) do
          {:ok, updated} ->
            Canopy.EventBus.broadcast(
              "department:#{updated.department_id}",
              %{event: "team.updated", team_id: updated.id, name: updated.name}
            )

            json(conn, %{team: serialize(updated)})

          {:error, changeset} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_failed", details: format_errors(changeset)})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(Team, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      team ->
        Repo.delete!(team)

        Canopy.EventBus.broadcast(
          "department:#{team.department_id}",
          %{event: "team.deleted", team_id: team.id}
        )

        json(conn, %{ok: true})
    end
  end

  def agents(conn, %{"team_id" => team_id}) do
    case Repo.get(Team, team_id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "team_not_found"})

      _team ->
        agents =
          Repo.all(
            from a in Agent,
              join: tm in TeamMembership, on: tm.agent_id == a.id,
              where: tm.team_id == ^team_id,
              order_by: [asc: a.name],
              select: %{
                id: a.id,
                name: a.name,
                slug: a.slug,
                role: a.role,
                status: a.status,
                adapter: a.adapter,
                model: a.model,
                avatar_emoji: a.avatar_emoji,
                team_role: tm.role
              }
          )

        json(conn, %{agents: agents})
    end
  end

  def add_member(conn, %{"team_id" => team_id} = params) do
    agent_id = params["agent_id"]
    role = params["role"] || "member"

    with %Team{} <- Repo.get(Team, team_id) || :team_not_found,
         %Agent{} <- Repo.get(Agent, agent_id) || :agent_not_found do
      changeset =
        TeamMembership.changeset(%TeamMembership{}, %{
          team_id: team_id,
          agent_id: agent_id,
          role: role
        })

      txn_result =
        Repo.transaction(fn ->
          case Repo.insert(changeset) do
            {:ok, membership} ->
              # Sync agent.team_id denormalized FK
              Repo.get!(Agent, agent_id)
              |> Ecto.Changeset.change(team_id: team_id)
              |> Repo.update!()

              membership

            {:error, changeset} ->
              Repo.rollback({:validation_failed, changeset})
          end
        end)

      case txn_result do
        {:ok, membership} ->
          Canopy.EventBus.broadcast(
            "team:#{team_id}",
            %{event: "team.member_added", team_id: team_id, agent_id: agent_id, role: role}
          )

          # Invalidate budget hierarchy cache
          Canopy.BudgetEnforcer.invalidate_hierarchy(agent_id)

          conn |> put_status(201) |> json(%{membership: serialize_membership(membership)})

        {:error, {:validation_failed, changeset}} ->
          conn
          |> put_status(422)
          |> json(%{error: "validation_failed", details: format_errors(changeset)})

        {:error, reason} ->
          conn
          |> put_status(422)
          |> json(%{error: "transaction_failed", details: inspect(reason)})
      end
    else
      :team_not_found ->
        conn |> put_status(404) |> json(%{error: "team_not_found"})

      :agent_not_found ->
        conn |> put_status(404) |> json(%{error: "agent_not_found"})
    end
  end

  def remove_member(conn, %{"team_id" => team_id, "agent_id" => agent_id}) do
    case Repo.one(
           from tm in TeamMembership,
             where: tm.team_id == ^team_id and tm.agent_id == ^agent_id
         ) do
      nil ->
        conn |> put_status(404) |> json(%{error: "membership_not_found"})

      membership ->
        txn_result =
          Repo.transaction(fn ->
            Repo.delete!(membership)

            # Clear agent.team_id denormalized FK
            case Repo.get(Agent, agent_id) do
              %Agent{} = agent ->
                agent |> Ecto.Changeset.change(team_id: nil) |> Repo.update!()

              nil ->
                :ok
            end
          end)

        case txn_result do
          {:ok, _} ->
            Canopy.EventBus.broadcast(
              "team:#{team_id}",
              %{event: "team.member_removed", team_id: team_id, agent_id: agent_id}
            )

            Canopy.BudgetEnforcer.invalidate_hierarchy(agent_id)

            json(conn, %{ok: true})

          {:error, reason} ->
            conn
            |> put_status(422)
            |> json(%{error: "transaction_failed", details: inspect(reason)})
        end
    end
  end

  defp serialize(%Team{} = t) do
    %{
      id: t.id,
      department_id: t.department_id,
      name: t.name,
      slug: t.slug,
      description: t.description,
      manager_agent_id: t.manager_agent_id,
      budget_monthly_cents: t.budget_monthly_cents,
      budget_enforcement: t.budget_enforcement,
      signal: t.signal,
      mission: t.mission,
      coordination: t.coordination,
      escalation_rules: t.escalation_rules,
      handoff_protocols: t.handoff_protocols,
      inserted_at: t.inserted_at,
      updated_at: t.updated_at
    }
  end

  defp serialize_membership(%TeamMembership{} = m) do
    %{
      id: m.id,
      team_id: m.team_id,
      agent_id: m.agent_id,
      role: m.role,
      inserted_at: m.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
