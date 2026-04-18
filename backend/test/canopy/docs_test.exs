defmodule Canopy.DocsTest do
  @moduledoc """
  Integration tests for Canopy.Docs context:
  - Folder CRUD + tree building
  - Document CRUD + body_text derivation
  - Full-text search
  """

  use Canopy.DataCase, async: true

  alias Canopy.Docs
  alias Canopy.Docs.{Document, Folder}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp workspace_slug, do: "test-ws-#{System.unique_integer([:positive])}"

  defp folder_attrs(ws, overrides \\ %{}) do
    Map.merge(%{"name" => "My Folder", "workspace_slug" => ws}, overrides)
  end

  defp doc_attrs(ws, overrides \\ %{}) do
    Map.merge(
      %{
        "slug" => "doc-#{System.unique_integer([:positive])}",
        "workspace_slug" => ws,
        "title" => "Test Doc",
        "author_type" => "user",
        "author_id" => Ecto.UUID.generate(),
        "last_editor_type" => "user",
        "last_editor_id" => Ecto.UUID.generate(),
        "body_json" => %{
          "type" => "doc",
          "content" => [
            %{
              "type" => "paragraph",
              "content" => [%{"type" => "text", "text" => "Hello world"}]
            }
          ]
        }
      },
      overrides
    )
  end

  # ---------------------------------------------------------------------------
  # Folder CRUD
  # ---------------------------------------------------------------------------

  describe "create_folder/1" do
    test "creates a folder with required fields" do
      ws = workspace_slug()
      assert {:ok, %Folder{} = folder} = Docs.create_folder(folder_attrs(ws))
      assert folder.name == "My Folder"
      assert folder.workspace_slug == ws
      assert is_nil(folder.parent_id)
      assert is_nil(folder.archived_at)
    end

    test "creates a nested folder with parent_id" do
      ws = workspace_slug()
      {:ok, parent} = Docs.create_folder(folder_attrs(ws, %{"name" => "Parent"}))

      {:ok, child} =
        Docs.create_folder(folder_attrs(ws, %{"name" => "Child", "parent_id" => parent.id}))

      assert child.parent_id == parent.id
    end

    test "rejects folder without name" do
      assert {:error, changeset} =
               Docs.create_folder(%{"workspace_slug" => workspace_slug()})

      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "rejects folder without workspace_slug" do
      assert {:error, changeset} = Docs.create_folder(%{"name" => "Orphan"})
      assert %{workspace_slug: [_ | _]} = errors_on(changeset)
    end
  end

  describe "list_folders/1" do
    test "returns only non-archived folders for the workspace" do
      ws = workspace_slug()
      {:ok, f1} = Docs.create_folder(folder_attrs(ws, %{"name" => "A"}))
      {:ok, f2} = Docs.create_folder(folder_attrs(ws, %{"name" => "B"}))
      {:ok, archived} = Docs.create_folder(folder_attrs(ws, %{"name" => "C"}))
      Docs.archive_folder(archived.id)

      folders = Docs.list_folders(ws)
      ids = Enum.map(folders, & &1.id)
      assert f1.id in ids
      assert f2.id in ids
      refute archived.id in ids
    end

    test "does not return folders from other workspaces" do
      ws1 = workspace_slug()
      ws2 = workspace_slug()
      {:ok, f1} = Docs.create_folder(folder_attrs(ws1))
      {:ok, f2} = Docs.create_folder(folder_attrs(ws2))

      ws1_folders = Docs.list_folders(ws1)
      assert Enum.any?(ws1_folders, &(&1.id == f1.id))
      refute Enum.any?(ws1_folders, &(&1.id == f2.id))
    end
  end

  describe "get_folder_tree/1" do
    test "returns hierarchical tree with children" do
      ws = workspace_slug()
      {:ok, root} = Docs.create_folder(folder_attrs(ws, %{"name" => "Root"}))

      {:ok, _child} =
        Docs.create_folder(folder_attrs(ws, %{"name" => "Child", "parent_id" => root.id}))

      tree = Docs.get_folder_tree(ws)
      root_node = Enum.find(tree, &(&1.id == root.id))
      assert root_node != nil
      assert length(root_node.children) == 1
      assert hd(root_node.children).name == "Child"
    end

    test "excludes archived folders from tree" do
      ws = workspace_slug()
      {:ok, folder} = Docs.create_folder(folder_attrs(ws))
      {:ok, _} = Docs.archive_folder(folder.id)

      tree = Docs.get_folder_tree(ws)
      refute Enum.any?(tree, &(&1.id == folder.id))
    end
  end

  describe "archive_folder/1" do
    test "sets archived_at on the folder" do
      ws = workspace_slug()
      {:ok, folder} = Docs.create_folder(folder_attrs(ws))
      assert {:ok, archived} = Docs.archive_folder(folder.id)
      assert archived.archived_at != nil
    end

    test "returns not_found for unknown id" do
      assert {:error, :not_found} = Docs.archive_folder(Ecto.UUID.generate())
    end
  end

  # ---------------------------------------------------------------------------
  # Document CRUD
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "creates a document and derives body_text from body_json" do
      ws = workspace_slug()
      attrs = doc_attrs(ws)
      assert {:ok, %Document{} = doc} = Docs.create(attrs)
      assert doc.title == "Test Doc"
      assert doc.version == 1
      assert String.contains?(doc.body_text, "Hello world")
      assert doc.published == false
    end

    test "creates an unfiled document (no folder_id)" do
      ws = workspace_slug()
      {:ok, doc} = Docs.create(doc_attrs(ws))
      assert is_nil(doc.folder_id)
    end

    test "creates a document in a folder" do
      ws = workspace_slug()
      {:ok, folder} = Docs.create_folder(folder_attrs(ws))
      {:ok, doc} = Docs.create(doc_attrs(ws, %{"folder_id" => folder.id}))
      assert doc.folder_id == folder.id
    end

    test "rejects duplicate slug within workspace" do
      ws = workspace_slug()
      attrs = doc_attrs(ws, %{"slug" => "fixed-slug"})
      {:ok, _} = Docs.create(attrs)
      assert {:error, changeset} = Docs.create(attrs)
      assert %{slug: [_ | _]} = errors_on(changeset)
    end

    test "allows same slug in different workspaces" do
      slug = "same-slug"
      {:ok, _} = Docs.create(doc_attrs(workspace_slug(), %{"slug" => slug}))
      {:ok, doc2} = Docs.create(doc_attrs(workspace_slug(), %{"slug" => slug}))
      assert doc2.slug == slug
    end

    test "rejects document without required fields" do
      assert {:error, changeset} = Docs.create(%{})
      errors = errors_on(changeset)
      assert Map.has_key?(errors, :slug) or Map.has_key?(errors, :title)
    end
  end

  describe "get/1" do
    test "gets a document by id" do
      ws = workspace_slug()
      {:ok, doc} = Docs.create(doc_attrs(ws))
      assert {:ok, fetched} = Docs.get(doc.id)
      assert fetched.id == doc.id
    end

    test "gets a document by {slug, workspace_slug}" do
      ws = workspace_slug()
      {:ok, doc} = Docs.create(doc_attrs(ws, %{"slug" => "my-doc"}))
      assert {:ok, fetched} = Docs.get({"my-doc", ws})
      assert fetched.id == doc.id
    end

    test "returns not_found for unknown id" do
      assert {:error, :not_found} = Docs.get(Ecto.UUID.generate())
    end

    test "returns not_found for unknown slug+workspace" do
      assert {:error, :not_found} = Docs.get({"nope", "no-ws"})
    end
  end

  # ---------------------------------------------------------------------------
  # Update (last-writer-wins)
  # ---------------------------------------------------------------------------

  describe "update/2" do
    test "updates document title and increments version" do
      ws = workspace_slug()
      {:ok, doc} = Docs.create(doc_attrs(ws))
      assert doc.version == 1

      {:ok, updated} =
        Docs.update(doc, %{
          "title" => "Updated Title",
          "last_editor_type" => "user",
          "last_editor_id" => Ecto.UUID.generate()
        })

      assert updated.version == 2
      assert updated.title == "Updated Title"
    end

    test "re-derives body_text from updated body_json" do
      ws = workspace_slug()
      {:ok, doc} = Docs.create(doc_attrs(ws))

      new_body = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "paragraph",
            "content" => [%{"type" => "text", "text" => "Updated content"}]
          }
        ]
      }

      {:ok, updated} =
        Docs.update(doc, %{
          "body_json" => new_body,
          "last_editor_type" => "user",
          "last_editor_id" => Ecto.UUID.generate()
        })

      assert String.contains?(updated.body_text, "Updated content")
    end
  end

  # ---------------------------------------------------------------------------
  # Publish / unpublish
  # ---------------------------------------------------------------------------

  describe "publish/1 and unpublish/1" do
    test "publish sets published and published_at" do
      ws = workspace_slug()
      {:ok, doc} = Docs.create(doc_attrs(ws))
      assert doc.published == false

      {:ok, published} = Docs.publish(doc.id)
      assert published.published == true
      assert published.published_at != nil
    end

    test "unpublish clears published and published_at" do
      ws = workspace_slug()
      {:ok, doc} = Docs.create(doc_attrs(ws))
      {:ok, published} = Docs.publish(doc.id)
      assert published.published == true

      {:ok, unpublished} = Docs.unpublish(doc.id)
      assert unpublished.published == false
      assert is_nil(unpublished.published_at)
    end

    test "publish returns not_found for unknown id" do
      assert {:error, :not_found} = Docs.publish(Ecto.UUID.generate())
    end
  end

  # ---------------------------------------------------------------------------
  # Archive / unarchive
  # ---------------------------------------------------------------------------

  describe "archive/1 and unarchive/1" do
    test "archive sets archived_at" do
      ws = workspace_slug()
      {:ok, doc} = Docs.create(doc_attrs(ws))
      {:ok, archived} = Docs.archive(doc.id)
      assert archived.archived_at != nil
    end

    test "unarchive clears archived_at" do
      ws = workspace_slug()
      {:ok, doc} = Docs.create(doc_attrs(ws))
      {:ok, archived} = Docs.archive(doc.id)
      {:ok, unarchived} = Docs.unarchive(archived.id)
      assert is_nil(unarchived.archived_at)
    end

    test "archived docs excluded from list_documents by default" do
      ws = workspace_slug()
      {:ok, doc} = Docs.create(doc_attrs(ws))
      {:ok, _} = Docs.archive(doc.id)

      docs = Docs.list_documents(%{"workspace_slug" => ws})
      refute Enum.any?(docs, &(&1.id == doc.id))
    end

    test "archived docs included when archived: true filter applied" do
      ws = workspace_slug()
      {:ok, doc} = Docs.create(doc_attrs(ws))
      {:ok, _} = Docs.archive(doc.id)

      docs = Docs.list_documents(%{"workspace_slug" => ws, "archived" => true})
      assert Enum.any?(docs, &(&1.id == doc.id))
    end
  end

  # ---------------------------------------------------------------------------
  # Full-text search
  # ---------------------------------------------------------------------------

  describe "search/2" do
    test "returns documents matching full-text query" do
      ws = workspace_slug()

      body = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "paragraph",
            "content" => [%{"type" => "text", "text" => "Elixir functional programming"}]
          }
        ]
      }

      {:ok, doc} = Docs.create(doc_attrs(ws, %{"body_json" => body}))

      results = Docs.search(ws, "Elixir")
      assert Enum.any?(results, &(&1.id == doc.id))
    end

    test "does not return archived documents in search" do
      ws = workspace_slug()

      body = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "paragraph",
            "content" => [%{"type" => "text", "text" => "Phoenix framework search test"}]
          }
        ]
      }

      {:ok, doc} = Docs.create(doc_attrs(ws, %{"body_json" => body}))
      {:ok, _} = Docs.archive(doc.id)

      results = Docs.search(ws, "Phoenix")
      refute Enum.any?(results, &(&1.id == doc.id))
    end

    test "returns empty list for blank query" do
      ws = workspace_slug()
      {:ok, _} = Docs.create(doc_attrs(ws))
      assert Docs.search(ws, "") == []
    end

    test "does not return results from other workspaces" do
      ws1 = workspace_slug()
      ws2 = workspace_slug()

      body = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "paragraph",
            "content" => [%{"type" => "text", "text" => "uniqueterm12345"}]
          }
        ]
      }

      {:ok, _} = Docs.create(doc_attrs(ws1, %{"body_json" => body}))

      results = Docs.search(ws2, "uniqueterm12345")
      assert results == []
    end
  end

  # ---------------------------------------------------------------------------
  # Delete
  # ---------------------------------------------------------------------------

  describe "delete/1" do
    test "hard-deletes a document" do
      ws = workspace_slug()
      {:ok, doc} = Docs.create(doc_attrs(ws))
      {:ok, _} = Docs.delete(doc.id)
      assert {:error, :not_found} = Docs.get(doc.id)
    end

    test "returns not_found for unknown id" do
      assert {:error, :not_found} = Docs.delete(Ecto.UUID.generate())
    end
  end
end
