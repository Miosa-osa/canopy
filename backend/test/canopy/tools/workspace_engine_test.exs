defmodule Canopy.Tools.WorkspaceEngineTest do
  use Canopy.DataCase, async: false

  alias Canopy.Repo
  alias Canopy.Tools.WorkspaceEngine
  alias Canopy.Workspaces.Workspace

  defp tmp_dir do
    dir =
      Path.join(
        System.tmp_dir!(),
        "canopy-engine-tool-test-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end

  defp workspace do
    root = tmp_dir()

    {:ok, workspace} =
      Repo.insert(
        Workspace.changeset(%Workspace{}, %{
          slug: "engine-tool-ws-#{System.unique_integer([:positive])}",
          name: "Engine Tool Workspace",
          root_path: root
        })
      )

    File.mkdir_p!(Path.join(root, "engine"))
    File.mkdir_p!(Path.join(root, ".canopy"))
    File.write!(Path.join([root, "engine", "mix.exs"]), "")

    File.write!(Path.join([root, ".canopy", "engine.yaml"]), """
    commands:
      impact:
        task: optimal.impact
    """)

    Canopy.EngineFixture.pin!(root)
    workspace
  end

  describe "__canopy_tools__/0" do
    test "declares workspace engine tool surface" do
      names = WorkspaceEngine.__canopy_tools__() |> Enum.map(& &1.name)

      assert "workspace.engine_health" in names
      assert "workspace.engine_commands" in names
      assert "workspace.engine_run" in names
    end
  end

  describe "handlers" do
    test "health returns workspace-scoped engine status" do
      workspace = workspace()

      assert {:ok, health} = WorkspaceEngine.health(%{"workspace_slug" => workspace.slug})
      assert health.workspace_slug == workspace.slug
      assert health.available == true
    end

    test "commands returns command list and count" do
      workspace = workspace()

      assert {:ok, %{commands: commands, count: 1}} =
               WorkspaceEngine.commands(%{"workspace_slug" => workspace.slug})

      assert [%{name: "impact", task: "optimal.impact"}] = commands
    end

    test "run returns engine errors without masking them" do
      workspace = workspace()

      assert {:error, :command_not_allowed} =
               WorkspaceEngine.run(%{"workspace_slug" => workspace.slug, "command" => "unknown"})
    end
  end
end
