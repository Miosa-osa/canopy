defmodule CanopyWeb.NotificationController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.Notification
  alias Canopy.Notifications.Dispatcher
  import Ecto.Query

  @default_limit 50
  @max_limit 200

  def index(conn, params) do
    workspace_id = params["workspace_id"]
    limit = min(parse_int(params["limit"], @default_limit), @max_limit)
    offset = parse_int(params["offset"], 0)

    query =
      from n in Notification,
        where: is_nil(n.dismissed_at),
        order_by: [desc: n.inserted_at],
        limit: ^limit,
        offset: ^offset

    query = apply_workspace_filter(query, workspace_id)
    query = apply_category_filter(query, params["category"])
    query = apply_severity_filter(query, params["severity"])
    query = apply_unread_filter(query, params["unread"])

    notifications = Repo.all(query)
    json(conn, %{notifications: Enum.map(notifications, &serialize/1)})
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(Notification, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      notification ->
        json(conn, %{notification: serialize(notification)})
    end
  end

  def create(conn, params) do
    # Ensure workspace_id is set from auth context when not provided in body
    workspace_id =
      params["workspace_id"] || default_workspace_id(conn)

    attrs = Map.put(params, "workspace_id", workspace_id)

    case Dispatcher.notify(attrs) do
      {:ok, notification} ->
        conn |> put_status(201) |> json(%{notification: serialize(notification)})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(changeset)})
    end
  end

  def mark_read(conn, %{"notification_id" => id}) do
    case Repo.get(Notification, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      notification ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        case notification
             |> Ecto.Changeset.change(read_at: now)
             |> Repo.update() do
          {:ok, updated} ->
            json(conn, %{notification: serialize(updated)})

          {:error, _changeset} ->
            conn |> put_status(500) |> json(%{error: "update_failed"})
        end
    end
  end

  def mark_all_read(conn, params) do
    workspace_id = params["workspace_id"]
    category = params["category"]
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    query =
      from n in Notification,
        where: is_nil(n.read_at) and is_nil(n.dismissed_at)

    query = apply_workspace_filter(query, workspace_id)
    query = apply_category_filter(query, category)

    {count, _} = Repo.update_all(query, set: [read_at: now, updated_at: now])
    json(conn, %{ok: true, updated: count})
  end

  def dismiss(conn, %{"notification_id" => id}) do
    case Repo.get(Notification, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      notification ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        case notification
             |> Ecto.Changeset.change(dismissed_at: now)
             |> Repo.update() do
          {:ok, updated} ->
            json(conn, %{notification: serialize(updated)})

          {:error, _changeset} ->
            conn |> put_status(500) |> json(%{error: "update_failed"})
        end
    end
  end

  def badges(conn, params) do
    workspace_id = params["workspace_id"]

    base =
      from n in Notification,
        where: is_nil(n.read_at) and is_nil(n.dismissed_at)

    base = apply_workspace_filter(base, workspace_id)

    unread = Repo.aggregate(base, :count)

    categories = ~w(task approval alert mention system budget workflow)

    by_category =
      Enum.into(categories, %{}, fn cat ->
        count =
          base
          |> where([n], n.category == ^cat)
          |> Repo.aggregate(:count)

        {cat, count}
      end)

    severities = ~w(info warning error critical)

    by_severity =
      Enum.into(severities, %{}, fn sev ->
        count =
          base
          |> where([n], n.severity == ^sev)
          |> Repo.aggregate(:count)

        {sev, count}
      end)

    json(conn, %{
      unread: unread,
      by_category: by_category,
      by_severity: by_severity
    })
  end

  # --- Private helpers ---

  defp apply_workspace_filter(query, nil), do: query

  defp apply_workspace_filter(query, workspace_id),
    do: where(query, [n], n.workspace_id == ^workspace_id)

  defp apply_category_filter(query, nil), do: query
  defp apply_category_filter(query, ""), do: query
  defp apply_category_filter(query, category), do: where(query, [n], n.category == ^category)

  defp apply_severity_filter(query, nil), do: query
  defp apply_severity_filter(query, ""), do: query
  defp apply_severity_filter(query, severity), do: where(query, [n], n.severity == ^severity)

  defp apply_unread_filter(query, "true"), do: where(query, [n], is_nil(n.read_at))
  defp apply_unread_filter(query, _), do: query

  defp default_workspace_id(conn) do
    case conn.assigns do
      %{workspace: %{id: id}} -> id
      %{user_workspace_ids: [id]} -> id
      _ -> nil
    end
  end

  defp parse_int(nil, default), do: default

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {n, _} when n >= 0 -> n
      _ -> default
    end
  end

  defp parse_int(value, _default) when is_integer(value), do: value

  defp serialize(%Notification{} = n) do
    %{
      id: n.id,
      workspace_id: n.workspace_id,
      recipient_type: n.recipient_type,
      recipient_id: n.recipient_id,
      sender_type: n.sender_type,
      sender_id: n.sender_id,
      category: n.category,
      severity: n.severity,
      title: n.title,
      body: n.body,
      action_url: n.action_url,
      action_label: n.action_label,
      metadata: n.metadata,
      read_at: n.read_at,
      dismissed_at: n.dismissed_at,
      expires_at: n.expires_at,
      read: not is_nil(n.read_at),
      dismissed: not is_nil(n.dismissed_at),
      inserted_at: n.inserted_at,
      updated_at: n.updated_at
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
