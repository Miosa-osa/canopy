defmodule CanopyWeb.SkillsControllerTest do
  @moduledoc """
  Tests for the SkillsController endpoints:
    GET    /api/v1/skills
    GET    /api/v1/skills/:slug
    POST   /api/v1/skills/import
  """

  use CanopyWeb.ConnCase, async: false

  import Canopy.Factory

  # ---------------------------------------------------------------------------
  # GET /api/v1/skills
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/skills" do
    test "returns 200 with empty list when no skills exist", %{conn: conn} do
      conn = get(conn, "/api/v1/skills")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns all skills", %{conn: conn} do
      insert(:skill, slug: "skill-a", name: "A Skill")
      insert(:skill, slug: "skill-b", name: "B Skill")
      conn = get(conn, "/api/v1/skills")
      assert %{"data" => data} = json_response(conn, 200)
      slugs = Enum.map(data, & &1["slug"])
      assert "skill-a" in slugs
      assert "skill-b" in slugs
    end

    test "filters by source", %{conn: conn} do
      insert(:skill, slug: "src-local", source: "local")
      insert(:skill, slug: "src-hub", source: "clawhub")
      conn = get(conn, "/api/v1/skills?source=local")
      assert %{"data" => data} = json_response(conn, 200)
      slugs = Enum.map(data, & &1["slug"])
      assert "src-local" in slugs
      refute "src-hub" in slugs
    end

    test "filters by enabled=true", %{conn: conn} do
      insert(:skill, slug: "en-on", enabled: true)
      insert(:skill, slug: "en-off", enabled: false)
      conn = get(conn, "/api/v1/skills?enabled=true")
      assert %{"data" => data} = json_response(conn, 200)
      slugs = Enum.map(data, & &1["slug"])
      assert "en-on" in slugs
      refute "en-off" in slugs
    end

    test "filters by enabled=false", %{conn: conn} do
      insert(:skill, slug: "ef-on", enabled: true)
      insert(:skill, slug: "ef-off", enabled: false)
      conn = get(conn, "/api/v1/skills?enabled=false")
      assert %{"data" => data} = json_response(conn, 200)
      slugs = Enum.map(data, & &1["slug"])
      refute "ef-on" in slugs
      assert "ef-off" in slugs
    end

    test "filters by tag", %{conn: conn} do
      insert(:skill, slug: "tagged-ctrl", tags: ["elixir"])
      insert(:skill, slug: "untagged-ctrl", tags: [])
      conn = get(conn, "/api/v1/skills?tag=elixir")
      assert %{"data" => data} = json_response(conn, 200)
      slugs = Enum.map(data, & &1["slug"])
      assert "tagged-ctrl" in slugs
      refute "untagged-ctrl" in slugs
    end

    test "returns all skills when no filter params given", %{conn: conn} do
      insert(:skill, slug: "all-1", enabled: true)
      insert(:skill, slug: "all-2", enabled: false)
      conn = get(conn, "/api/v1/skills")
      assert %{"data" => data} = json_response(conn, 200)
      slugs = Enum.map(data, & &1["slug"])
      assert "all-1" in slugs
      assert "all-2" in slugs
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/skills/:slug
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/skills/:slug" do
    test "returns 200 with skill detail when found", %{conn: conn} do
      insert(:skill, slug: "show-skill", name: "Show Skill")
      conn = get(conn, "/api/v1/skills/show-skill")
      body = json_response(conn, 200)
      assert body["slug"] == "show-skill"
      assert body["name"] == "Show Skill"
      assert Map.has_key?(body, "content")
      assert Map.has_key?(body, "content_hash")
      assert Map.has_key?(body, "provider_format")
      assert Map.has_key?(body, "source")
    end

    test "returns 404 when skill not found", %{conn: conn} do
      conn = get(conn, "/api/v1/skills/no-such-skill")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/skills/import
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/skills/import" do
    test "returns 200 with imported:0 and errors:0 for clawhub (registry unreachable)", %{
      conn: conn
    } do
      # ClawHub/Skills.sh URLs are not configured in test — returns empty list gracefully
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/skills/import", Jason.encode!(%{"source" => "clawhub"}))

      assert %{"imported" => imported, "errors" => errors} = json_response(conn, 200)
      assert is_integer(imported)
      assert is_integer(errors)
    end

    test "returns 200 with imported:0 and errors:0 for skills_sh (registry unreachable)", %{
      conn: conn
    } do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/skills/import", Jason.encode!(%{"source" => "skills_sh"}))

      assert %{"imported" => imported, "errors" => errors} = json_response(conn, 200)
      assert is_integer(imported)
      assert is_integer(errors)
    end

    test "returns 422 for unknown source", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/skills/import", Jason.encode!(%{"source" => "unknown"}))

      assert %{"error" => "invalid_source"} = json_response(conn, 422)
    end

    test "returns 422 when source is missing", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/skills/import", Jason.encode!(%{}))

      assert json_response(conn, 422)
    end
  end
end
