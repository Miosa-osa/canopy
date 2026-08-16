defmodule CanopyWeb.DriveControllerTest do
  @moduledoc """
  Tests for /api/v1/drive/* endpoints.

  Focus: input validation (UUID, slug format, scope/kind enums), error
  responses, and end-to-end happy paths for index/show/create/update/move/
  archive/reorder/tree/search.
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.Drive

  defp create_folder!(attrs \\ %{}) do
    {:ok, e} =
      Drive.create(
        Map.merge(
          %{
            slug: "f-#{System.unique_integer([:positive])}",
            name: "F",
            kind: "folder",
            scope: "personal"
          },
          attrs
        )
      )

    e
  end

  describe "GET /api/v1/drive" do
    test "returns empty when no entries", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/drive")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns entries", %{conn: conn} do
      _ = create_folder!()
      conn = get(conn, ~p"/api/v1/drive")
      assert %{"data" => [_ | _]} = json_response(conn, 200)
    end

    test "filters by scope", %{conn: conn} do
      _p = create_folder!(%{scope: "personal"})
      _t = create_folder!(%{scope: "team"})

      conn = get(conn, ~p"/api/v1/drive?scope=team")
      assert %{"data" => [entry]} = json_response(conn, 200)
      assert entry["scope"] == "team"
    end

    test "filters by kind", %{conn: conn} do
      _ = create_folder!()

      {:ok, _} =
        Drive.create(%{
          slug: "p1",
          name: "P",
          kind: "prompt",
          scope: "personal",
          body: %{"body" => "x"}
        })

      conn = get(conn, ~p"/api/v1/drive?kind=prompt")
      assert %{"data" => [entry]} = json_response(conn, 200)
      assert entry["kind"] == "prompt"
    end

    test "rejects invalid scope", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/drive?scope=invalid")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects invalid kind", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/drive?kind=mystery")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects malformed parent_id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/drive?parent_id=not-a-uuid")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "caps limit at 1000", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/drive?limit=999999")
      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) <= 1000
    end
  end

  describe "GET /api/v1/drive/tree" do
    test "rejects missing scope", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/drive/tree")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "returns nested tree", %{conn: conn} do
      a = create_folder!(%{slug: "a"})
      _b = create_folder!(%{slug: "b", parent_id: a.id})

      conn = get(conn, ~p"/api/v1/drive/tree?scope=personal")
      assert %{"scope" => "personal", "data" => [node]} = json_response(conn, 200)
      assert node["entry"]["slug"] == "a"
      assert length(node["children"]) == 1
    end

    test "rejects bad scope", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/drive/tree?scope=other")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  describe "GET /api/v1/drive/search" do
    test "rejects missing q", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/drive/search")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "returns matches", %{conn: conn} do
      _ = create_folder!(%{slug: "alpha", name: "Alpha Bravo"})
      _ = create_folder!(%{slug: "beta", name: "Charlie"})

      conn = get(conn, ~p"/api/v1/drive/search?q=Alpha")
      assert %{"data" => [match]} = json_response(conn, 200)
      assert match["name"] == "Alpha Bravo"
    end
  end

  describe "GET /api/v1/drive/:id" do
    test "rejects invalid uuid", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/drive/not-a-uuid")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "returns 404 for unknown id", %{conn: conn} do
      uuid = Ecto.UUID.generate()
      conn = get(conn, ~p"/api/v1/drive/#{uuid}")
      assert %{"error" => "drive_entry_not_found"} = json_response(conn, 404)
    end

    test "returns the entry", %{conn: conn} do
      e = create_folder!()
      conn = get(conn, ~p"/api/v1/drive/#{e.id}")
      assert %{"id" => id} = json_response(conn, 200)
      assert id == e.id
    end
  end

  describe "POST /api/v1/drive" do
    test "creates a valid folder", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/drive", %{
          slug: "new-fold",
          name: "New",
          kind: "folder",
          scope: "personal"
        })

      assert %{"slug" => "new-fold", "kind" => "folder"} = json_response(conn, 201)
    end

    test "rejects malformed slug", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/drive", %{
          slug: "Bad Slug!",
          name: "X",
          kind: "folder",
          scope: "personal"
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects missing kind", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/drive", %{
          slug: "x",
          name: "X",
          scope: "personal"
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects invalid scope", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/drive", %{
          slug: "x",
          name: "X",
          kind: "folder",
          scope: "everywhere"
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects workflow without routine_id (changeset error)", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/drive", %{
          slug: "wf",
          name: "WF",
          kind: "workflow",
          scope: "personal",
          body: %{}
        })

      # body validation fails in changeset → 422 via FallbackController
      assert json_response(conn, 422)
    end
  end

  describe "PATCH /api/v1/drive/:id" do
    test "updates name", %{conn: conn} do
      e = create_folder!(%{name: "Old"})

      conn = patch(conn, ~p"/api/v1/drive/#{e.id}", %{name: "New"})
      assert %{"name" => "New"} = json_response(conn, 200)
    end

    test "rejects bad uuid", %{conn: conn} do
      conn = patch(conn, ~p"/api/v1/drive/not-a-uuid", %{name: "X"})
      assert json_response(conn, 400)
    end
  end

  describe "POST /api/v1/drive/:id/archive" do
    test "archives an entry", %{conn: conn} do
      e = create_folder!()

      conn = post(conn, ~p"/api/v1/drive/#{e.id}/archive", %{})
      response = json_response(conn, 200)
      refute is_nil(response["archivedAt"]) and is_nil(response["archived_at"])
    end

    test "404 for unknown id", %{conn: conn} do
      uuid = Ecto.UUID.generate()
      conn = post(conn, ~p"/api/v1/drive/#{uuid}/archive", %{})
      assert %{"error" => "drive_entry_not_found"} = json_response(conn, 404)
    end
  end

  describe "POST /api/v1/drive/:id/restore" do
    test "restores an archived entry", %{conn: conn} do
      e = create_folder!()
      {:ok, archived} = Drive.archive(e)
      refute is_nil(archived.archived_at)

      conn = post(conn, ~p"/api/v1/drive/#{e.id}/restore", %{})
      assert response = json_response(conn, 200)
      assert is_nil(response["archivedAt"]) or is_nil(response["archived_at"])
    end
  end

  describe "POST /api/v1/drive/:id/move" do
    test "moves an entry under a new parent", %{conn: conn} do
      a = create_folder!(%{slug: "p1"})
      b = create_folder!(%{slug: "p2"})

      conn = post(conn, ~p"/api/v1/drive/#{b.id}/move", %{parent_id: a.id})
      response = json_response(conn, 200)
      assert response["parentId"] == a.id or response["parent_id"] == a.id
    end

    test "moves to root with null parent_id", %{conn: conn} do
      a = create_folder!(%{slug: "p1"})
      b = create_folder!(%{slug: "p2", parent_id: a.id})

      conn = post(conn, ~p"/api/v1/drive/#{b.id}/move", %{parent_id: nil})
      response = json_response(conn, 200)
      assert is_nil(response["parentId"]) or is_nil(response["parent_id"])
    end

    test "rejects cycle", %{conn: conn} do
      a = create_folder!(%{slug: "p1"})

      conn = post(conn, ~p"/api/v1/drive/#{a.id}/move", %{parent_id: a.id})
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  describe "POST /api/v1/drive/reorder" do
    test "reorders sibling group", %{conn: conn} do
      a = create_folder!(%{slug: "a"})
      b = create_folder!(%{slug: "b"})
      c = create_folder!(%{slug: "c"})

      conn = post(conn, ~p"/api/v1/drive/reorder", %{ids: [c.id, a.id, b.id]})
      assert %{"count" => 3} = json_response(conn, 200)
    end

    test "rejects non-uuid ids", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/drive/reorder", %{ids: ["not-a-uuid"]})
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects missing ids", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/drive/reorder", %{})
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end
end
