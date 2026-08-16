defmodule CanopyWeb.AgentSkillsControllerTest do
  @moduledoc """
  Tests for agent ↔ skill assignment endpoints:
    GET    /api/v1/agents/:slug/skills
    POST   /api/v1/agents/:slug/skills
    DELETE /api/v1/agents/:slug/skills/:skill_slug
  """

  use CanopyWeb.ConnCase, async: false

  import Canopy.Factory

  alias Canopy.Skills

  # ---------------------------------------------------------------------------
  # GET /api/v1/agents/:slug/skills
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/agents/:slug/skills" do
    test "returns 200 with empty data when agent has no assignments", %{conn: conn} do
      agent = insert(:agent)
      conn = get(conn, "/api/v1/agents/#{agent.slug}/skills")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns assigned skills with joined skill data", %{conn: conn} do
      agent = insert(:agent)
      skill = insert(:skill, slug: "assigned-skill-ctrl", name: "Assigned Skill")
      {:ok, _} = Skills.assign(agent.slug, skill.slug)

      conn = get(conn, "/api/v1/agents/#{agent.slug}/skills")
      assert %{"data" => [assignment]} = json_response(conn, 200)
      assert assignment["skill_slug"] == "assigned-skill-ctrl"
      assert assignment["agent_slug"] == agent.slug
      assert is_map(assignment["skill"])
      assert assignment["skill"]["name"] == "Assigned Skill"
    end

    test "returns 404 for unknown agent slug", %{conn: conn} do
      conn = get(conn, "/api/v1/agents/no-such-agent/skills")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/agents/:slug/skills
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/agents/:slug/skills" do
    test "assigns a skill and returns 201", %{conn: conn} do
      agent = insert(:agent)
      skill = insert(:skill, slug: "to-assign-ctrl")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          "/api/v1/agents/#{agent.slug}/skills",
          Jason.encode!(%{"skill_slug" => skill.slug})
        )

      assert json_response(conn, 201)["skill_slug"] == skill.slug
      assert json_response(conn, 201)["agent_slug"] == agent.slug
    end

    test "respects priority param", %{conn: conn} do
      agent = insert(:agent)
      skill = insert(:skill, slug: "prio-ctrl-skill")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          "/api/v1/agents/#{agent.slug}/skills",
          Jason.encode!(%{"skill_slug" => skill.slug, "priority" => 5})
        )

      assert json_response(conn, 201)["priority"] == 5
    end

    test "returns 422 when skill_slug is missing", %{conn: conn} do
      agent = insert(:agent)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          "/api/v1/agents/#{agent.slug}/skills",
          Jason.encode!(%{})
        )

      assert json_response(conn, 422)["error"] == "missing_skill_slug"
    end

    test "returns 404 when agent does not exist", %{conn: conn} do
      skill = insert(:skill, slug: "assign-no-agent-ctrl")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          "/api/v1/agents/no-such-agent/skills",
          Jason.encode!(%{"skill_slug" => skill.slug})
        )

      assert json_response(conn, 404)
    end

    test "returns 404 when skill does not exist", %{conn: conn} do
      agent = insert(:agent)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          "/api/v1/agents/#{agent.slug}/skills",
          Jason.encode!(%{"skill_slug" => "no-such-skill"})
        )

      assert json_response(conn, 404)
    end

    test "returns 422 when skill is already assigned", %{conn: conn} do
      agent = insert(:agent)
      skill = insert(:skill, slug: "dup-assign-ctrl")
      {:ok, _} = Skills.assign(agent.slug, skill.slug)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          "/api/v1/agents/#{agent.slug}/skills",
          Jason.encode!(%{"skill_slug" => skill.slug})
        )

      # unique constraint violation → changeset error → 422 via FallbackController
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/agents/:slug/skills/:skill_slug
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/agents/:slug/skills/:skill_slug" do
    test "removes assignment and returns 204", %{conn: conn} do
      agent = insert(:agent)
      skill = insert(:skill, slug: "to-remove-ctrl")
      {:ok, _} = Skills.assign(agent.slug, skill.slug)

      conn = delete(conn, "/api/v1/agents/#{agent.slug}/skills/#{skill.slug}")
      assert conn.status == 204

      # Confirm assignment gone
      {:ok, assignments} = Skills.list_assignments(agent.slug)
      slugs = Enum.map(assignments, & &1.skill_slug)
      refute skill.slug in slugs
    end

    test "returns 404 when assignment does not exist", %{conn: conn} do
      agent = insert(:agent)
      conn = delete(conn, "/api/v1/agents/#{agent.slug}/skills/no-such-skill")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/v1/skills/:slug — update endpoint
  # ---------------------------------------------------------------------------

  describe "PUT /api/v1/skills/:slug" do
    test "updates skill content and recomputes hash", %{conn: conn} do
      skill = insert(:skill, slug: "update-content-ctrl")
      new_content = "# Updated content for test"

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put("/api/v1/skills/#{skill.slug}", Jason.encode!(%{"content" => new_content}))

      body = json_response(conn, 200)
      assert body["content"] == new_content
      expected_hash = :crypto.hash(:sha256, new_content) |> Base.encode16(case: :lower)
      assert body["content_hash"] == expected_hash
    end

    test "updates kind", %{conn: conn} do
      skill = insert(:skill, slug: "update-kind-ctrl", kind: "prompt")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put("/api/v1/skills/#{skill.slug}", Jason.encode!(%{"kind" => "workflow"}))

      assert json_response(conn, 200)["kind"] == "workflow"
    end

    test "updates frontmatter", %{conn: conn} do
      skill = insert(:skill, slug: "update-fm-ctrl")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put(
          "/api/v1/skills/#{skill.slug}",
          Jason.encode!(%{"frontmatter" => %{"when" => "code-review"}})
        )

      assert json_response(conn, 200)["frontmatter"] == %{"when" => "code-review"}
    end

    test "returns 404 for unknown skill", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put("/api/v1/skills/no-such-skill", Jason.encode!(%{"name" => "Oops"}))

      assert json_response(conn, 404)
    end

    test "returns 422 for invalid kind", %{conn: conn} do
      skill = insert(:skill, slug: "update-invalid-kind-ctrl")

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put("/api/v1/skills/#{skill.slug}", Jason.encode!(%{"kind" => "bogus"}))

      assert json_response(conn, 422)
    end
  end
end
