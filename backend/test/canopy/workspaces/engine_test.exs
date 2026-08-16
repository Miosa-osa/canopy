defmodule Canopy.Workspaces.EngineTest do
  use Canopy.DataCase, async: false

  alias Canopy.Repo
  alias Canopy.Workspaces.Engine
  alias Canopy.Workspaces.Workspace

  defp tmp_dir do
    dir = Path.join(System.tmp_dir!(), "canopy-engine-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end

  defp insert_workspace(attrs \\ %{}) do
    root = Map.get(attrs, :root_path, tmp_dir())
    slug = Map.get(attrs, :slug, "engine-ws-#{System.unique_integer([:positive])}")

    {:ok, workspace} =
      Repo.insert(
        Workspace.changeset(%Workspace{}, %{
          slug: slug,
          name: "Engine Workspace",
          root_path: root
        })
      )

    workspace
  end

  defp write_engine!(workspace, manifest \\ default_manifest()) do
    File.mkdir_p!(Path.join(workspace.root_path, "engine"))
    File.mkdir_p!(Path.join(workspace.root_path, ".canopy"))

    File.write!(
      Path.join([workspace.root_path, "engine", "mix.exs"]),
      "defmodule Engine.MixProject do\nend\n"
    )

    File.write!(Path.join([workspace.root_path, ".canopy", "engine.yaml"]), manifest)
  end

  defp default_manifest do
    """
    commands:
      impact:
        task: optimal.impact
        description: Score strategic impact
        args:
          - --json
      build-plan:
        task: optimal.build_plan
    """
  end

  defp fake_mix! do
    path = Path.join(tmp_dir(), "fake-mix")

    File.write!(path, """
    #!/bin/sh
    printf 'cwd=%s\\n' "$PWD"
    printf 'args=%s\\n' "$*"
    """)

    File.chmod!(path, 0o755)

    previous = Application.get_env(:canopy, :engine_mix_executable)
    Application.put_env(:canopy, :engine_mix_executable, path)

    on_exit(fn ->
      if previous do
        Application.put_env(:canopy, :engine_mix_executable, previous)
      else
        Application.delete_env(:canopy, :engine_mix_executable)
      end
    end)

    path
  end

  describe "health/1" do
    test "reports missing engine pieces without failing" do
      workspace = insert_workspace()

      assert {:ok, health} = Engine.health(workspace.slug)
      assert health.workspace_slug == workspace.slug
      assert health.engine_exists == false
      assert health.mix_project == false
      assert health.manifest_exists == false
      assert health.commands_count == 0
      assert health.available == false
    end

    test "reports available only when engine, mix project, and manifest exist" do
      workspace = insert_workspace()
      write_engine!(workspace)

      assert {:ok, health} = Engine.health(workspace.slug)
      assert health.engine_exists == true
      assert health.mix_project == true
      assert health.manifest_exists == true
      assert health.commands_count == 2
      assert health.available == true
    end
  end

  describe "list_commands/1" do
    test "loads allowlisted commands from workspace manifest" do
      workspace = insert_workspace()
      write_engine!(workspace)

      assert {:ok, commands} = Engine.list_commands(workspace.slug)
      assert Enum.map(commands, & &1.name) == ["build-plan", "impact"]
      assert Enum.find(commands, &(&1.name == "impact")).args == ["--json"]
    end

    test "requires a workspace-local engine directory" do
      workspace = insert_workspace()

      assert {:error, :engine_not_found} = Engine.list_commands(workspace.slug)
    end

    test "requires a manifest" do
      workspace = insert_workspace()
      File.mkdir_p!(Path.join(workspace.root_path, "engine"))
      File.write!(Path.join([workspace.root_path, "engine", "mix.exs"]), "")

      assert {:error, :manifest_not_found} = Engine.list_commands(workspace.slug)
    end
  end

  describe "run/4" do
    test "runs an allowlisted mix task inside the workspace engine directory" do
      workspace = insert_workspace()
      write_engine!(workspace)
      fake_mix!()

      assert {:ok, result} = Engine.run(workspace.slug, "impact", ["--target", "growth"])

      assert result.workspace_slug == workspace.slug
      assert result.command == "impact"
      assert result.task == "optimal.impact"
      assert result.args == ["optimal.impact", "--json", "--target", "growth"]
      assert result.cwd == Path.join(workspace.root_path, "engine")
      assert result.stdout =~ "cwd="
      assert result.stdout =~ "args=optimal.impact --json --target growth"
      assert result.exit_code == 0
    end

    test "rejects commands not in the manifest" do
      workspace = insert_workspace()
      write_engine!(workspace)

      assert {:error, :command_not_allowed} = Engine.run(workspace.slug, "shell", [])
    end

    test "rejects malformed args and invalid timeouts" do
      workspace = insert_workspace()
      write_engine!(workspace)

      assert {:error, :invalid_arg} = Engine.run(workspace.slug, "impact", "--bad")
      assert {:error, :invalid_arg} = Engine.run(workspace.slug, "impact", ["bad" <> <<0>>])
      assert {:error, :invalid_timeout} = Engine.run(workspace.slug, "impact", [], timeout_ms: 0)

      assert {:error, :timeout_too_large} =
               Engine.run(workspace.slug, "impact", [], timeout_ms: 300_001)
    end
  end
end
