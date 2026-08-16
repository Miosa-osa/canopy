defmodule CanopyWeb.Plugs.RunIdAuditTest do
  @moduledoc "Tests for the RunIdAudit plug — stamping and enforcement behavior."

  use CanopyWeb.ConnCase, async: true

  import Canopy.Factory

  alias CanopyWeb.Plugs.RunIdAudit

  # ---------------------------------------------------------------------------
  # GET requests — always passthrough
  # ---------------------------------------------------------------------------

  describe "GET requests" do
    test "GET without X-Run-Id passes through without DB hit", %{conn: conn} do
      conn = %{conn | method: "GET", path_info: ["api", "v1", "tasks"]}
      result = RunIdAudit.call(conn, [])
      assert result.status == nil
      refute Map.has_key?(result.assigns, :run_id)
    end

    test "GET with X-Run-Id still passes through (no enforcement)", %{conn: conn} do
      run = insert(:run)

      conn =
        conn
        |> Map.put(:method, "GET")
        |> Map.put(:path_info, ["api", "v1", "tasks"])
        |> put_req_header("x-run-id", run.id)

      result = RunIdAudit.call(conn, [])
      # Should pass through without stamping on GET
      assert result.status == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Mutation requests without X-Run-Id — backward compat passthrough
  # ---------------------------------------------------------------------------

  describe "POST without X-Run-Id" do
    test "passes through for backward compat", %{conn: conn} do
      conn = %{conn | method: "POST", path_info: ["api", "v1", "tasks"]}
      result = RunIdAudit.call(conn, [])
      assert result.status == nil
      refute Map.has_key?(result.assigns, :run_id)
    end
  end

  # ---------------------------------------------------------------------------
  # /api/v1/runs/* — always bypass
  # ---------------------------------------------------------------------------

  describe "runs route bypass" do
    test "POST to /api/v1/runs bypasses enforcement even with header", %{conn: conn} do
      conn =
        conn
        |> Map.put(:method, "POST")
        |> Map.put(:path_info, ["api", "v1", "runs"])
        |> put_req_header("x-run-id", "R-UNKNOWN1")

      result = RunIdAudit.call(conn, [])
      # Not halted, no error
      assert result.status == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Valid X-Run-Id on mutation — stamp assigns
  # ---------------------------------------------------------------------------

  describe "valid X-Run-Id on mutation" do
    test "stamps run_id and run in conn.assigns", %{conn: conn} do
      run = insert(:run)

      conn =
        conn
        |> Map.put(:method, "POST")
        |> Map.put(:path_info, ["api", "v1", "tasks"])
        |> put_req_header("x-run-id", run.id)

      result = RunIdAudit.call(conn, [])
      assert result.assigns.run_id == run.id
      assert result.assigns.run.short_id == run.short_id
    end

    test "accepts short_id in header", %{conn: conn} do
      run = insert(:run)

      conn =
        conn
        |> Map.put(:method, "PATCH")
        |> Map.put(:path_info, ["api", "v1", "tasks", "T-00000001"])
        |> put_req_header("x-run-id", run.short_id)

      result = RunIdAudit.call(conn, [])
      assert result.assigns.run_id == run.id
    end
  end

  # ---------------------------------------------------------------------------
  # Invalid X-Run-Id — 422
  # ---------------------------------------------------------------------------

  describe "invalid X-Run-Id on mutation" do
    test "returns 422 for unknown run uuid", %{conn: conn} do
      conn =
        conn
        |> Map.put(:method, "POST")
        |> Map.put(:path_info, ["api", "v1", "tasks"])
        |> put_req_header("x-run-id", Ecto.UUID.generate())

      result = RunIdAudit.call(conn, [])
      assert result.status == 422
      assert result.halted
    end

    test "returns 422 for unknown short_id", %{conn: conn} do
      conn =
        conn
        |> Map.put(:method, "DELETE")
        |> Map.put(:path_info, ["api", "v1", "issues", "I-00000001"])
        |> put_req_header("x-run-id", "R-NOTEXIST")

      result = RunIdAudit.call(conn, [])
      assert result.status == 422
      assert result.halted
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: X-Run-Id flows through to controller assigns
  # ---------------------------------------------------------------------------

  describe "integration: X-Run-Id header reaches controller" do
    test "POST /api/v1/tasks with valid X-Run-Id stamps created_by_run_id", %{conn: conn} do
      run = insert(:run)

      conn =
        conn
        |> put_req_header("x-run-id", run.id)
        |> post("/api/v1/tasks", %{title: "Agent task", workspace_slug: "default"})

      body = json_response(conn, 201)
      assert body["data"]["created_by_run_id"] == run.id
    end

    test "POST /api/v1/issues with valid X-Run-Id stamps created_by_run_id", %{conn: conn} do
      run = insert(:run)

      conn =
        conn
        |> put_req_header("x-run-id", run.id)
        |> post("/api/v1/issues", %{title: "Agent issue", workspace_slug: "default"})

      body = json_response(conn, 201)
      assert body["data"]["created_by_run_id"] == run.id
    end

    test "POST /api/v1/tasks without X-Run-Id still works (created_by_run_id nil)", %{conn: conn} do
      conn = post(conn, "/api/v1/tasks", %{title: "Human task", workspace_slug: "default"})
      body = json_response(conn, 201)
      assert is_nil(body["data"]["created_by_run_id"])
    end
  end
end
