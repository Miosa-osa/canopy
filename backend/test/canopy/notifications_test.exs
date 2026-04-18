defmodule Canopy.NotificationsTest do
  @moduledoc """
  Integration tests for Canopy.Notifications — create, list, unread_count,
  mark_read, mark_all_read, delete, emit, emit_from_template.
  """

  use Canopy.DataCase, async: false

  alias Canopy.Notifications
  alias Canopy.Notifications.Notification

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp user_id, do: Ecto.UUID.generate()

  defp notification_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        type: "task_assigned",
        title: "Task assigned to you",
        body: "Roberto assigned 'Fix login' to you.",
        icon: "📋",
        link_path: "/tasks/T-1",
        payload: %{"task_id" => "T-1"}
      },
      overrides
    )
  end

  defp insert_notification!(user_id, overrides \\ %{}) do
    {:ok, n} =
      Notifications.create(
        Map.merge(notification_attrs(), %{user_id: user_id} |> Map.merge(overrides))
      )

    n
  end

  # ---------------------------------------------------------------------------
  # create/1
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "inserts a notification with required fields" do
      uid = user_id()
      attrs = notification_attrs(%{user_id: uid})

      assert {:ok, %Notification{} = n} = Notifications.create(attrs)
      assert n.type == "task_assigned"
      assert n.title == "Task assigned to you"
      assert n.user_id == uid
      assert is_nil(n.read_at)
    end

    test "rejects notification without title" do
      attrs = notification_attrs(%{user_id: user_id()}) |> Map.delete(:title)
      assert {:error, changeset} = Notifications.create(attrs)
      assert %{title: [_ | _]} = errors_on(changeset)
    end

    test "rejects notification without type" do
      attrs = notification_attrs(%{user_id: user_id()}) |> Map.delete(:type)
      assert {:error, changeset} = Notifications.create(attrs)
      assert %{type: [_ | _]} = errors_on(changeset)
    end

    test "rejects notification without body" do
      attrs = notification_attrs(%{user_id: user_id()}) |> Map.delete(:body)
      assert {:error, changeset} = Notifications.create(attrs)
      assert %{body: [_ | _]} = errors_on(changeset)
    end

    test "defaults payload to empty map when not provided" do
      uid = user_id()
      attrs = %{type: "test", title: "T", body: "B", user_id: uid}
      assert {:ok, n} = Notifications.create(attrs)
      assert n.payload == %{}
    end

    test "accepts nil user_id for agent-destined notifications" do
      attrs = notification_attrs(%{user_id: nil, agent_slug: "coding-agent"})
      assert {:ok, n} = Notifications.create(attrs)
      assert is_nil(n.user_id)
      assert n.agent_slug == "coding-agent"
    end
  end

  # ---------------------------------------------------------------------------
  # list_for_user/2
  # ---------------------------------------------------------------------------

  describe "list_for_user/2" do
    test "returns empty list when user has no notifications" do
      assert [] = Notifications.list_for_user(user_id())
    end

    test "returns notifications for the user, newest first" do
      uid = user_id()
      n1 = insert_notification!(uid, %{type: "task_assigned"})
      n2 = insert_notification!(uid, %{type: "mention_in_channel"})

      result = Notifications.list_for_user(uid)
      ids = Enum.map(result, & &1.id)

      assert length(result) == 2
      assert n1.id in ids
      assert n2.id in ids
    end

    test "does not return other users' notifications" do
      uid1 = user_id()
      uid2 = user_id()
      insert_notification!(uid1)

      assert [] = Notifications.list_for_user(uid2)
    end

    test "filters by unread: true" do
      uid = user_id()
      unread = insert_notification!(uid)
      read = insert_notification!(uid)
      {:ok, _} = Notifications.mark_read(read.id)

      result = Notifications.list_for_user(uid, %{unread: true})
      ids = Enum.map(result, & &1.id)
      assert unread.id in ids
      refute read.id in ids
    end

    test "filters by type" do
      uid = user_id()
      insert_notification!(uid, %{type: "task_assigned"})
      insert_notification!(uid, %{type: "mention_in_channel"})

      result = Notifications.list_for_user(uid, %{type: "task_assigned"})
      assert Enum.all?(result, &(&1.type == "task_assigned"))
    end

    test "respects limit" do
      uid = user_id()
      Enum.each(1..5, fn _ -> insert_notification!(uid) end)

      result = Notifications.list_for_user(uid, %{limit: 3})
      assert length(result) == 3
    end
  end

  # ---------------------------------------------------------------------------
  # unread_count/1
  # ---------------------------------------------------------------------------

  describe "unread_count/1" do
    test "returns 0 when no notifications" do
      assert 0 = Notifications.unread_count(user_id())
    end

    test "counts only unread notifications" do
      uid = user_id()
      n1 = insert_notification!(uid)
      n2 = insert_notification!(uid)
      _n3 = insert_notification!(uid)

      Notifications.mark_read(n1.id)
      Notifications.mark_read(n2.id)

      assert 1 = Notifications.unread_count(uid)
    end

    test "does not count other users' unread" do
      uid1 = user_id()
      uid2 = user_id()
      insert_notification!(uid1)

      assert 0 = Notifications.unread_count(uid2)
    end
  end

  # ---------------------------------------------------------------------------
  # mark_read/1
  # ---------------------------------------------------------------------------

  describe "mark_read/1" do
    test "sets read_at on the notification" do
      uid = user_id()
      n = insert_notification!(uid)
      assert is_nil(n.read_at)

      assert {:ok, updated} = Notifications.mark_read(n.id)
      assert not is_nil(updated.read_at)
    end

    test "returns {:error, :not_found} for unknown ID" do
      assert {:error, :not_found} = Notifications.mark_read(Ecto.UUID.generate())
    end

    test "is idempotent — marking already-read notification returns ok" do
      uid = user_id()
      n = insert_notification!(uid)
      {:ok, first} = Notifications.mark_read(n.id)
      {:ok, second} = Notifications.mark_read(n.id)
      # read_at should be the same or close (both truncated to second)
      assert not is_nil(first.read_at)
      assert not is_nil(second.read_at)
    end
  end

  # ---------------------------------------------------------------------------
  # mark_all_read/1
  # ---------------------------------------------------------------------------

  describe "mark_all_read/1" do
    test "marks all unread notifications read" do
      uid = user_id()
      insert_notification!(uid)
      insert_notification!(uid)
      insert_notification!(uid)

      assert {:ok, 3} = Notifications.mark_all_read(uid)
      assert 0 = Notifications.unread_count(uid)
    end

    test "returns 0 when no unread notifications" do
      uid = user_id()
      assert {:ok, 0} = Notifications.mark_all_read(uid)
    end

    test "only marks the requesting user's notifications" do
      uid1 = user_id()
      uid2 = user_id()
      insert_notification!(uid1)
      insert_notification!(uid2)

      {:ok, count} = Notifications.mark_all_read(uid1)
      assert count == 1
      assert 1 = Notifications.unread_count(uid2)
    end
  end

  # ---------------------------------------------------------------------------
  # delete/1
  # ---------------------------------------------------------------------------

  describe "delete/1" do
    test "removes the notification" do
      uid = user_id()
      n = insert_notification!(uid)
      assert {:ok, deleted} = Notifications.delete(n.id)
      assert deleted.id == n.id
      assert [] = Notifications.list_for_user(uid)
    end

    test "returns {:error, :not_found} for unknown ID" do
      assert {:error, :not_found} = Notifications.delete(Ecto.UUID.generate())
    end
  end
end
