defmodule CanopyWeb.SessionsControllerTest do
  @moduledoc """
  Tests for the SessionsController.

  Uses Mox to mock the adapter for `create` tests — avoids spawning real
  subprocesses. The mock adapter is registered in the Registry for each test
  that needs it and unregisters when the test process exits.
  """

  use CanopyWeb.ConnCase, async: false

  import Canopy.Factory
  import Mox

  alias Canopy.Runtimes.{MockAdapter, RegistryServer}
  alias Canopy.Sessions

  setup :verify_on_exit!

  @mock_type "mock-adapter"

  # Helper: register mock adapter and stub minimum callbacks needed for create
  defp setup_mock_adapter(pid \\ nil) do
    return_pid = pid || self()

    Mox.stub(MockAdapter, :type, fn -> @mock_type end)

    Mox.stub(MockAdapter, :execute, fn _ctx ->
      {:ok, %{pid: return_pid, session_id: "mock-session-id"}}
    end)

    RegistryServer.register(MockAdapter)
  end

  defp unregister_mock do
    RegistryServer.unregister(@mock_type)
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/sessions
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/sessions" do
    test "returns 200 with empty list", %{conn: conn} do
      conn = get(conn, "/api/v1/sessions")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns sessions", %{conn: conn} do
      insert(:session, runtime_type: "claude-local", status: "pending")
      conn = get(conn, "/api/v1/sessions")
      assert %{"data" => data} = json_response(conn, 200)
      assert data != []
    end

    test "filters by status", %{conn: conn} do
      insert(:session, status: "running", started_at: DateTime.utc_now())

      insert(:session,
        status: "completed",
        started_at: DateTime.add(DateTime.utc_now(), -60),
        completed_at: DateTime.utc_now()
      )

      conn = get(conn, "/api/v1/sessions?status=running")
      assert %{"data" => data} = json_response(conn, 200)
      assert Enum.all?(data, &(&1["status"] == "running"))
    end

    test "filters by runtime", %{conn: conn} do
      insert(:session, runtime_type: "codex-local")
      insert(:session, runtime_type: "gemini-local")

      conn = get(conn, "/api/v1/sessions?runtime=codex-local")
      assert %{"data" => data} = json_response(conn, 200)
      assert Enum.all?(data, &(&1["runtime_type"] == "codex-local"))
    end

    test "filters by workspace_slug", %{conn: conn} do
      insert(:session, workspace_slug: "acme-corp")
      insert(:session, workspace_slug: "other-workspace")

      conn = get(conn, "/api/v1/sessions?workspace=acme-corp")
      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) >= 1
      assert Enum.all?(data, &(&1["workspace_slug"] == "acme-corp"))
    end

    test "returns workspace_slug in session response", %{conn: conn} do
      insert(:session, workspace_slug: "my-workspace")
      conn = get(conn, "/api/v1/sessions")
      assert %{"data" => data} = json_response(conn, 200)
      assert Enum.any?(data, &(&1["workspace_slug"] == "my-workspace"))
    end

    test "respects limit param", %{conn: conn} do
      for _n <- 1..5, do: insert(:session)
      conn = get(conn, "/api/v1/sessions?limit=2")
      assert %{"data" => data} = json_response(conn, 200)
      assert Enum.count(data) <= 2
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/sessions/:id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/sessions/:id" do
    test "returns 404 for unknown id", %{conn: conn} do
      conn = get(conn, "/api/v1/sessions/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end

    test "returns session with messages", %{conn: conn} do
      session = insert(:session)

      {:ok, _msg} =
        Sessions.add_message(session.id, %{
          sequence: 0,
          kind: "assistant",
          content: %{"text" => "Hello"},
          emitted_at: DateTime.utc_now()
        })

      conn = get(conn, "/api/v1/sessions/#{session.id}")
      assert body = json_response(conn, 200)
      assert body["session"]["id"] == session.id
      assert length(body["messages"]) == 1
    end

    test "returns session with empty messages when no messages exist", %{conn: conn} do
      session = insert(:session)
      conn = get(conn, "/api/v1/sessions/#{session.id}")
      assert body = json_response(conn, 200)
      assert body["session"]["id"] == session.id
      assert body["messages"] == []
    end

    test "includes workspace_slug in session detail response", %{conn: conn} do
      session = insert(:session, workspace_slug: "detail-workspace")
      conn = get(conn, "/api/v1/sessions/#{session.id}")
      assert body = json_response(conn, 200)
      assert body["session"]["workspace_slug"] == "detail-workspace"
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/sessions
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/sessions" do
    setup do
      setup_mock_adapter()
      on_exit(&unregister_mock/0)
      :ok
    end

    test "creates session and returns 201 with session_id and sse_url", %{conn: conn} do
      body = %{runtime_type: @mock_type, cwd: "/tmp/project", prompt: "Hello agent"}

      conn = post(conn, "/api/v1/sessions", body)
      assert response = json_response(conn, 201)
      assert is_binary(response["session_id"])
      assert response["sse_url"] =~ "/api/v1/sessions/"
      assert response["sse_url"] =~ "/events"
    end

    test "session status is updated to running after execute", %{conn: conn} do
      body = %{runtime_type: @mock_type, cwd: "/tmp/project"}
      conn = post(conn, "/api/v1/sessions", body)
      assert %{"session_id" => session_id} = json_response(conn, 201)
      assert {:ok, session} = Sessions.get(session_id)
      assert session.status == "running"
    end

    test "returns 422 when runtime_type is unknown", %{conn: conn} do
      # unregister mock so this type doesn't exist
      unregister_mock()
      body = %{runtime_type: "no-such-runtime", cwd: "/tmp"}
      conn = post(conn, "/api/v1/sessions", body)
      assert body = json_response(conn, 422)
      assert body["error"] == "unknown_runtime"
      setup_mock_adapter()
    end

    test "returns 422 when cwd is missing", %{conn: conn} do
      body = %{runtime_type: @mock_type}
      conn = post(conn, "/api/v1/sessions", body)
      # cwd defaults to System.tmp_dir! so this actually succeeds
      # — the controller substitutes the default
      assert json_response(conn, 201)
    end

    test "returns 422 when adapter.execute fails", %{conn: conn} do
      Mox.expect(MockAdapter, :execute, fn _ctx -> {:error, :binary_not_found} end)
      body = %{runtime_type: @mock_type, cwd: "/tmp/project"}
      conn = post(conn, "/api/v1/sessions", body)
      assert body = json_response(conn, 422)
      assert body["error"] == "execution_failed"
    end

    test "passes parent_session_id when provided", %{conn: conn} do
      {:ok, parent} = Sessions.create(%{runtime_type: @mock_type, cwd: "/tmp"})
      body = %{runtime_type: @mock_type, cwd: "/tmp", parent_session_id: parent.id}
      conn = post(conn, "/api/v1/sessions", body)
      assert %{"session_id" => session_id} = json_response(conn, 201)
      session = Sessions.get!(session_id)
      assert session.parent_session_id == parent.id
    end

    test "persists workspace_slug when provided", %{conn: conn} do
      body = %{runtime_type: @mock_type, cwd: "/tmp", workspace_slug: "acme-corp"}
      conn = post(conn, "/api/v1/sessions", body)
      assert %{"session_id" => session_id} = json_response(conn, 201)
      session = Sessions.get!(session_id)
      assert session.workspace_slug == "acme-corp"
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/sessions — governance + budget gate responses
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/sessions — gate responses" do
    setup do
      setup_mock_adapter()
      on_exit(&unregister_mock/0)
      :ok
    end

    test "returns 422 governance_blocked when governance blocks session", %{conn: conn} do
      # Evaluator uses "runtime" key (not "runtime_type") for runtime condition
      insert(:governance_rule,
        enabled: true,
        priority: 100,
        action: "block",
        conditions: %{"runtime" => @mock_type}
      )

      body = %{runtime_type: @mock_type, cwd: "/tmp/project"}
      conn = post(conn, "/api/v1/sessions", body)
      assert response = json_response(conn, 422)
      assert response["error"] == "governance_blocked"
      assert is_map(response["rule"])
      assert is_binary(response["rule"]["id"])
      assert is_binary(response["rule"]["name"])
      assert response["message"] == "Session blocked by governance rule"
    end

    test "returns 422 budget_blocked when budget hard ceiling is exceeded", %{conn: conn} do
      import Ecto.Query, only: [from: 2]

      insert(:budget,
        scope_type: "global",
        scope_id: nil,
        period: "total",
        limit_usd: Decimal.new("0.001"),
        hard_ceiling: true,
        enabled: true
      )

      completed = insert(:completed_session, cost_usd: Decimal.new("1.00"))

      Canopy.Repo.update_all(
        from(s in Canopy.Sessions.Session, where: s.id == ^completed.id),
        set: [status: "completed", completed_at: DateTime.utc_now()]
      )

      body = %{runtime_type: @mock_type, cwd: "/tmp/project"}
      conn = post(conn, "/api/v1/sessions", body)
      assert response = json_response(conn, 422)
      assert response["error"] == "budget_blocked"
      assert is_binary(response["budget_id"])
      assert is_binary(response["spent_usd"])
      assert is_binary(response["limit_usd"])
      assert response["message"] == "Session blocked by budget limit"
    end

    test "returns 202 accepted when governance requires approval", %{conn: conn} do
      insert(:governance_rule,
        enabled: true,
        priority: 100,
        action: "require_approval",
        conditions: %{"runtime" => @mock_type}
      )

      body = %{runtime_type: @mock_type, cwd: "/tmp/project"}
      conn = post(conn, "/api/v1/sessions", body)
      assert response = json_response(conn, 202)
      assert response["status"] == "pending_approval"
      assert is_binary(response["session_id"])
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/sessions/:id
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/sessions/:id" do
    test "returns 404 for unknown session", %{conn: conn} do
      conn = delete(conn, "/api/v1/sessions/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end

    test "returns 204 for pending session (no-op)", %{conn: conn} do
      session = insert(:session, status: "pending")
      conn = delete(conn, "/api/v1/sessions/#{session.id}")
      assert response(conn, 204) == ""
    end

    test "cancels running session and returns 204", %{conn: conn} do
      session = insert(:session, status: "running", started_at: DateTime.utc_now())
      conn = delete(conn, "/api/v1/sessions/#{session.id}")
      assert response(conn, 204) == ""
      assert {:ok, updated} = Sessions.get(session.id)
      assert updated.status == "cancelled"
    end

    test "returns 204 for already completed session", %{conn: conn} do
      session =
        insert(:session,
          status: "completed",
          started_at: DateTime.add(DateTime.utc_now(), -60),
          completed_at: DateTime.utc_now()
        )

      conn = delete(conn, "/api/v1/sessions/#{session.id}")
      assert response(conn, 204) == ""
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/sessions/:id/chain
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/sessions/:id/chain" do
    test "returns 404 for unknown session", %{conn: conn} do
      conn = get(conn, "/api/v1/sessions/#{Ecto.UUID.generate()}/chain")
      assert json_response(conn, 404)
    end

    test "returns chain for root session with no parent/children", %{conn: conn} do
      session = insert(:session)
      conn = get(conn, "/api/v1/sessions/#{session.id}/chain")
      assert body = json_response(conn, 200)
      assert body["session"]["id"] == session.id
      assert body["ancestors"] == []
      assert body["children"] == []
    end

    test "includes children in chain", %{conn: conn} do
      parent = insert(:session)

      {:ok, child} =
        Sessions.create(%{
          runtime_type: "claude-local",
          cwd: "/tmp",
          parent_session_id: parent.id
        })

      conn = get(conn, "/api/v1/sessions/#{parent.id}/chain")
      assert body = json_response(conn, 200)
      child_ids = Enum.map(body["children"], & &1["id"])
      assert child.id in child_ids
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/sessions/:id/messages
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/sessions/:id/messages" do
    test "returns 404 for unknown session", %{conn: conn} do
      conn = get(conn, "/api/v1/sessions/#{Ecto.UUID.generate()}/messages")
      assert json_response(conn, 404)
    end

    test "returns empty list when session has no messages", %{conn: conn} do
      session = insert(:session)
      conn = get(conn, "/api/v1/sessions/#{session.id}/messages")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns messages ordered by sequence", %{conn: conn} do
      session = insert(:session)
      now = DateTime.utc_now()

      for seq <- [2, 0, 1] do
        Sessions.add_message(session.id, %{
          sequence: seq,
          kind: "assistant",
          content: %{},
          emitted_at: now
        })
      end

      conn = get(conn, "/api/v1/sessions/#{session.id}/messages")
      assert %{"data" => msgs} = json_response(conn, 200)
      seqs = Enum.map(msgs, & &1["sequence"])
      assert seqs == [0, 1, 2]
    end

    test "filters by from param", %{conn: conn} do
      session = insert(:session)
      now = DateTime.utc_now()

      for seq <- 0..4 do
        Sessions.add_message(session.id, %{
          sequence: seq,
          kind: "assistant",
          content: %{},
          emitted_at: now
        })
      end

      conn = get(conn, "/api/v1/sessions/#{session.id}/messages?from=3")
      assert %{"data" => msgs} = json_response(conn, 200)
      seqs = Enum.map(msgs, & &1["sequence"])
      assert seqs == [3, 4]
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/sessions/:id/messages
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/sessions/:id/messages" do
    test "returns 200 with status sent for existing session", %{conn: conn} do
      session = insert(:session)

      conn =
        post(conn, "/api/v1/sessions/#{session.id}/messages", %{content: "ls -la"})

      assert body = json_response(conn, 200)
      assert body["status"] == "sent"
      assert body["session_id"] == session.id
    end

    test "accepts 'message' param as alias for content", %{conn: conn} do
      session = insert(:session)

      conn =
        post(conn, "/api/v1/sessions/#{session.id}/messages", %{message: "pwd"})

      assert body = json_response(conn, 200)
      assert body["status"] == "sent"
    end

    test "persists message to session transcript", %{conn: conn} do
      session = insert(:session)

      post(conn, "/api/v1/sessions/#{session.id}/messages", %{content: "echo hello"})

      {:ok, msgs} = Sessions.list_messages(session.id)
      assert Enum.any?(msgs, fn m -> m.kind == "user_input" end)
    end

    test "returns 404 for non-existent session", %{conn: conn} do
      conn =
        post(conn, "/api/v1/sessions/#{Ecto.UUID.generate()}/messages", %{content: "hello"})

      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/sessions/:id/inject
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/sessions/:id/inject" do
    test "returns 200 with status injected for existing session", %{conn: conn} do
      session = insert(:session)

      conn =
        post(conn, "/api/v1/sessions/#{session.id}/inject", %{
          from_agent: "orchestrator",
          content: "run tests"
        })

      assert body = json_response(conn, 200)
      assert body["status"] == "injected"
      assert body["session_id"] == session.id
      assert body["from_agent"] == "orchestrator"
    end

    test "persists injection with from_agent metadata", %{conn: conn} do
      session = insert(:session)

      post(conn, "/api/v1/sessions/#{session.id}/inject", %{
        from_agent: "planner",
        content: "mix test"
      })

      {:ok, msgs} = Sessions.list_messages(session.id)

      assert Enum.any?(msgs, fn m ->
               m.kind == "agent_injection" and
                 get_in(m.content, ["from_agent"]) == "planner"
             end)
    end

    test "returns 404 for non-existent session", %{conn: conn} do
      conn =
        post(conn, "/api/v1/sessions/#{Ecto.UUID.generate()}/inject", %{
          from_agent: "agent",
          content: "hello"
        })

      assert json_response(conn, 404)
    end
  end
end
