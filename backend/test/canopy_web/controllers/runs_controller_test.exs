defmodule CanopyWeb.RunsControllerTest do
  @moduledoc "Controller tests for the Runs API."

  use CanopyWeb.ConnCase, async: true

  import Canopy.Factory

  # ---------------------------------------------------------------------------
  # GET /api/v1/runs
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/runs" do
    test "200 returns run list", %{conn: conn} do
      ws = "ctrl-runs-ws-#{System.unique_integer()}"
      insert(:run, workspace_slug: ws)
      conn = get(conn, "/api/v1/runs", workspace_slug: ws)
      body = json_response(conn, 200)
      assert is_list(body["data"])
      assert is_integer(body["count"])
    end

    test "200 with empty list when no runs", %{conn: conn} do
      conn = get(conn, "/api/v1/runs", workspace_slug: "empty-runs-ws-#{System.unique_integer()}")
      body = json_response(conn, 200)
      assert body["data"] == []
      assert body["count"] == 0
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/runs
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/runs" do
    test "201 creates and returns run", %{conn: conn} do
      conn = post(conn, "/api/v1/runs", %{workspace_slug: "default"})
      body = json_response(conn, 201)
      assert String.starts_with?(body["data"]["short_id"], "R-")
      assert body["data"]["status"] == "queued"
    end

    test "201 with all optional fields", %{conn: conn} do
      conn =
        post(conn, "/api/v1/runs", %{
          workspace_slug: "ws",
          agent_slug: "backend-engineer",
          wake_reason: "manual"
        })

      body = json_response(conn, 201)
      assert body["data"]["agent_slug"] == "backend-engineer"
      assert body["data"]["wake_reason"] == "manual"
    end

    test "422 when workspace_slug missing", %{conn: conn} do
      conn = post(conn, "/api/v1/runs", %{})
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/runs/:id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/runs/:id" do
    test "200 returns run by uuid", %{conn: conn} do
      run = insert(:run)
      conn = get(conn, "/api/v1/runs/#{run.id}")
      body = json_response(conn, 200)
      assert body["data"]["id"] == run.id
    end

    test "200 returns run by short_id", %{conn: conn} do
      run = insert(:run)
      conn = get(conn, "/api/v1/runs/#{run.short_id}")
      body = json_response(conn, 200)
      assert body["data"]["short_id"] == run.short_id
    end

    test "404 for unknown id", %{conn: conn} do
      conn = get(conn, "/api/v1/runs/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/runs/:id
  # ---------------------------------------------------------------------------

  describe "PATCH /api/v1/runs/:id" do
    test "200 marks run running with process_pid", %{conn: conn} do
      run = insert(:run)
      conn = patch(conn, "/api/v1/runs/#{run.id}", %{status: "running", process_pid: 42_000})
      body = json_response(conn, 200)
      assert body["data"]["status"] == "running"
      assert body["data"]["process_pid"] == 42_000
    end

    test "200 marks run paused", %{conn: conn} do
      run = insert(:run, status: "running")
      conn = patch(conn, "/api/v1/runs/#{run.id}", %{status: "paused"})
      body = json_response(conn, 200)
      assert body["data"]["status"] == "paused"
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/runs/:id/finish
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/runs/:id/finish" do
    test "200 marks run succeeded with usage", %{conn: conn} do
      run = insert(:run, status: "running")

      conn =
        post(conn, "/api/v1/runs/#{run.id}/finish", %{
          status: "succeeded",
          usage_json: %{tokens_in: 1000, tokens_out: 500, cost_usd: "0.015"}
        })

      body = json_response(conn, 200)
      assert body["data"]["status"] == "succeeded"
      assert body["data"]["finished_at"] != nil
    end

    test "200 marks run failed with error", %{conn: conn} do
      run = insert(:run, status: "running")

      conn =
        post(conn, "/api/v1/runs/#{run.id}/finish", %{
          status: "failed",
          error: "context window exceeded"
        })

      body = json_response(conn, 200)
      assert body["data"]["status"] == "failed"
      assert body["data"]["error_reason"] == "context window exceeded"
    end

    test "422 for invalid finish status", %{conn: conn} do
      run = insert(:run)

      conn =
        post(conn, "/api/v1/runs/#{run.id}/finish", %{status: "running"})

      body = json_response(conn, 422)
      assert body["error"] == "invalid_status"
    end

    test "404 for unknown run", %{conn: conn} do
      conn =
        post(conn, "/api/v1/runs/#{Ecto.UUID.generate()}/finish", %{status: "succeeded"})

      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/runs/:id/log
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/runs/:id/log" do
    test "200 returns empty lines when log_ref is nil", %{conn: conn} do
      run = insert(:run)
      conn = get(conn, "/api/v1/runs/#{run.id}/log")
      body = json_response(conn, 200)
      assert body["lines"] == []
      assert body["offset"] == 0
    end

    test "200 returns lines from scrollback file", %{conn: conn} do
      # Write a temp log file
      tmp = System.tmp_dir!()
      log_path = Path.join(tmp, "test_run_#{System.unique_integer()}.log")

      lines = [
        Jason.encode!(%{seq: 0, at: "2026-04-20T00:00:00Z", kind: "stdout", data: "Starting..."}),
        Jason.encode!(%{seq: 1, at: "2026-04-20T00:00:01Z", kind: "stdout", data: "Done."})
      ]

      File.write!(log_path, Enum.join(lines, "\n"))

      run = insert(:run, log_ref: log_path)
      conn = get(conn, "/api/v1/runs/#{run.id}/log")
      body = json_response(conn, 200)
      assert length(body["lines"]) == 2
      assert Enum.at(body["lines"], 0)["data"] == "Starting..."

      File.rm(log_path)
    end

    test "200 with offset pagination", %{conn: conn} do
      tmp = System.tmp_dir!()
      log_path = Path.join(tmp, "test_run_offset_#{System.unique_integer()}.log")
      lines = for i <- 0..4, do: Jason.encode!(%{seq: i, kind: "stdout", data: "line #{i}"})
      File.write!(log_path, Enum.join(lines, "\n"))

      run = insert(:run, log_ref: log_path)
      conn = get(conn, "/api/v1/runs/#{run.id}/log", %{offset: "2", limit: "2"})
      body = json_response(conn, 200)
      assert length(body["lines"]) == 2
      assert Enum.at(body["lines"], 0)["data"] == "line 2"

      File.rm(log_path)
    end

    test "404 for unknown run", %{conn: conn} do
      conn = get(conn, "/api/v1/runs/#{Ecto.UUID.generate()}/log")
      assert json_response(conn, 404)
    end
  end
end
