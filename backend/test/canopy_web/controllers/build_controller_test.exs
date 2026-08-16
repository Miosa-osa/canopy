defmodule CanopyWeb.BuildControllerTest do
  @moduledoc """
  Tests for /api/v1/build/* endpoints.

  Focus: input validation (slug format, scope, UUID), error responses,
  end-to-end happy paths for layouts CRUD, suggest, default, set-default.
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.Build

  describe "GET /api/v1/build/layouts" do
    test "returns empty when none exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/build/layouts")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "lists created layouts", %{conn: conn} do
      {:ok, _} = Build.create_layout(%{slug: "x", name: "X"})
      conn = get(conn, ~p"/api/v1/build/layouts")
      assert %{"data" => [layout]} = json_response(conn, 200)
      assert layout["slug"] == "x"
    end

    test "filters by scope", %{conn: conn} do
      {:ok, _} = Build.create_layout(%{slug: "p", name: "P", scope: "personal"})

      {:ok, _} =
        Build.create_layout(%{
          slug: "w",
          name: "W",
          scope: "workspace",
          workspace_slug: "alpha"
        })

      conn = get(conn, ~p"/api/v1/build/layouts?scope=workspace")
      assert %{"data" => [layout]} = json_response(conn, 200)
      assert layout["slug"] == "w"
    end

    test "rejects invalid scope", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/build/layouts?scope=garbage")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects invalid owner_id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/build/layouts?owner_id=not-a-uuid")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  describe "GET /api/v1/build/layouts/:slug" do
    test "returns layout by slug", %{conn: conn} do
      {:ok, _} = Build.create_layout(%{slug: "review-pr", name: "Review PR"})
      conn = get(conn, ~p"/api/v1/build/layouts/review-pr")
      assert %{"slug" => "review-pr", "name" => "Review PR"} = json_response(conn, 200)
    end

    test "404 when missing", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/build/layouts/nope")
      assert %{"error" => "layout_not_found"} = json_response(conn, 404)
    end

    test "rejects malformed slug", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/build/layouts/Bad%20Slug")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  describe "POST /api/v1/build/layouts" do
    test "creates a layout", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/build/layouts", %{
          slug: "fix-bug",
          name: "Fix Bug"
        })

      assert %{"slug" => "fix-bug"} = json_response(conn, 201)
    end

    test "rejects malformed slug", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/build/layouts", %{
          slug: "Bad Slug!",
          name: "X"
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects invalid scope", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/build/layouts", %{
          slug: "x",
          name: "X",
          scope: "global"
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  describe "PATCH /api/v1/build/layouts/:slug" do
    test "patches a layout", %{conn: conn} do
      {:ok, _} = Build.create_layout(%{slug: "u1", name: "Original"})

      conn =
        patch(conn, ~p"/api/v1/build/layouts/u1", %{
          name: "Renamed",
          density: "compact"
        })

      assert %{"name" => "Renamed", "density" => "compact"} = json_response(conn, 200)
    end

    test "404 when missing", %{conn: conn} do
      conn = patch(conn, ~p"/api/v1/build/layouts/nope", %{name: "X"})
      assert %{"error" => "layout_not_found"} = json_response(conn, 404)
    end
  end

  describe "DELETE /api/v1/build/layouts/:slug" do
    test "archives a layout (soft-delete)", %{conn: conn} do
      {:ok, _} = Build.create_layout(%{slug: "a1", name: "A"})

      conn = delete(conn, ~p"/api/v1/build/layouts/a1")
      assert %{"slug" => "a1", "archived_at" => archived_at} = json_response(conn, 200)
      assert archived_at != nil
    end

    test "404 when missing", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/build/layouts/nope")
      assert %{"error" => "layout_not_found"} = json_response(conn, 404)
    end
  end

  describe "POST /api/v1/build/suggest" do
    test "returns ranked suggestions", %{conn: conn} do
      {:ok, _} =
        Build.create_layout(%{
          slug: "review-pr",
          name: "Review PR",
          description: "diff + terminal"
        })

      {:ok, _} =
        Build.create_layout(%{
          slug: "fix-bug",
          name: "Fix Bug",
          description: "editor + tests"
        })

      conn = post(conn, ~p"/api/v1/build/suggest", %{intent: "review pr"})
      assert %{"suggestions" => [top | _]} = json_response(conn, 200)
      assert top["slug"] == "review-pr"
    end

    test "rejects empty intent", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/build/suggest", %{intent: ""})
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "returns empty suggestions when no layouts", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/build/suggest", %{intent: "anything"})
      assert %{"count" => 0, "suggestions" => []} = json_response(conn, 200)
    end
  end

  describe "GET /api/v1/build/default" do
    test "rejects missing workspace_slug", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/build/default")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "returns nil when no default set", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/build/default?workspace_slug=empty")
      assert %{"data" => nil} = json_response(conn, 200)
    end

    test "returns the default layout when set", %{conn: conn} do
      {:ok, _} =
        Build.create_layout(%{
          slug: "default",
          name: "Default",
          scope: "workspace",
          workspace_slug: "alpha"
        })

      conn = get(conn, ~p"/api/v1/build/default?workspace_slug=alpha")
      assert %{"data" => %{"slug" => "default"}} = json_response(conn, 200)
    end
  end

  describe "POST /api/v1/build/layouts/:slug/set-default" do
    test "promotes a layout to workspace default", %{conn: conn} do
      {:ok, _} = Build.create_layout(%{slug: "fix-bug", name: "Fix Bug"})

      conn =
        post(conn, ~p"/api/v1/build/layouts/fix-bug/set-default", %{
          workspace_slug: "alpha"
        })

      assert %{"slug" => "default", "scope" => "workspace", "workspace_slug" => "alpha"} =
               json_response(conn, 200)
    end

    test "404 when missing", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/build/layouts/nope/set-default", %{
          workspace_slug: "alpha"
        })

      assert %{"error" => "layout_not_found"} = json_response(conn, 404)
    end

    test "rejects missing workspace_slug", %{conn: conn} do
      {:ok, _} = Build.create_layout(%{slug: "x", name: "X"})
      conn = post(conn, ~p"/api/v1/build/layouts/x/set-default", %{})
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  describe "GET /api/v1/build/commands" do
    test "returns at least the 10 built-in commands on a fresh DB", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/build/commands")
      assert %{"data" => data} = json_response(conn, 200)
      builtins = Enum.filter(data, &(&1["source"] == "builtin"))
      assert length(builtins) == 10

      assert Enum.any?(builtins, &(&1["name"] == "/agent"))
      assert Enum.any?(builtins, &(&1["name"] == "/open-file"))
    end

    test "every command has the normalized shape", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/build/commands")
      assert %{"data" => [first | _]} = json_response(conn, 200)
      assert is_binary(first["namespace"])
      assert is_binary(first["name"])
      assert is_binary(first["description"])
      assert is_binary(first["icon"])
      assert is_binary(first["source"])
    end

    test "?q= narrows by substring on name+description (case-insensitive)", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/build/commands?q=AGENT")
      assert %{"data" => data} = json_response(conn, 200)
      assert Enum.any?(data, &(&1["name"] == "/agent"))
      refute Enum.any?(data, &(&1["name"] == "/review"))
    end

    test "empty ?q= returns everything", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/build/commands?q=")
      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) >= 10
    end

    test "?limit= caps the result", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/build/commands?limit=3")
      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) == 3
    end

    test "?limit= hard-caps at 200", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/build/commands?limit=9999")
      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) <= 200
    end
  end
end
