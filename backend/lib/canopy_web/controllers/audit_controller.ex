defmodule CanopyWeb.AuditController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.AuditEvent
  import Ecto.Query

  def index(conn, params) do
    action = params["action"]
    actor = params["actor"]
    actor_type = params["actor_type"]
    entity_type = params["entity_type"]
    from_date = params["from"]
    to_date = params["to"]
    limit = min(parse_int(params["limit"], 50), 500)
    offset = parse_int(params["offset"], 0)

    query =
      from e in AuditEvent,
        order_by: [desc: e.inserted_at],
        limit: ^limit,
        offset: ^offset

    query = if action, do: where(query, [e], e.action == ^action), else: query
    query = if actor, do: where(query, [e], ilike(e.actor, ^"%#{actor}%")), else: query
    query = if actor_type, do: where(query, [e], e.actor_type == ^actor_type), else: query
    query = if entity_type, do: where(query, [e], e.entity_type == ^entity_type), else: query

    query =
      case parse_datetime(from_date) do
        {:ok, dt} -> where(query, [e], e.inserted_at >= ^dt)
        _ -> query
      end

    query =
      case parse_datetime(to_date) do
        {:ok, dt} -> where(query, [e], e.inserted_at <= ^dt)
        _ -> query
      end

    events = Repo.all(query)
    total = Repo.aggregate(AuditEvent, :count)

    json(conn, %{
      entries: Enum.map(events, &serialize/1),
      total: total
    })
  end

  defp serialize(%AuditEvent{} = e) do
    %{
      id: e.id,
      action: e.action,
      actor: e.actor,
      actor_type: e.actor_type,
      entity_type: e.entity_type,
      entity_id: e.entity_id,
      details: e.details,
      ip_address: nil,
      created_at: e.inserted_at,
      inserted_at: e.inserted_at
    }
  end

  defp parse_datetime(nil), do: :error

  defp parse_datetime(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> {:ok, dt}
      _ -> :error
    end
  end
end
