defmodule CanopyWeb.NotificationsControllerTest do
  @moduledoc """
  Tests for NotificationsController endpoints:
    GET    /api/v1/notifications
    GET    /api/v1/notifications/unread_count
    POST   /api/v1/notifications/:id/read
    POST   /api/v1/notifications/read_all
    DELETE /api/v1/notifications/:id

  Injects current_user directly via conn assigns rather than JWT since the
  auth infrastructure (Guardian/Accounts) is out of scope for this module.
  """

  use CanopyWeb.ConnCase, async: false

  alias Canopy.Notifications

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp make_user do
    %{id: Ecto.UUID.generate()}
  end

  defp authed_conn(conn, user) do
    assign(conn, :current_user, user)
  end

  defp create_notification!(user, overrides \\ %{}) do
    {:ok, n} =
      Notifications.create(
        Map.merge(
          %{
            type: "task_assigned",
            title: "Task assigned",
            body: "You have a new task.",
            icon: "task",
            link_path: "/tasks/T-1",
            user_id: user.id
          },
          overrides
        )
      )

    n
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/notifications
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/notifications" do
    test "returns 200 with empty list when no notifications exist", %{conn: conn} do
      user = make_user()
      conn = conn |> authed_conn(user) |> get("/api/v1/notifications")
      assert %{"data" => [], "unread_count" => 0} = json_response(conn, 200)
    end

    test "returns notifications for current user", %{conn: conn} do
      user = make_user()
      create_notification!(user)
      create_notification!(user)

      conn = conn |> authed_conn(user) |> get("/api/v1/notifications")
      assert %{"data" => data, "unread_count" => count} = json_response(conn, 200)
      assert length(data) == 2
      assert count == 2
    end

    test "does not return other users' notifications", %{conn: conn} do
      user1 = make_user()
      user2 = make_user()
      create_notification!(user1)

      conn = conn |> authed_conn(user2) |> get("/api/v1/notifications")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "filters by unread=true query param", %{conn: conn} do
      user = make_user()
      unread = create_notification!(user)
      read_n = create_notification!(user)
      Notifications.mark_read(read_n.id)

      conn = conn |> authed_conn(user) |> get("/api/v1/notifications?unread=true")
      assert %{"data" => data} = json_response(conn, 200)
      ids = Enum.map(data, & &1["id"])
      assert unread.id in ids
      refute read_n.id in ids
    end

    test "filters by type query param", %{conn: conn} do
      user = make_user()
      create_notification!(user, %{type: "task_assigned"})
      create_notification!(user, %{type: "mention_in_channel"})

      conn = conn |> authed_conn(user) |> get("/api/v1/notifications?type=task_assigned")
      assert %{"data" => data} = json_response(conn, 200)
      assert Enum.all?(data, &(&1["type"] == "task_assigned"))
    end

    test "respects limit query param", %{conn: conn} do
      user = make_user()
      Enum.each(1..5, fn _ -> create_notification!(user) end)

      conn = conn |> authed_conn(user) |> get("/api/v1/notifications?limit=2")
      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) == 2
    end

    test "returns empty list when no current_user (unauthenticated)", %{conn: conn} do
      conn = get(conn, "/api/v1/notifications")
      assert %{"data" => [], "unread_count" => 0} = json_response(conn, 200)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/notifications/unread_count
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/notifications/unread_count" do
    test "returns 0 for user with no notifications", %{conn: conn} do
      user = make_user()
      conn = conn |> authed_conn(user) |> get("/api/v1/notifications/unread_count")
      assert %{"unread_count" => 0} = json_response(conn, 200)
    end

    test "returns correct count", %{conn: conn} do
      user = make_user()
      n1 = create_notification!(user)
      create_notification!(user)
      create_notification!(user)
      Notifications.mark_read(n1.id)

      conn = conn |> authed_conn(user) |> get("/api/v1/notifications/unread_count")
      assert %{"unread_count" => 2} = json_response(conn, 200)
    end

    test "returns 0 when unauthenticated", %{conn: conn} do
      conn = get(conn, "/api/v1/notifications/unread_count")
      assert %{"unread_count" => 0} = json_response(conn, 200)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/notifications/:id/read
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/notifications/:id/read" do
    test "marks notification as read and returns it", %{conn: conn} do
      user = make_user()
      n = create_notification!(user)

      conn = conn |> authed_conn(user) |> post("/api/v1/notifications/#{n.id}/read")
      body = json_response(conn, 200)
      assert body["id"] == n.id
      assert not is_nil(body["read_at"])
    end

    test "returns 404 for unknown notification ID", %{conn: conn} do
      user = make_user()

      conn =
        conn |> authed_conn(user) |> post("/api/v1/notifications/#{Ecto.UUID.generate()}/read")

      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/notifications/read_all
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/notifications/read_all" do
    test "marks all notifications read and returns count", %{conn: conn} do
      user = make_user()
      create_notification!(user)
      create_notification!(user)
      create_notification!(user)

      conn = conn |> authed_conn(user) |> post("/api/v1/notifications/read_all")
      assert %{"marked_read" => 3} = json_response(conn, 200)
      assert 0 = Notifications.unread_count(user.id)
    end

    test "returns 0 when no unread notifications", %{conn: conn} do
      user = make_user()
      conn = conn |> authed_conn(user) |> post("/api/v1/notifications/read_all")
      assert %{"marked_read" => 0} = json_response(conn, 200)
    end

    test "returns 0 when unauthenticated", %{conn: conn} do
      conn = post(conn, "/api/v1/notifications/read_all")
      assert %{"marked_read" => 0} = json_response(conn, 200)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/notifications/:id
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/notifications/:id" do
    test "deletes the notification and returns it", %{conn: conn} do
      user = make_user()
      n = create_notification!(user)

      conn = conn |> authed_conn(user) |> delete("/api/v1/notifications/#{n.id}")
      body = json_response(conn, 200)
      assert body["id"] == n.id
      assert [] = Notifications.list_for_user(user.id)
    end

    test "returns 404 for unknown notification ID", %{conn: conn} do
      user = make_user()
      conn = conn |> authed_conn(user) |> delete("/api/v1/notifications/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end
end
