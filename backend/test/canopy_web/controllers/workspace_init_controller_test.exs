defmodule CanopyWeb.WorkspaceInitControllerTest do
  @moduledoc """
  Controller-level tests for workspace init endpoints.
  """

  use CanopyWeb.ConnCase, async: false

  alias Canopy.Repo
  alias Canopy.Workspaces.Init
  alias Canopy.Workspaces.Workspace

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp tmp_dir do
    dir =
      System.tmp_dir!()
      |> Path.join("canopy-init-ctrl-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    dir
  end

  defp insert_workspace(overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          slug: "ctrl-ws-#{System.unique_integer([:positive])}",
          name: "Controller Test Workspace",
          root_path: tmp_dir()
        },
        overrides
      )

    {:ok, ws} = Repo.insert(Workspace.changeset(%Workspace{}, attrs))
    ws
  end

  defp wait_for_terminal(job_id, timeout_ms \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    Stream.repeatedly(fn ->
      Process.sleep(50)

      case Init.get(job_id) do
        {:ok, %{status: s} = job} when s in ["succeeded", "failed", "cancelled"] ->
          {:done, job}

        _ ->
          if System.monotonic_time(:millisecond) > deadline do
            raise "Timeout waiting for job #{job_id}"
          end

          :waiting
      end
    end)
    |> Enum.find_value(fn
      {:done, job} -> job
      :waiting -> nil
    end)
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/workspaces/:slug/init
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/workspaces/:slug/init" do
    test "returns 201 with job_id for existing workspace", %{conn: conn} do
      ws = insert_workspace()
      conn = post(conn, "/api/v1/workspaces/#{ws.slug}/init", %{})
      assert %{"job_id" => job_id, "stream_url" => _} = json_response(conn, 201)
      assert is_binary(job_id)
    end

    test "returns 404 for unknown workspace", %{conn: conn} do
      conn = post(conn, "/api/v1/workspaces/nonexistent-xyzzy/init", %{})
      assert %{"error" => "not_found"} = json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:slug/init/:job_id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/workspaces/:slug/init/:job_id" do
    test "returns 200 with job data", %{conn: conn} do
      ws = insert_workspace()
      {:ok, job} = Init.start(ws.slug)

      conn = get(conn, "/api/v1/workspaces/#{ws.slug}/init/#{job.id}")
      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == job.id
    end

    test "returns 404 for unknown job", %{conn: conn} do
      ws = insert_workspace()
      conn = get(conn, "/api/v1/workspaces/#{ws.slug}/init/#{Ecto.UUID.generate()}")
      assert %{"error" => "not_found"} = json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/workspaces/:slug/init/:job_id/cancel
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/workspaces/:slug/init/:job_id/cancel" do
    test "cancels a running job", %{conn: conn} do
      ws = insert_workspace(%{setup_script: "sleep 30"})
      {:ok, job} = Init.start(ws.slug)
      Process.sleep(100)

      conn = post(conn, "/api/v1/workspaces/#{ws.slug}/init/#{job.id}/cancel", %{})
      assert %{"data" => data} = json_response(conn, 200)
      assert data["status"] == "cancelled"
    end

    test "returns 422 for already-terminal job", %{conn: conn} do
      ws = insert_workspace()
      {:ok, job} = Init.start(ws.slug)
      wait_for_terminal(job.id)

      conn = post(conn, "/api/v1/workspaces/#{ws.slug}/init/#{job.id}/cancel", %{})
      assert %{"error" => "already_terminal"} = json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/workspaces/:slug/setup (ad-hoc)
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/workspaces/:slug/setup" do
    test "returns 201 with job_id when setup_script is configured", %{conn: conn} do
      ws = insert_workspace(%{setup_script: "echo hi"})
      conn = post(conn, "/api/v1/workspaces/#{ws.slug}/setup", %{})
      assert %{"job_id" => job_id} = json_response(conn, 201)
      assert is_binary(job_id)
    end

    test "returns 422 when workspace has no setup_script", %{conn: conn} do
      ws = insert_workspace()
      conn = post(conn, "/api/v1/workspaces/#{ws.slug}/setup", %{})
      assert %{"error" => "no_setup_script"} = json_response(conn, 422)
    end

    test "returns 404 for unknown workspace", %{conn: conn} do
      conn = post(conn, "/api/v1/workspaces/nonexistent-xyzzy/setup", %{})
      assert json_response(conn, 404)
    end
  end
end
