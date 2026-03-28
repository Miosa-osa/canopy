defmodule CanopyWeb.InboxController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.ActivityEvent
  import Ecto.Query

  # Inbox messages are ActivityEvents with level="notification".
  # "Read" state is tracked in metadata["read"] = true.

  def index(conn, params) do
    workspace_id = params["workspace_id"]
    unread_only = params["unread"] == "true"
    limit = min(parse_int(params["limit"], 50), 200)
    offset = parse_int(params["offset"], 0)

    query =
      from e in ActivityEvent,
        where: e.level == "notification",
        order_by: [desc: e.inserted_at],
        limit: ^limit,
        offset: ^offset

    query = if workspace_id, do: where(query, [e], e.workspace_id == ^workspace_id), else: query

    query =
      if unread_only do
        where(
          query,
          [e],
          fragment("COALESCE((?->>'read')::boolean, false) = false", e.metadata)
        )
      else
        query
      end

    messages = Repo.all(query)
    total = Repo.aggregate(from(e in ActivityEvent, where: e.level == "notification"), :count)

    unread_count =
      Repo.aggregate(
        from(e in ActivityEvent,
          where:
            e.level == "notification" and
              fragment("COALESCE((?->>'read')::boolean, false) = false", e.metadata)
        ),
        :count
      )

    json(conn, %{
      items: Enum.map(messages, &serialize/1),
      total: total,
      unread_count: unread_count
    })
  end

  def read(conn, %{"id" => id}) do
    case Repo.get(ActivityEvent, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      event ->
        updated_metadata = Map.put(event.metadata || %{}, "read", true)

        case event
             |> Ecto.Changeset.change(metadata: updated_metadata)
             |> Repo.update() do
          {:ok, updated} ->
            json(conn, %{item: serialize(updated)})

          {:error, _changeset} ->
            conn |> put_status(500) |> json(%{error: "update_failed"})
        end
    end
  end

  def read_all(conn, params) do
    workspace_id = params["workspace_id"]

    query =
      from e in ActivityEvent,
        where:
          e.level == "notification" and
            fragment("COALESCE((?->>'read')::boolean, false) = false", e.metadata)

    query = if workspace_id, do: where(query, [e], e.workspace_id == ^workspace_id), else: query

    # Use Ecto.Adapters.SQL for the JSONB merge (fragment not supported in update_all set)
    {count, _} =
      from(e in query, select: e.id)
      |> Repo.all()
      |> case do
        [] ->
          {0, nil}

        ids ->
          from(e in ActivityEvent, where: e.id in ^ids)
          |> Repo.update_all(set: [metadata: %{"read" => true}, updated_at: DateTime.utc_now()])
      end

    json(conn, %{ok: true, updated: count})
  end

  def perform_action(conn, %{"id" => id} = params) do
    action_type = params["action"] || "acknowledge"

    case Repo.get(ActivityEvent, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      event ->
        updated_metadata =
          (event.metadata || %{})
          |> Map.put("read", true)
          |> Map.put("action", action_type)
          |> Map.put("actioned_at", DateTime.to_iso8601(DateTime.utc_now()))

        case event
             |> Ecto.Changeset.change(metadata: updated_metadata)
             |> Repo.update() do
          {:ok, updated} ->
            Canopy.EventBus.broadcast(
              Canopy.EventBus.activity_topic(),
              %{event: "inbox.actioned", message_id: id, action: action_type}
            )

            json(conn, %{ok: true, item: serialize(updated), action: action_type})

          {:error, _changeset} ->
            conn |> put_status(500) |> json(%{error: "update_failed"})
        end
    end
  end

  defp serialize(%ActivityEvent{} = e) do
    %{
      id: e.id,
      type: e.event_type,
      status: if(get_in(e.metadata || %{}, ["read"]) == true, do: "read", else: "unread"),
      title: e.message,
      body: e.message,
      source_agent: e.agent_id,
      actions: [],
      event_type: e.event_type,
      message: e.message,
      metadata: e.metadata,
      level: e.level,
      workspace_id: e.workspace_id,
      agent_id: e.agent_id,
      created_at: e.inserted_at,
      inserted_at: e.inserted_at,
      read: get_in(e.metadata || %{}, ["read"]) == true
    }
  end
end
