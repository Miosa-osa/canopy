defmodule CanopyWeb.WorktreeControllerTest do
  @moduledoc """
  Tests for the worktree endpoints on SessionsController.

  The integration tests spin up a real git repo in /tmp and create an actual
  worktree so we verify the full path: controller → Sessions context → WorktreeManager → git.
  The fallback test verifies that a workspace with a non-git root_path produces
  a session with nil worktree fields without raising.
  """

  use CanopyWeb.ConnCase, async: false

  import Canopy.Factory
  import Mox

  alias Canopy.Runtimes.{MockAdapter, RegistryServer}
  alias Canopy.Sessions

  setup :verify_on_exit!

  @mock_type "mock-adapter"

  defp setup_mock_adapter do
    Mox.stub(MockAdapter, :type, fn -> @mock_type end)

    Mox.stub(MockAdapter, :execute, fn _ctx ->
      {:ok, %{pid: self(), session_id: "mock-session"}}
    end)

    RegistryServer.register(MockAdapter)
  end

  defp unregister_mock, do: RegistryServer.unregister(@mock_type)

  # Initialises a git repo with one commit and returns the path.
  defp init_git_repo do
    path = Path.join(System.tmp_dir!(), "canopy-wt-ctrl-#{System.unique_integer([:positive])}")
    File.mkdir_p!(path)
    {_, 0} = System.cmd("git", ["init"], cd: path, stderr_to_stdout: true)
    {_, 0} = System.cmd("git", ["config", "user.email", "test@canopy.test"], cd: path)
    {_, 0} = System.cmd("git", ["config", "user.name", "Canopy Test"], cd: path)
    File.write!(Path.join(path, "README.md"), "# test")
    {_, 0} = System.cmd("git", ["add", "."], cd: path)
    {_, 0} = System.cmd("git", ["commit", "-m", "init"], cd: path, stderr_to_stdout: true)
    path
  end

  defp cleanup_repo(path), do: File.rm_rf(path)

  # ---------------------------------------------------------------------------
  # GET /api/v1/sessions/:id/worktree — no worktree
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/sessions/:id/worktree (no worktree)" do
    test "returns exists: false when session has no worktree", %{conn: conn} do
      session = insert(:session)
      conn = get(conn, "/api/v1/sessions/#{session.id}/worktree")
      body = json_response(conn, 200)

      assert body["exists"] == false
      assert body["changes_count"] == 0
      assert is_nil(body["path"])
    end

    test "returns 404 for unknown session", %{conn: conn} do
      conn = get(conn, "/api/v1/sessions/00000000-0000-0000-0000-000000000000/worktree")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # Fallback: workspace is NOT a git repo
  # ---------------------------------------------------------------------------

  describe "session spawn fallback (non-git workspace)" do
    test "session gets nil worktree fields when workspace root is not a git repo", %{conn: conn} do
      setup_mock_adapter()
      plain_dir = Path.join(System.tmp_dir!(), "plain-#{System.unique_integer([:positive])}")
      File.mkdir_p!(plain_dir)

      workspace = insert(:workspace, root_path: plain_dir)

      conn =
        post(conn, "/api/v1/sessions", %{
          "runtime_type" => @mock_type,
          "cwd" => plain_dir,
          "workspace_slug" => workspace.slug
        })

      body = json_response(conn, 201)
      session_id = body["session_id"]

      {:ok, session} = Sessions.get(session_id)
      assert is_nil(session.worktree_path)
      assert is_nil(session.branch)
      assert is_nil(session.base_branch)

      unregister_mock()
      File.rm_rf(plain_dir)
    end
  end

  # ---------------------------------------------------------------------------
  # Full worktree lifecycle: create session → worktree_status → diff → commit → cleanup
  # ---------------------------------------------------------------------------

  describe "worktree lifecycle (real git repo)" do
    test "spawn creates worktree, status reflects it, cleanup removes it", %{conn: conn} do
      setup_mock_adapter()
      repo = init_git_repo()

      workspace = insert(:workspace, root_path: repo)

      conn =
        post(conn, "/api/v1/sessions", %{
          "runtime_type" => @mock_type,
          "cwd" => repo,
          "workspace_slug" => workspace.slug
        })

      body = json_response(conn, 201)
      session_id = body["session_id"]

      {:ok, session} = Sessions.get(session_id)

      worktree_path = session.worktree_path

      try do
        refute is_nil(worktree_path)
        assert File.dir?(worktree_path)
        assert session.branch =~ ~r/^session\//
        assert is_binary(session.base_branch)

        # GET worktree/status
        status_conn = get(build_conn(), "/api/v1/sessions/#{session_id}/worktree")
        status = json_response(status_conn, 200)
        assert status["exists"] == true
        assert status["path"] == worktree_path

        # GET worktree/diff (empty worktree — no changes)
        diff_conn = get(build_conn(), "/api/v1/sessions/#{session_id}/worktree/diff")
        diff_body = json_response(diff_conn, 200)
        assert is_binary(diff_body["diff"])
        assert diff_body["truncated"] == false

        # Write a file into the worktree to produce a diff
        File.write!(Path.join(worktree_path, "agent-output.txt"), "some output")

        # POST worktree/commit
        commit_conn =
          post(build_conn(), "/api/v1/sessions/#{session_id}/worktree/commit", %{
            "message" => "agent work"
          })

        commit_body = json_response(commit_conn, 200)
        assert commit_body["ok"] == true
        assert is_binary(commit_body["output"])

        # POST cleanup_worktree
        cleanup_conn = post(build_conn(), "/api/v1/sessions/#{session_id}/cleanup_worktree")
        cleanup_body = json_response(cleanup_conn, 200)
        assert cleanup_body["ok"] == true

        refute File.dir?(worktree_path)

        # Verify DB fields cleared
        {:ok, cleaned} = Sessions.get(session_id)
        assert is_nil(cleaned.worktree_path)
      after
        # Best-effort cleanup in case test fails mid-way
        if worktree_path, do: File.rm_rf(worktree_path)
        cleanup_repo(repo)
        unregister_mock()
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/sessions/:id/worktree/diff — no worktree
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/sessions/:id/worktree/diff (no worktree)" do
    test "returns empty diff with informational message", %{conn: conn} do
      session = insert(:session)
      conn = get(conn, "/api/v1/sessions/#{session.id}/worktree/diff")
      body = json_response(conn, 200)

      assert body["diff"] == ""
      assert body["truncated"] == false
      assert is_binary(body["message"])
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/sessions/:id/worktree/commit — no worktree
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/sessions/:id/worktree/commit (no worktree)" do
    test "returns 422 when session has no worktree", %{conn: conn} do
      session = insert(:session)

      conn =
        post(conn, "/api/v1/sessions/#{session.id}/worktree/commit", %{
          "message" => "test"
        })

      body = json_response(conn, 422)
      assert body["error"] == "no_worktree"
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/sessions/:id/cleanup_worktree — already clean
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/sessions/:id/cleanup_worktree (no worktree)" do
    test "returns ok when session has no worktree (idempotent)", %{conn: conn} do
      session = insert(:session)
      conn = post(conn, "/api/v1/sessions/#{session.id}/cleanup_worktree")
      body = json_response(conn, 200)
      assert body["ok"] == true
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/sessions/:id/worktree — RESTful cleanup endpoint
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/sessions/:id/worktree (no worktree)" do
    test "returns ok when session has no worktree (idempotent)", %{conn: conn} do
      session = insert(:session)
      conn = delete(conn, "/api/v1/sessions/#{session.id}/worktree")
      body = json_response(conn, 200)
      assert body["ok"] == true
    end

    test "returns 404 for unknown session", %{conn: conn} do
      conn = delete(conn, "/api/v1/sessions/00000000-0000-0000-0000-000000000000/worktree")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/sessions/:id/worktree/push — no worktree
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/sessions/:id/worktree/push (no worktree)" do
    test "returns 422 when session has no worktree", %{conn: conn} do
      session = insert(:session)
      conn = post(conn, "/api/v1/sessions/#{session.id}/worktree/push", %{})
      body = json_response(conn, 422)
      assert body["error"] == "no_worktree"
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/sessions/:id/worktree/merge — no worktree
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/sessions/:id/worktree/merge (no worktree)" do
    test "returns 422 when session has no worktree", %{conn: conn} do
      session = insert(:session)
      conn = post(conn, "/api/v1/sessions/#{session.id}/worktree/merge", %{})
      body = json_response(conn, 422)
      assert body["error"] == "no_worktree"
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/sessions/:id/worktree — enriched status fields
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/sessions/:id/worktree — enriched status" do
    test "returns has_changes, ahead, behind fields", %{conn: conn} do
      session = insert(:session)
      conn = get(conn, "/api/v1/sessions/#{session.id}/worktree")
      body = json_response(conn, 200)

      assert Map.has_key?(body, "has_changes")
      assert Map.has_key?(body, "ahead")
      assert Map.has_key?(body, "behind")
      assert Map.has_key?(body, "changes_count")
    end
  end

  # ---------------------------------------------------------------------------
  # Full lifecycle with push — smoke test (no remote, just ensure no crash)
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/sessions/:id/worktree/push — no remote" do
    test "returns push_failed error when origin is not configured", %{conn: conn} do
      setup_mock_adapter()
      repo = init_git_repo()
      workspace = insert(:workspace, root_path: repo)

      conn =
        post(conn, "/api/v1/sessions", %{
          "runtime_type" => @mock_type,
          "cwd" => repo,
          "workspace_slug" => workspace.slug
        })

      body = json_response(conn, 201)
      session_id = body["session_id"]

      {:ok, session} = Sessions.get(session_id)
      worktree_path = session.worktree_path

      try do
        refute is_nil(worktree_path)

        push_conn = post(build_conn(), "/api/v1/sessions/#{session_id}/worktree/push", %{})
        push_body = json_response(push_conn, 422)
        assert push_body["error"] == "push_failed"
      after
        if worktree_path, do: File.rm_rf(worktree_path)
        cleanup_repo(repo)
        unregister_mock()
      end
    end
  end
end
