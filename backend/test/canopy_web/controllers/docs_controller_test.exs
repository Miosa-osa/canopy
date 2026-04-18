defmodule CanopyWeb.DocsControllerTest do
  @moduledoc """
  Controller tests for DocsController endpoints:
    GET    /api/v1/docs
    POST   /api/v1/docs
    GET    /api/v1/docs/search
    GET    /api/v1/docs/:id
    PUT    /api/v1/docs/:id
    POST   /api/v1/docs/:id/publish
    POST   /api/v1/docs/:id/unpublish
    POST   /api/v1/docs/:id/archive
    POST   /api/v1/docs/:id/unarchive
    DELETE /api/v1/docs/:id
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.Docs

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp ws, do: "test-ws-#{System.unique_integer([:positive])}"

  defp create_doc!(workspace_slug, overrides \\ %{}) do
    {:ok, doc} =
      Docs.create(
        Map.merge(
          %{
            "slug" => "doc-#{System.unique_integer([:positive])}",
            "workspace_slug" => workspace_slug,
            "title" => "Test Document",
            "author_type" => "user",
            "author_id" => Ecto.UUID.generate(),
            "last_editor_type" => "user",
            "last_editor_id" => Ecto.UUID.generate(),
            "body_json" => %{
              "type" => "doc",
              "content" => [
                %{
                  "type" => "paragraph",
                  "content" => [%{"type" => "text", "text" => "Hello from test"}]
                }
              ]
            }
          },
          overrides
        )
      )

    doc
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/docs
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/docs" do
    test "returns 200 with empty list when no documents", %{conn: conn} do
      conn = get(conn, "/api/v1/docs", workspace_slug: ws())
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns documents for workspace", %{conn: conn} do
      workspace = ws()
      doc = create_doc!(workspace)
      conn = get(conn, "/api/v1/docs", workspace_slug: workspace)
      %{"data" => data} = json_response(conn, 200)
      assert Enum.any?(data, &(&1["id"] == doc.id))
    end

    test "filters by folder_id", %{conn: conn} do
      workspace = ws()
      {:ok, folder} = Docs.create_folder(%{"name" => "F", "workspace_slug" => workspace})
      in_folder = create_doc!(workspace, %{"folder_id" => folder.id})
      _not_in_folder = create_doc!(workspace)

      conn = get(conn, "/api/v1/docs", workspace_slug: workspace, folder_id: folder.id)
      %{"data" => data} = json_response(conn, 200)
      assert length(data) == 1
      assert hd(data)["id"] == in_folder.id
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/docs
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/docs" do
    test "creates a document and returns 201", %{conn: conn} do
      workspace = ws()

      conn =
        post(conn, "/api/v1/docs", %{
          "slug" => "new-doc",
          "workspace_slug" => workspace,
          "title" => "New Document",
          "author_type" => "user",
          "author_id" => Ecto.UUID.generate(),
          "last_editor_type" => "user",
          "last_editor_id" => Ecto.UUID.generate()
        })

      assert %{"data" => %{"id" => _, "version" => 1}} = json_response(conn, 201)
    end

    test "returns 422 for missing required fields", %{conn: conn} do
      conn = post(conn, "/api/v1/docs", %{"title" => "Missing slug"})
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/docs/search
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/docs/search" do
    test "returns matching documents", %{conn: conn} do
      workspace = ws()

      doc =
        create_doc!(workspace, %{
          "body_json" => %{
            "type" => "doc",
            "content" => [
              %{
                "type" => "paragraph",
                "content" => [%{"type" => "text", "text" => "searchableterm9999"}]
              }
            ]
          }
        })

      conn = get(conn, "/api/v1/docs/search", q: "searchableterm9999", workspace_slug: workspace)
      %{"data" => data} = json_response(conn, 200)
      assert Enum.any?(data, &(&1["id"] == doc.id))
    end

    test "returns 400 when q or workspace_slug missing", %{conn: conn} do
      conn = get(conn, "/api/v1/docs/search", q: "something")
      assert json_response(conn, 400)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/docs/:id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/docs/:id" do
    test "returns 200 with document", %{conn: conn} do
      doc = create_doc!(ws())
      conn = get(conn, "/api/v1/docs/#{doc.id}")
      assert %{"data" => %{"id" => id}} = json_response(conn, 200)
      assert id == doc.id
    end

    test "returns 404 for unknown id", %{conn: conn} do
      conn = get(conn, "/api/v1/docs/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/v1/docs/:id
  # ---------------------------------------------------------------------------

  describe "PUT /api/v1/docs/:id" do
    test "updates document and bumps version", %{conn: conn} do
      doc = create_doc!(ws())

      conn =
        put(conn, "/api/v1/docs/#{doc.id}", %{
          "title" => "Updated Title",
          "expected_version" => 1,
          "last_editor_type" => "user",
          "last_editor_id" => Ecto.UUID.generate()
        })

      assert %{"data" => %{"version" => 2, "title" => "Updated Title"}} = json_response(conn, 200)
    end

    test "returns 404 for unknown document", %{conn: conn} do
      conn =
        put(conn, "/api/v1/docs/#{Ecto.UUID.generate()}", %{
          "expected_version" => 1,
          "last_editor_type" => "user",
          "last_editor_id" => Ecto.UUID.generate()
        })

      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/docs/:id/publish
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/docs/:id/publish" do
    test "publishes document", %{conn: conn} do
      doc = create_doc!(ws())
      conn = post(conn, "/api/v1/docs/#{doc.id}/publish")
      assert %{"data" => %{"published" => true}} = json_response(conn, 200)
    end

    test "returns 404 for unknown document", %{conn: conn} do
      conn = post(conn, "/api/v1/docs/#{Ecto.UUID.generate()}/publish")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/docs/:id/unpublish
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/docs/:id/unpublish" do
    test "unpublishes document", %{conn: conn} do
      doc = create_doc!(ws())
      {:ok, published} = Docs.publish(doc.id)
      assert published.published == true

      conn = post(conn, "/api/v1/docs/#{doc.id}/unpublish")
      assert %{"data" => %{"published" => false}} = json_response(conn, 200)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/docs/:id/archive and /unarchive
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/docs/:id/archive" do
    test "archives document", %{conn: conn} do
      doc = create_doc!(ws())
      conn = post(conn, "/api/v1/docs/#{doc.id}/archive")
      assert %{"data" => %{"archived_at" => archived_at}} = json_response(conn, 200)
      assert archived_at != nil
    end
  end

  describe "POST /api/v1/docs/:id/unarchive" do
    test "unarchives document", %{conn: conn} do
      doc = create_doc!(ws())
      {:ok, _} = Docs.archive(doc.id)
      conn = post(conn, "/api/v1/docs/#{doc.id}/unarchive")
      assert %{"data" => %{"archived_at" => nil}} = json_response(conn, 200)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/docs/:id
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/docs/:id" do
    test "deletes document and returns 204", %{conn: conn} do
      doc = create_doc!(ws())
      conn = delete(conn, "/api/v1/docs/#{doc.id}")
      assert response(conn, 204)
    end

    test "returns 404 for unknown document", %{conn: conn} do
      conn = delete(conn, "/api/v1/docs/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end
end
