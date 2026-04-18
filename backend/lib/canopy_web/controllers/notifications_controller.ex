defmodule CanopyWeb.NotificationsController do
  @moduledoc """
  HTTP API for Canopy notifications.

  Routes (registered in router.ex under /api/v1):
    GET    /notifications                 — list for current user (filters: unread, type, limit)
    GET    /notifications/unread_count    — integer count of unread
    POST   /notifications/:id/read       — mark one read
    POST   /notifications/read_all       — mark all read for current user
    DELETE /notifications/:id            — delete one

  User identity comes from `conn.assigns.current_user` (set by OptionalAuthenticate).
  When `current_user` is nil (unauthenticated), list/unread_count return empty/zero
  and mutation endpoints return empty success to avoid leaking data.
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Notifications
  alias CanopyWeb.Schemas.NotificationSchema

  action_fallback CanopyWeb.FallbackController

  tags ["notifications"]

  operation :index,
    summary: "List notifications for current user",
    parameters: [
      unread: [
        in: :query,
        description: "When 'true', return only unread notifications",
        type: :boolean,
        required: false
      ],
      type: [
        in: :query,
        description: "Filter by notification type, e.g. task_assigned",
        type: :string,
        required: false
      ],
      limit: [
        in: :query,
        description: "Max notifications to return (default 50)",
        type: :integer,
        required: false
      ]
    ],
    responses: [
      ok: {"Notification list", "application/json", NotificationSchema.NotificationList}
    ]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    user_id = user_id_from(conn)

    if is_nil(user_id) do
      json(conn, %{data: [], unread_count: 0})
    else
      filters = build_filters(params)
      notifications = Notifications.list_for_user(user_id, filters)
      count = Notifications.unread_count(user_id)
      json(conn, %{data: notifications, unread_count: count})
    end
  end

  operation :unread_count,
    summary: "Get unread notification count for current user",
    responses: [
      ok: {"Unread count", "application/json", NotificationSchema.UnreadCountResponse}
    ]

  @spec unread_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def unread_count(conn, _params) do
    user_id = user_id_from(conn)

    count =
      if is_nil(user_id),
        do: 0,
        else: Notifications.unread_count(user_id)

    json(conn, %{unread_count: count})
  end

  operation :mark_read,
    summary: "Mark a single notification as read",
    parameters: [
      id: [in: :path, description: "Notification UUID", type: :string, required: true]
    ],
    responses: [
      ok: {"Updated notification", "application/json", NotificationSchema.Notification},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec mark_read(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def mark_read(conn, %{"id" => id}) do
    with {:ok, notification} <- Notifications.mark_read(id) do
      json(conn, notification)
    end
  end

  operation :read_all,
    summary: "Mark all notifications read for current user",
    responses: [
      ok: {"Mark all result", "application/json", NotificationSchema.MarkAllReadResponse}
    ]

  @spec read_all(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def read_all(conn, _params) do
    user_id = user_id_from(conn)

    {:ok, count} =
      if is_nil(user_id),
        do: {:ok, 0},
        else: Notifications.mark_all_read(user_id)

    json(conn, %{marked_read: count})
  end

  operation :delete,
    summary: "Delete a notification",
    parameters: [
      id: [in: :path, description: "Notification UUID", type: :string, required: true]
    ],
    responses: [
      ok: {"Deleted notification", "application/json", NotificationSchema.Notification},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    with {:ok, notification} <- Notifications.delete(id) do
      json(conn, notification)
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec user_id_from(Plug.Conn.t()) :: binary() | nil
  defp user_id_from(conn) do
    case conn.assigns[:current_user] do
      %{id: id} -> id
      nil -> nil
    end
  end

  @spec build_filters(map()) :: map()
  defp build_filters(params) do
    %{}
    |> maybe_put_unread(params["unread"])
    |> maybe_put_type(params["type"])
    |> maybe_put_limit(params["limit"])
  end

  defp maybe_put_unread(filters, "true"), do: Map.put(filters, :unread, true)
  defp maybe_put_unread(filters, _), do: filters

  defp maybe_put_type(filters, nil), do: filters
  defp maybe_put_type(filters, type), do: Map.put(filters, :type, type)

  defp maybe_put_limit(filters, nil), do: filters

  defp maybe_put_limit(filters, limit_str) do
    case Integer.parse(limit_str) do
      {n, ""} when n > 0 -> Map.put(filters, :limit, n)
      _ -> filters
    end
  end
end
