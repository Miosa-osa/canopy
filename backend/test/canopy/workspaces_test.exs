defmodule Canopy.WorkspacesTest do
  @moduledoc """
  Integration tests for the Canopy.Workspaces context module.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Workspaces
  alias Canopy.Workspaces.Workspace

  defp valid_workspace_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        slug: "ws-#{System.unique_integer([:positive])}",
        name: "My Workspace",
        root_path: "/home/user/projects/my-workspace"
      },
      overrides
    )
  end

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
  end

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
  end

  describe "create/1" do
    test "creates a workspace with valid attrs" do
      assert {:ok, ws} =
               Workspaces.create(%{
                 slug: "created-ws",
                 name: "Created Workspace",
                 root_path: "/tmp/created"
               })

      assert ws.id != nil
      assert ws.slug == "created-ws"
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
  end
end
