defmodule Canopy.WorkspacesTest do
  @moduledoc """
  Integration tests for the Canopy.Workspaces context module.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Workspaces
  alias Canopy.Workspaces.Workspace

  defp valid_workspace_attrs(overrides \\ %{}) do
    tmp_dir =
      System.tmp_dir!()
      |> Path.join("canopy-ws-test-#{System.unique_integer([:positive])}")

    Map.merge(
      %{
        slug: "ws-#{System.unique_integer([:positive])}",
        name: "My Workspace",
        root_path: tmp_dir
      },
      overrides
    )
  end

  # ---------------------------------------------------------------------------
  # list/0
  # ---------------------------------------------------------------------------

  describe "list/0" do
    test "returns empty list when no workspaces exist" do
      assert {:ok, []} = Workspaces.list()
    end

    test "returns all workspaces" do
      {:ok, _inserted} =
        Canopy.Repo.insert(Workspace.changeset(%Workspace{}, valid_workspace_attrs()))

      assert {:ok, workspaces} = Workspaces.list()
      assert workspaces != []
    end

    test "does not return soft-deleted workspaces" do
      attrs = valid_workspace_attrs(%{slug: "to-delete"})
      {:ok, _ws} = Canopy.Repo.insert(Workspace.changeset(%Workspace{}, attrs))
      {:ok, _deleted} = Workspaces.delete("to-delete")

      {:ok, all} = Workspaces.list()
      slugs = Enum.map(all, & &1.slug)
      refute "to-delete" in slugs
    end
  end

  # ---------------------------------------------------------------------------
  # get_by_slug/1
  # ---------------------------------------------------------------------------

  describe "get_by_slug/1" do
    test "returns workspace when found" do
      {:ok, inserted} =
        Canopy.Repo.insert(
          Workspace.changeset(%Workspace{}, valid_workspace_attrs(%{slug: "found-ws"}))
        )

      assert {:ok, ws} = Workspaces.get_by_slug("found-ws")
      assert ws.id == inserted.id
    end

    test "returns error when not found" do
      assert {:error, :not_found} = Workspaces.get_by_slug("no-such-slug")
    end

    test "returns error for soft-deleted workspace" do
      attrs = valid_workspace_attrs(%{slug: "soft-deleted-ws"})
      {:ok, _ws} = Canopy.Repo.insert(Workspace.changeset(%Workspace{}, attrs))
      {:ok, _deleted} = Workspaces.delete("soft-deleted-ws")

      assert {:error, :not_found} = Workspaces.get_by_slug("soft-deleted-ws")
    end
  end

  # ---------------------------------------------------------------------------
  # create/1
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "creates a workspace with valid attrs and writes SYSTEM.md" do
      tmp_dir =
        System.tmp_dir!()
        |> Path.join("canopy-create-test-#{System.unique_integer([:positive])}")

      on_exit(fn -> File.rm_rf(tmp_dir) end)

      assert {:ok, ws} =
               Workspaces.create(%{
                 slug: "created-ws",
                 name: "Created Workspace",
                 root_path: tmp_dir
               })

      assert ws.id != nil
      assert ws.slug == "created-ws"
      assert File.exists?(Path.join(tmp_dir, "SYSTEM.md"))
    end

    test "returns changeset error on invalid attrs" do
      assert {:error, cs} = Workspaces.create(%{})
      assert %{slug: ["can't be blank"]} = errors_on(cs)
    end

    test "rejects duplicate slug" do
      attrs = valid_workspace_attrs(%{slug: "dup-slug"})
      {:ok, _first} = Workspaces.create(attrs)
      {:error, cs} = Workspaces.create(attrs)
      assert %{slug: ["has already been taken"]} = errors_on(cs)
    end

    test "does not overwrite existing SYSTEM.md" do
      tmp_dir =
        System.tmp_dir!()
        |> Path.join("canopy-existing-test-#{System.unique_integer([:positive])}")

      File.mkdir_p!(tmp_dir)
      existing_content = "# Existing SYSTEM.md\n"
      File.write!(Path.join(tmp_dir, "SYSTEM.md"), existing_content)

      on_exit(fn -> File.rm_rf(tmp_dir) end)

      {:ok, _ws} =
        Workspaces.create(%{
          slug: "existing-system-ws",
          name: "Existing SYSTEM Workspace",
          root_path: tmp_dir
        })

      assert File.read!(Path.join(tmp_dir, "SYSTEM.md")) == existing_content
    end
  end

  # ---------------------------------------------------------------------------
  # delete/1
  # ---------------------------------------------------------------------------

  describe "delete/1" do
    test "soft-deletes a workspace by setting deleted_at" do
      attrs = valid_workspace_attrs(%{slug: "deletable-ws"})
      {:ok, _ws} = Canopy.Repo.insert(Workspace.changeset(%Workspace{}, attrs))

      assert {:ok, deleted} = Workspaces.delete("deletable-ws")
      assert deleted.deleted_at != nil
    end

    test "does not destroy the DB row — record still exists with deleted_at set" do
      attrs = valid_workspace_attrs(%{slug: "still-exists-ws"})
      {:ok, inserted} = Canopy.Repo.insert(Workspace.changeset(%Workspace{}, attrs))

      {:ok, _deleted} = Workspaces.delete("still-exists-ws")

      raw = Canopy.Repo.get(Workspace, inserted.id)
      assert raw != nil
      assert raw.deleted_at != nil
    end

    test "returns :not_found for nonexistent slug" do
      assert {:error, :not_found} = Workspaces.delete("no-such-slug")
    end
  end

  # ---------------------------------------------------------------------------
  # list_templates/0
  # ---------------------------------------------------------------------------

  describe "list_templates/0" do
    test "returns 4 templates" do
      templates = Workspaces.list_templates()
      assert length(templates) == 4
    end

    test "template slugs are the expected 4" do
      templates = Workspaces.list_templates()
      slugs = Enum.map(templates, & &1.slug)
      assert "sales-engine" in slugs
      assert "dev-shop" in slugs
      assert "content-factory" in slugs
      assert "blank" in slugs
    end

    test "each template has slug, name, description, files" do
      for tpl <- Workspaces.list_templates() do
        assert is_binary(tpl.slug)
        assert is_binary(tpl.name)
        assert is_binary(tpl.description)
        assert is_list(tpl.files)
      end
    end

    test "blank template has SYSTEM.md and company.yaml" do
      templates = Workspaces.list_templates()
      blank = Enum.find(templates, &(&1.slug == "blank"))
      assert "SYSTEM.md" in blank.files
      assert "company.yaml" in blank.files
    end
  end

  # ---------------------------------------------------------------------------
  # create_from_template/3
  # ---------------------------------------------------------------------------

  describe "create_from_template/3" do
    test "creates a workspace from the blank template" do
      tmp_dir =
        System.tmp_dir!()
        |> Path.join("canopy-tpl-test-#{System.unique_integer([:positive])}")

      on_exit(fn -> File.rm_rf(tmp_dir) end)

      assert {:ok, ws} = Workspaces.create_from_template("tpl-ws", "blank", tmp_dir)
      assert ws.slug == "tpl-ws"
      assert ws.template == "blank"
      assert File.exists?(Path.join(tmp_dir, "SYSTEM.md"))
      assert File.exists?(Path.join(tmp_dir, "company.yaml"))
    end

    test "materialises sales-engine template structure" do
      tmp_dir =
        System.tmp_dir!()
        |> Path.join("canopy-sales-tpl-#{System.unique_integer([:positive])}")

      on_exit(fn -> File.rm_rf(tmp_dir) end)

      assert {:ok, _ws} = Workspaces.create_from_template("sales-ws", "sales-engine", tmp_dir)
      assert File.exists?(Path.join(tmp_dir, "SYSTEM.md"))
      assert File.exists?(Path.join(tmp_dir, "company.yaml"))
      assert File.dir?(Path.join(tmp_dir, "agents"))
      assert File.dir?(Path.join(tmp_dir, "skills"))
      assert File.dir?(Path.join(tmp_dir, "reference"))
    end

    test "returns :unknown_template for nonexistent template slug" do
      assert {:error, :unknown_template} =
               Workspaces.create_from_template("ws", "nonexistent", "/tmp/x")
    end
  end
end
