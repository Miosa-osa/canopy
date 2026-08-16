defmodule CanopyWeb.WorkspaceStatesControllerTest do
  @moduledoc """
  HTTP-level tests for `/api/v1/workspaces/:slug/state*`.

  Covers happy paths, slug/key validation, missing-workspace 404, missing-key
  404, oversized-value 422, and per-workspace key cap 422.
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.Workspaces
  alias Canopy.Workspaces.States

  defp setup_ws(_ctx) do
    slug = "ctl-#{System.unique_integer([:positive])}"

    tmp_dir =
      System.tmp_dir!()
      |> Path.join("canopy-states-ctl-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(tmp_dir) end)

    {:ok, ws} =
      Workspaces.create(%{slug: slug, name: "Controller WS", root_path: tmp_dir})

    {:ok, workspace: ws}
  end

  describe "GET /api/v1/workspaces/:slug/state" do
    setup :setup_ws

    test "returns empty map when no state exists", %{conn: conn, workspace: ws} do
      conn = get(conn, ~p"/api/v1/workspaces/#{ws.slug}/state")
      assert %{"workspace_slug" => slug, "data" => %{}} = json_response(conn, 200)
      assert slug == ws.slug
    end

    test "returns all entries for the workspace", %{conn: conn, workspace: ws} do
      {:ok, _} = States.put(ws.slug, "a", 1)
      {:ok, _} = States.put(ws.slug, "b", %{"nested" => true})

      conn = get(conn, ~p"/api/v1/workspaces/#{ws.slug}/state")
      assert %{"data" => %{"a" => 1, "b" => %{"nested" => true}}} = json_response(conn, 200)
    end

    test "returns 404 for unknown workspace", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/workspaces/no-such-workspace/state")
      assert %{"error" => "workspace_not_found"} = json_response(conn, 404)
    end

    test "returns 400 for malformed slug", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/workspaces/Bad_Slug!/state")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  describe "GET /api/v1/workspaces/:slug/state/:key" do
    setup :setup_ws

    test "returns the stored value", %{conn: conn, workspace: ws} do
      {:ok, _} = States.put(ws.slug, "mosaic.layout", %{"split" => "vertical"})

      conn = get(conn, ~p"/api/v1/workspaces/#{ws.slug}/state/mosaic.layout")
      assert %{"key" => "mosaic.layout", "value" => %{"split" => "vertical"}} =
               json_response(conn, 200)
    end

    test "returns 404 for missing key", %{conn: conn, workspace: ws} do
      conn = get(conn, ~p"/api/v1/workspaces/#{ws.slug}/state/never.set")
      assert %{"error" => "state_not_found"} = json_response(conn, 404)
    end

    test "returns 400 for malformed key", %{conn: conn, workspace: ws} do
      conn = get(conn, ~p"/api/v1/workspaces/#{ws.slug}/state/Bad!Key")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  describe "PUT /api/v1/workspaces/:slug/state/:key" do
    setup :setup_ws

    test "creates a new entry", %{conn: conn, workspace: ws} do
      conn =
        put(
          conn,
          ~p"/api/v1/workspaces/#{ws.slug}/state/build.density",
          %{value: "compact"}
        )

      assert %{"key" => "build.density", "value" => "compact"} = json_response(conn, 200)
      assert {:ok, "compact"} = States.get(ws.slug, "build.density")
    end

    test "updates an existing entry", %{conn: conn, workspace: ws} do
      {:ok, _} = States.put(ws.slug, "x", 1)

      conn = put(conn, ~p"/api/v1/workspaces/#{ws.slug}/state/x", %{value: 2})
      assert %{"value" => 2} = json_response(conn, 200)
    end

    test "returns 400 when body has no 'value' field", %{conn: conn, workspace: ws} do
      conn = put(conn, ~p"/api/v1/workspaces/#{ws.slug}/state/anything", %{})
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "returns 422 for oversized value", %{conn: conn, workspace: ws} do
      huge = String.duplicate("z", 1_048_577)

      conn =
        put(
          conn,
          ~p"/api/v1/workspaces/#{ws.slug}/state/big.blob",
          %{value: huge}
        )

      assert %{"error" => "value_too_large"} = json_response(conn, 422)
    end

    test "returns 422 when at the per-workspace key cap", %{conn: conn, workspace: ws} do
      for i <- 1..States.max_keys_per_workspace() do
        {:ok, _} = States.put(ws.slug, "fill.#{i}", i)
      end

      conn =
        put(
          conn,
          ~p"/api/v1/workspaces/#{ws.slug}/state/overflow",
          %{value: 1}
        )

      assert %{"error" => "too_many_keys"} = json_response(conn, 422)
    end

    test "returns 404 for unknown workspace", %{conn: conn} do
      conn =
        put(
          conn,
          ~p"/api/v1/workspaces/missing-ws/state/key",
          %{value: 1}
        )

      assert %{"error" => "workspace_not_found"} = json_response(conn, 404)
    end
  end

  describe "DELETE /api/v1/workspaces/:slug/state/:key" do
    setup :setup_ws

    test "removes a stored entry", %{conn: conn, workspace: ws} do
      {:ok, _} = States.put(ws.slug, "drop.me", true)

      conn = delete(conn, ~p"/api/v1/workspaces/#{ws.slug}/state/drop.me")
      assert %{"deleted" => true} = json_response(conn, 200)
      assert {:error, :not_found} = States.get(ws.slug, "drop.me")
    end

    test "returns 404 for missing key", %{conn: conn, workspace: ws} do
      conn = delete(conn, ~p"/api/v1/workspaces/#{ws.slug}/state/never.set")
      assert %{"error" => "state_not_found"} = json_response(conn, 404)
    end
  end
end
