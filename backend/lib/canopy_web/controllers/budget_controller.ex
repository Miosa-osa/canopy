defmodule CanopyWeb.BudgetController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{BudgetPolicy, BudgetIncident}
  import Ecto.Query

  def index(conn, _params) do
    policies =
      Repo.all(from p in BudgetPolicy, order_by: [asc: p.scope_type, asc: p.scope_id])

    json(conn, %{policies: Enum.map(policies, &serialize/1)})
  end

  def upsert(conn, %{"scope_type" => scope_type, "scope_id" => scope_id} = params) do
    existing =
      Repo.one(
        from p in BudgetPolicy,
          where: p.scope_type == ^scope_type and p.scope_id == ^scope_id
      )

    case existing do
      nil ->
        changeset =
          BudgetPolicy.changeset(%BudgetPolicy{}, Map.merge(params, %{
            "scope_type" => scope_type,
            "scope_id" => scope_id
          }))

        case Repo.insert(changeset) do
          {:ok, policy} ->
            conn |> put_status(201) |> json(%{budget: serialize(policy)})

          {:error, cs} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_failed", details: format_errors(cs)})
        end

      existing ->
        changeset = BudgetPolicy.changeset(existing, params)

        case Repo.update(changeset) do
          {:ok, policy} ->
            json(conn, %{budget: serialize(policy)})

          {:error, cs} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_failed", details: format_errors(cs)})
        end
    end
  end

  def incidents(conn, params) do
    resolved = params["resolved"]

    query = from bi in BudgetIncident, order_by: [desc: bi.inserted_at], limit: 50

    query =
      case resolved do
        "true" -> where(query, [bi], bi.resolved == true)
        "false" -> where(query, [bi], bi.resolved == false)
        _ -> query
      end

    incidents = Repo.all(query)
    json(conn, %{incidents: Enum.map(incidents, &serialize_incident/1)})
  end

  def resolve(conn, %{"id" => id}) do
    case Repo.get(BudgetIncident, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      incident ->
        {:ok, updated} =
          incident
          |> Ecto.Changeset.change(resolved: true, resolved_at: DateTime.utc_now() |> DateTime.truncate(:second))
          |> Repo.update()

        Canopy.EventBus.broadcast(
          Canopy.EventBus.activity_topic(),
          %{event: "budget.incident_resolved", incident_id: id}
        )

        json(conn, %{incident: serialize_incident(updated)})
    end
  end

  defp serialize(%BudgetPolicy{} = p) do
    %{
      id: p.id,
      scope_type: p.scope_type,
      scope_id: p.scope_id,
      monthly_limit_cents: p.monthly_limit_cents,
      warning_threshold_pct: p.warning_threshold_pct,
      hard_stop: p.hard_stop,
      inserted_at: p.inserted_at,
      updated_at: p.updated_at
    }
  end

  defp serialize_incident(%BudgetIncident{} = i) do
    %{
      id: i.id,
      policy_id: i.policy_id,
      agent_id: i.agent_id,
      incident_type: i.incident_type,
      threshold_pct: i.threshold_pct,
      actual_pct: i.actual_pct,
      resolved: i.resolved,
      resolved_at: i.resolved_at,
      inserted_at: i.inserted_at
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
