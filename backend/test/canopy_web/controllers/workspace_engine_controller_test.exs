defmodule CanopyWeb.WorkspaceEngineControllerTest do
  use CanopyWeb.ConnCase, async: false

  alias Canopy.Repo
  alias Canopy.Workspaces.Workspace

  defp tmp_dir do
    dir =
      Path.join(
        System.tmp_dir!(),
        "canopy-engine-controller-test-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end

  defp insert_workspace do
    root = tmp_dir()
    slug = "engine-api-ws-#{System.unique_integer([:positive])}"

    {:ok, workspace} =
      Repo.insert(
        Workspace.changeset(%Workspace{}, %{
          slug: slug,
          name: "Engine API Workspace",
          root_path: root
        })
      )

    workspace
  end

  defp write_engine!(workspace) do
    File.mkdir_p!(Path.join(workspace.root_path, "engine"))
    File.mkdir_p!(Path.join(workspace.root_path, ".canopy"))
    File.write!(Path.join([workspace.root_path, "engine", "mix.exs"]), "")

    File.write!(Path.join([workspace.root_path, ".canopy", "engine.yaml"]), """
    commands:
      impact:
        task: optimal.impact
        args:
          - --json
    """)

    Canopy.EngineFixture.pin!(workspace.root_path)
  end

  defp fake_mix! do
    path = Path.join(tmp_dir(), "fake-mix")

    File.write!(path, """
    #!/bin/sh
    printf 'api args=%s\\n' "$*"
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
  end

  test "GET /workspaces/:slug/engine/health returns engine health", %{conn: conn} do
    workspace = insert_workspace()

    conn = get(conn, "/api/v1/workspaces/#{workspace.slug}/engine/health")

    assert %{"data" => data} = json_response(conn, 200)
    assert data["workspace_slug"] == workspace.slug
    assert data["available"] == false
  end

  test "GET /workspaces/:slug/engine/commands lists manifest commands", %{conn: conn} do
    workspace = insert_workspace()
    write_engine!(workspace)

    conn = get(conn, "/api/v1/workspaces/#{workspace.slug}/engine/commands")

    assert %{"data" => %{"commands" => [command], "count" => 1}} = json_response(conn, 200)
    assert command["name"] == "impact"
    assert command["task"] == "optimal.impact"
  end

  test "GET commands returns 404 when the workspace has no engine", %{conn: conn} do
    workspace = insert_workspace()

    conn = get(conn, "/api/v1/workspaces/#{workspace.slug}/engine/commands")

    assert %{"error" => "engine_not_found"} = json_response(conn, 404)
  end

  test "POST /workspaces/:slug/engine/run runs allowlisted command", %{conn: conn} do
    workspace = insert_workspace()
    write_engine!(workspace)
    fake_mix!()

    conn =
      post(conn, "/api/v1/workspaces/#{workspace.slug}/engine/run", %{
        "command" => "impact",
        "args" => ["--target", "growth"]
      })

    assert %{"data" => data} = json_response(conn, 200)
    assert data["command"] == "impact"
    assert data["args"] == ["optimal.impact", "--json", "--target", "growth"]
    assert data["stdout"] =~ "api args=optimal.impact --json --target growth"
  end

  test "POST run rejects missing command", %{conn: conn} do
    workspace = insert_workspace()

    conn = post(conn, "/api/v1/workspaces/#{workspace.slug}/engine/run", %{})

    assert %{"error" => "bad_request"} = json_response(conn, 400)
  end

  test "POST run rejects unknown command", %{conn: conn} do
    workspace = insert_workspace()
    write_engine!(workspace)

    conn =
      post(conn, "/api/v1/workspaces/#{workspace.slug}/engine/run", %{
        "command" => "unknown"
      })

    assert %{"error" => "command_not_allowed"} = json_response(conn, 422)
  end

  test "POST refuses an unpinned checkout before executing a task", %{conn: conn} do
    workspace = insert_workspace()
    write_engine!(workspace)
    fake_mix!()

    Canopy.EngineFixture.git!(
      Path.join(workspace.root_path, "engine"),
      ["remote", "set-url", "origin", "https://github.com/attacker/OptimalEngine.git"]
    )

    conn = post(conn, "/api/v1/workspaces/#{workspace.slug}/engine/run", %{"command" => "impact"})
    assert %{"error" => "engine_incompatible"} = json_response(conn, 422)
  end
end
