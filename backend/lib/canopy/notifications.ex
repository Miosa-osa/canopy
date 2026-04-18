defmodule Canopy.Notifications do
  @moduledoc """
  Public API for Canopy's notification system.

  Every Phase 3 module (Tasks, Chat, Channels, Docs, Files) calls one function:

      Notifications.create(%{
        user_id: user_id,
        type: "task_assigned",
        title: "Task assigned to you",
        body: "Roberto assigned 'Fix login' to you.",
        icon: "📋",
        link_path: "/tasks/T-123",
        payload: %{"task_id" => "T-123"}
      })

  On success: row is persisted, in-app broadcast fires on `user:<id>`, telemetry emitted.

  ## In-app delivery

  Broadcasts `{:notification, payload}` on `Phoenix.PubSub` topic `user:<user_id>`.

  # TODO: Replace Phoenix.PubSub.broadcast with Canopy.Realtime.broadcast_user once #72 lands.
  # Track #72 (Realtime) has already landed — update this to use Canopy.Realtime.broadcast_user/3.

  ## Field contract

  Required: `type`, `title`, `body`.
  Optional: `user_id`, `agent_slug`, `icon`, `link_path`, `payload`.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Notifications.Notification
  alias Canopy.Repo

  @pubsub Canopy.PubSub

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Creates a notification and broadcasts in-app.

  Returns `{:ok, notification}` or `{:error, changeset}`.
  """
  @spec create(map()) :: {:ok, Notification.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %Notification{} |> Notification.changeset(attrs) |> Repo.insert() |> broadcast()
  end

  defp broadcast({:ok, notif} = result) do
    Phoenix.PubSub.broadcast(@pubsub, "user:#{notif.user_id}", {:notification, notif})
    result
  end

  defp broadcast(error), do: error

  @doc """
  Lists notifications for `user_id` with optional filters.

  Filters:
  - `unread: true` — only rows where `read_at IS NULL`
  - `type: "task_assigned"` — filter by notification type
  - `limit: 50` — max rows returned (default 50)
  """
  @spec list_for_user(binary(), map()) :: [Notification.t()]
  def list_for_user(user_id, filters \\ %{}) do
    limit = Map.get(filters, :limit, 50)

    query =
      from(n in Notification,
        where: n.user_id == ^user_id,
        order_by: [desc: n.inserted_at],
        limit: ^limit
      )

    query =
      if Map.get(filters, :unread) do
        from(n in query, where: is_nil(n.read_at))
      else
        query
      end

    query =
      case Map.get(filters, :type) do
        nil -> query
        type -> from(n in query, where: n.type == ^type)
      end

    Repo.all(query)
  end

  @doc "Returns the count of unread notifications for `user_id`."
  @spec unread_count(binary()) :: non_neg_integer()
  def unread_count(user_id) do
    Repo.one(
      from(n in Notification,
        where: n.user_id == ^user_id and is_nil(n.read_at),
        select: count(n.id)
      )
    ) || 0
  end

  @doc "Marks a single notification as read. Returns `{:ok, notification}` or `{:error, :not_found}`."
  @spec mark_read(binary()) :: {:ok, Notification.t()} | {:error, :not_found}
  def mark_read(id) do
    case Repo.get(Notification, id) do
      nil ->
        {:error, :not_found}

      notification ->
        notification
        |> Notification.mark_read_changeset(DateTime.utc_now() |> DateTime.truncate(:second))
        |> Repo.update()
    end
  end

  @doc "Marks all unread notifications for `user_id` as read. Returns `{:ok, count}`."
  @spec mark_all_read(binary()) :: {:ok, non_neg_integer()}
  def mark_all_read(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {count, _} =
      Repo.update_all(
        from(n in Notification,
          where: n.user_id == ^user_id and is_nil(n.read_at)
        ),
        set: [read_at: now, updated_at: now]
      )

    {:ok, count}
  end

  @doc "Deletes a notification by ID. Returns `{:ok, notification}` or `{:error, :not_found}`."
  @spec delete(binary()) :: {:ok, Notification.t()} | {:error, :not_found}
  def delete(id) do
    case Repo.get(Notification, id) do
      nil -> {:error, :not_found}
      notification -> Repo.delete(notification)
    end
  end
end
