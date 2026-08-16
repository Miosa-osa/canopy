defmodule CanopyWeb.TemplatesControllerTest do
  @moduledoc """
  Tests for /api/v1/templates/* endpoints.

  Focus: input validation (UUID, slug format, kind enum, limit bounds),
  error responses, and end-to-end happy paths.
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.Templates

  describe "GET /api/v1/templates" do
    test "returns empty data when no templates", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/templates")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns templates ordered", %{conn: conn} do
      Templates.create_template(%{slug: "first", name: "First", kind: "workspace"})
      Templates.create_template(%{slug: "second", name: "Second", kind: "persona"})

      conn = get(conn, ~p"/api/v1/templates")
      assert %{"data" => templates} = json_response(conn, 200)
      assert length(templates) == 2
    end

    test "filters by kind", %{conn: conn} do
      Templates.create_template(%{slug: "ws-only", name: "W", kind: "workspace"})
      Templates.create_template(%{slug: "per-only", name: "P", kind: "persona"})

      conn = get(conn, ~p"/api/v1/templates?kind=workspace")
      assert %{"data" => [t]} = json_response(conn, 200)
      assert t["slug"] == "ws-only"
    end

    test "rejects invalid kind", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/templates?kind=spaceship")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "filters by verified=true", %{conn: conn} do
      Templates.create_template(%{slug: "v-yes", name: "V", kind: "workspace", verified: true})
      Templates.create_template(%{slug: "v-no", name: "V", kind: "workspace"})

      conn = get(conn, ~p"/api/v1/templates?verified=true")
      assert %{"data" => [t]} = json_response(conn, 200)
      assert t["slug"] == "v-yes"
    end

    test "caps limit at 1000", %{conn: conn} do
      for i <- 1..3 do
        Templates.create_template(%{slug: "lim-#{i}", name: "L", kind: "workspace"})
      end

      conn = get(conn, ~p"/api/v1/templates?limit=999999")
      assert %{"data" => templates} = json_response(conn, 200)
      assert length(templates) <= 1000
    end

    test "filters by search term", %{conn: conn} do
      Templates.create_template(%{slug: "match-me", name: "Findable", kind: "workspace"})
      Templates.create_template(%{slug: "skip-me", name: "Other", kind: "workspace"})

      conn = get(conn, ~p"/api/v1/templates?search=Findable")
      assert %{"data" => [t]} = json_response(conn, 200)
      assert t["slug"] == "match-me"
    end
  end

  describe "GET /api/v1/templates/:slug" do
    test "returns the template when it exists", %{conn: conn} do
      {:ok, _} = Templates.create_template(%{slug: "show-me", name: "Show", kind: "workspace"})

      conn = get(conn, ~p"/api/v1/templates/show-me")
      assert %{"slug" => "show-me", "kind" => "workspace"} = json_response(conn, 200)
    end

    test "returns 404 for unknown slug", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/templates/does-not-exist")
      assert %{"error" => "template_not_found"} = json_response(conn, 404)
    end

    test "rejects malformed slug", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/templates/BAD%20SLUG")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  describe "POST /api/v1/templates" do
    test "creates a valid template", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/templates", %{
          slug: "create-tpl",
          name: "Created",
          kind: "workspace"
        })

      assert %{"slug" => "create-tpl"} = json_response(conn, 201)
    end

    test "rejects malformed slug", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/templates", %{
          slug: "Invalid Slug With Spaces!",
          name: "X",
          kind: "workspace"
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects invalid kind", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/templates", %{
          slug: "bad-kind",
          name: "X",
          kind: "spaceship"
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects empty slug", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/templates", %{slug: "", name: "X", kind: "workspace"})

      assert json_response(conn, 400)
    end
  end

  describe "POST /api/v1/templates/:slug/preview" do
    test "renders parameter-substituted body", %{conn: conn} do
      {:ok, _} =
        Templates.create_template(%{
          slug: "prev-tpl",
          name: "Preview",
          kind: "persona",
          body: %{"identity" => "You are {{role}}."},
          parameters: %{"role" => %{"type" => "string", "required" => true}}
        })

      conn =
        post(conn, ~p"/api/v1/templates/prev-tpl/preview", %{
          params: %{role: "analyst"}
        })

      assert %{"body" => %{"identity" => "You are analyst."}} = json_response(conn, 200)
    end

    test "returns 400 with missing parameters", %{conn: conn} do
      {:ok, _} =
        Templates.create_template(%{
          slug: "prev-missing",
          name: "Preview",
          kind: "persona",
          body: %{"x" => "{{a}}"},
          parameters: %{"a" => %{"type" => "string", "required" => true}}
        })

      conn = post(conn, ~p"/api/v1/templates/prev-missing/preview", %{params: %{}})
      assert %{"error" => "missing_parameters", "missing" => ["a"]} = json_response(conn, 400)
    end

    test "returns 404 for unknown template", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/templates/never-existed/preview", %{params: %{}})
      assert %{"error" => "template_not_found"} = json_response(conn, 404)
    end
  end

  describe "POST /api/v1/templates/:slug/instantiate" do
    test "creates an instantiation row", %{conn: conn} do
      {:ok, _} =
        Templates.create_template(%{
          slug: "inst-ws",
          name: "I",
          kind: "workspace",
          body: %{"files" => [%{"path" => "company.yaml", "content" => "name: {{ws}}"}]},
          parameters: %{"ws" => %{"type" => "string", "required" => true}}
        })

      conn =
        post(conn, ~p"/api/v1/templates/inst-ws/instantiate", %{
          target_workspace_slug: "new-ws",
          params: %{ws: "new-ws"}
        })

      assert %{
               "template_slug" => "inst-ws",
               "target_workspace_slug" => "new-ws",
               "status" => "success",
               "files_written" => 1
             } = json_response(conn, 200)
    end

    test "rejects invalid agent UUID", %{conn: conn} do
      {:ok, _} = Templates.create_template(%{slug: "u-tpl", name: "U", kind: "workspace"})

      conn =
        post(conn, ~p"/api/v1/templates/u-tpl/instantiate", %{
          instantiated_by_agent_id: "not-a-uuid"
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "returns 400 on missing required params", %{conn: conn} do
      {:ok, _} =
        Templates.create_template(%{
          slug: "inst-missing",
          name: "M",
          kind: "workspace",
          parameters: %{"required_field" => %{"type" => "string", "required" => true}}
        })

      conn = post(conn, ~p"/api/v1/templates/inst-missing/instantiate", %{params: %{}})
      assert %{"error" => "missing_parameters"} = json_response(conn, 400)
    end
  end

  describe "POST /api/v1/templates/:slug/publish" do
    test "publishes a template", %{conn: conn} do
      {:ok, _} =
        Templates.create_template(%{
          slug: "pub-tpl",
          name: "P",
          kind: "persona",
          body: %{"x" => "v1"}
        })

      conn =
        post(conn, ~p"/api/v1/templates/pub-tpl/publish", %{
          version: "1.0.0",
          changelog: "First"
        })

      assert %{"template" => %{"published" => true, "version" => "1.0.0"}} =
               json_response(conn, 200)
    end

    test "returns 404 for unknown slug", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/templates/does-not-exist/publish", %{})
      assert %{"error" => "template_not_found"} = json_response(conn, 404)
    end
  end

  describe "POST /api/v1/templates/:slug/fork" do
    test "forks a template", %{conn: conn} do
      {:ok, _} = Templates.create_template(%{slug: "src-tpl", name: "Src", kind: "workspace"})

      conn =
        post(conn, ~p"/api/v1/templates/src-tpl/fork", %{
          new_slug: "dst-tpl",
          new_name: "Dest"
        })

      assert %{
               "slug" => "dst-tpl",
               "name" => "Dest",
               "forked_from_slug" => "src-tpl"
             } = json_response(conn, 201)
    end

    test "rejects malformed new_slug", %{conn: conn} do
      {:ok, _} = Templates.create_template(%{slug: "src-2", name: "S", kind: "workspace"})

      conn =
        post(conn, ~p"/api/v1/templates/src-2/fork", %{
          new_slug: "BAD SLUG!",
          new_name: "Dest"
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects missing new_name", %{conn: conn} do
      {:ok, _} = Templates.create_template(%{slug: "src-3", name: "S", kind: "workspace"})

      conn =
        post(conn, ~p"/api/v1/templates/src-3/fork", %{new_slug: "dst-3"})

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  describe "GET /api/v1/templates/:slug/versions" do
    test "returns version history", %{conn: conn} do
      {:ok, t} =
        Templates.create_template(%{slug: "ver-tpl", name: "V", kind: "persona"})

      {:ok, _} = Templates.publish_template(t, version: "1.0.0")

      conn = get(conn, ~p"/api/v1/templates/ver-tpl/versions")
      assert %{"slug" => "ver-tpl", "count" => 1, "data" => [v]} = json_response(conn, 200)
      assert v["version"] == "1.0.0"
    end
  end

  describe "GET /api/v1/templates/instantiations" do
    test "returns audit log", %{conn: conn} do
      {:ok, _} = Templates.create_template(%{slug: "a-tpl", name: "A", kind: "workspace"})

      Templates.record_instantiation(%{
        template_slug: "a-tpl",
        template_version: "0.1.0",
        status: "success"
      })

      conn = get(conn, ~p"/api/v1/templates/instantiations")
      assert %{"data" => [inst]} = json_response(conn, 200)
      assert inst["template_slug"] == "a-tpl"
    end

    test "filters by template_slug", %{conn: conn} do
      {:ok, _} = Templates.create_template(%{slug: "a-1", name: "A", kind: "workspace"})
      {:ok, _} = Templates.create_template(%{slug: "a-2", name: "A", kind: "workspace"})

      Templates.record_instantiation(%{
        template_slug: "a-1",
        template_version: "0.1.0",
        status: "success"
      })

      Templates.record_instantiation(%{
        template_slug: "a-2",
        template_version: "0.1.0",
        status: "success"
      })

      conn = get(conn, ~p"/api/v1/templates/instantiations?template_slug=a-1")
      assert %{"data" => [inst]} = json_response(conn, 200)
      assert inst["template_slug"] == "a-1"
    end
  end
end
