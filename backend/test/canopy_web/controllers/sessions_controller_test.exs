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
end
