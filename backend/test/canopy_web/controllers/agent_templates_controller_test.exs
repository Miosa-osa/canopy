defmodule CanopyWeb.AgentTemplatesControllerTest do
  @moduledoc """
  Tests for the AgentTemplatesController endpoints:
    GET  /api/v1/agent-templates              — list templates
    GET  /api/v1/agent-templates/:slug        — get single template
    POST /api/v1/agents/from-template         — clone template into a real agent
  """

  use CanopyWeb.ConnCase, async: false

  alias Canopy.Agents.Template
  alias Canopy.Repo

  # Seed a couple of templates for tests
  defp insert_template!(attrs \\ %{}) do
    defaults = %{
      slug: "tpl-test-#{:rand.uniform(99_999)}",
      name: "Test Template",
      description: "A test template",
      category: "engineering",
      persona_markdown: "You are a test agent.",
      icon: "🤖",
      color: "#374151",
      sort_order: 0,
      capabilities: ["read_files"],
      skill_slugs: []
    }

    attrs = Map.merge(defaults, attrs)
    {:ok, tpl} = Repo.insert(Template.changeset(%Template{}, attrs))
    tpl
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/agent-templates
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/agent-templates" do
    test "returns 200 with data array", %{conn: conn} do
      insert_template!(%{slug: "tpl-list-a", name: "List A"})
      insert_template!(%{slug: "tpl-list-b", name: "List B"})

      conn = get(conn, "/api/v1/agent-templates")
      assert %{"data" => templates} = json_response(conn, 200)
      assert is_list(templates)
      slugs = Enum.map(templates, & &1["slug"])
      assert "tpl-list-a" in slugs
      assert "tpl-list-b" in slugs
    end

    test "returns templates ordered by sort_order then name", %{conn: conn} do
      insert_template!(%{slug: "tpl-order-z", name: "Z Template", sort_order: 2})
      insert_template!(%{slug: "tpl-order-a", name: "A Template", sort_order: 1})

      conn = get(conn, "/api/v1/agent-templates")
      %{"data" => templates} = json_response(conn, 200)
      orders = Enum.map(templates, & &1["sort_order"])
      assert orders == Enum.sort(orders)
    end

    test "filters by category when ?category= is provided", %{conn: conn} do
      insert_template!(%{slug: "tpl-eng-cat", name: "Eng", category: "engineering"})
      insert_template!(%{slug: "tpl-prod-cat", name: "Prod", category: "product"})

      conn = get(conn, "/api/v1/agent-templates?category=engineering")
      %{"data" => templates} = json_response(conn, 200)
      assert Enum.all?(templates, &(&1["category"] == "engineering"))
      slugs = Enum.map(templates, & &1["slug"])
      assert "tpl-eng-cat" in slugs
      refute "tpl-prod-cat" in slugs
    end

    test "returns empty data array when no templates match category", %{conn: conn} do
      conn = get(conn, "/api/v1/agent-templates?category=nonexistent-category-xyz")
      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/agent-templates/:slug
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/agent-templates/:slug" do
    test "returns 200 with template detail", %{conn: conn} do
      tpl = insert_template!(%{slug: "tpl-show-detail", name: "Show Detail"})

      conn = get(conn, "/api/v1/agent-templates/#{tpl.slug}")
      assert body = json_response(conn, 200)
      assert body["slug"] == tpl.slug
      assert body["name"] == tpl.name
      assert body["category"] == tpl.category
      assert body["persona_markdown"] == tpl.persona_markdown
      assert is_list(body["capabilities"])
      assert is_list(body["skill_slugs"])
    end

    test "returns 404 for unknown slug", %{conn: conn} do
      conn = get(conn, "/api/v1/agent-templates/does-not-exist-xyz")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/agents/from-template
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/agents/from-template" do
    test "clones template into a hired agent with 201", %{conn: conn} do
      tpl =
        insert_template!(%{
          slug: "tpl-clone-src",
          name: "Clone Source",
          category: "engineering",
          persona_markdown: "You are a cloned agent.",
          capabilities: ["read_files", "write_files"]
        })

      conn =
        post(conn, "/api/v1/agents/from-template", %{template_slug: tpl.slug})

      assert body = json_response(conn, 201)
      assert body["slug"] == tpl.slug
      assert body["name"] == tpl.name
      assert body["hired"] == true
      assert body["persona_content"] == tpl.persona_markdown
    end

    test "accepts custom name and slug overrides", %{conn: conn} do
      tpl = insert_template!(%{slug: "tpl-override-src", name: "Override Source"})

      conn =
        post(conn, "/api/v1/agents/from-template", %{
          template_slug: tpl.slug,
          name: "My Custom Agent",
          slug: "my-custom-agent"
        })

      assert body = json_response(conn, 201)
      assert body["slug"] == "my-custom-agent"
      assert body["name"] == "My Custom Agent"
    end

    test "stores template capabilities in agent config", %{conn: conn} do
      tpl =
        insert_template!(%{
          slug: "tpl-caps-src",
          name: "Caps Source",
          capabilities: ["read_files", "post_comments"]
        })

      conn =
        post(conn, "/api/v1/agents/from-template", %{template_slug: tpl.slug})

      assert body = json_response(conn, 201)
      config = body["config"]
      assert config["capabilities"] == ["read_files", "post_comments"]
      assert config["from_template"] == tpl.slug
    end

    test "returns 404 when template_slug does not exist", %{conn: conn} do
      conn =
        post(conn, "/api/v1/agents/from-template", %{
          template_slug: "does-not-exist-xyz"
        })

      assert json_response(conn, 404)
    end

    test "returns error when slug conflicts with existing agent", %{conn: conn} do
      tpl = insert_template!(%{slug: "tpl-conflict-src", name: "Conflict Source"})

      # First clone — succeeds
      post(conn, "/api/v1/agents/from-template", %{template_slug: tpl.slug})

      # Second clone with same slug — should conflict
      conn2 = build_conn()
      conn2 = post(conn2, "/api/v1/agents/from-template", %{template_slug: tpl.slug})
      assert json_response(conn2, 422)
    end
  end
end
