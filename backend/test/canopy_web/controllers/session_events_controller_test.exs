defmodule CanopyWeb.SessionEventsControllerTest do
  @moduledoc """
  Tests for GET /api/v1/sessions/:id/events (SSE endpoint).

  These tests exercise the critical paths:
  1. 404 for unknown session.
  2. Immediate `done` event for completed sessions (with history replay).
  3. PubSub broadcast integration — events arrive and are sent to the client.

  Note: Full SSE streaming tests are integration-level. The `send_chunked` path
  cannot be easily tested with `Phoenix.ConnTest.get/2` because chunked responses
  complete asynchronously. We test the observable outcomes:
    - Correct 404 handling
    - Correct headers on a live connection
    - Replay of history for completed sessions (we inspect message replay via
      the response body for completed sessions that close immediately)

  For the live PubSub subscription path, we test the loop responds correctly
  to `:session_done` and `:session_status` messages by spawning a task that
  broadcasts to PubSub and verifying the response body contains expected events.
  """

  use CanopyWeb.ConnCase, async: false

  import Canopy.Factory

  alias Canopy.{PubSub, Sessions}
  alias Canopy.Runtimes.TranscriptEntry

  # ---------------------------------------------------------------------------
  # 404 handling
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/sessions/:id/events — 404" do
    test "returns 404 for unknown session", %{conn: conn} do
      conn = get(conn, "/api/v1/sessions/#{Ecto.UUID.generate()}/events")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # Completed session — replay + immediate close
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/sessions/:id/events — completed session" do
    test "returns 200 and sends history then done for completed session", %{conn: conn} do
      session =
        insert(:session,
          status: "completed",
          started_at: DateTime.add(DateTime.utc_now(), -60),
          completed_at: DateTime.utc_now()
        )

      now = DateTime.utc_now()

      Sessions.add_message(session.id, %{
        sequence: 0,
        kind: "assistant",
        content: %{"text" => "Hello from history"},
        emitted_at: now
      })

      Sessions.add_message(session.id, %{
        sequence: 1,
        kind: "system",
        content: %{"event" => "completed"},
        emitted_at: now
      })

      conn = get(conn, "/api/v1/sessions/#{session.id}/events")
      # The response is 200 (chunked). ConnTest returns the full body.
      assert conn.status == 200
      body = response(conn, 200)
      assert body =~ "event: transcript_entry"
      assert body =~ "Hello from history"
      # done event sent for completed sessions
      assert body =~ "event: done"
    end

    test "respects ?from param for history replay", %{conn: conn} do
      session =
        insert(:session,
          status: "completed",
          started_at: DateTime.add(DateTime.utc_now(), -60),
          completed_at: DateTime.utc_now()
        )

      now = DateTime.utc_now()

      for seq <- 0..3 do
        Sessions.add_message(session.id, %{
          sequence: seq,
          kind: "assistant",
          content: %{"text" => "Message #{seq}"},
          emitted_at: now
        })
      end

      conn = get(conn, "/api/v1/sessions/#{session.id}/events?from=2")
      body = response(conn, 200)

      # Sequences 0 and 1 should NOT appear
      refute body =~ "Message 0"
      refute body =~ "Message 1"
      # Sequences 2 and 3 should appear
      assert body =~ "Message 2"
      assert body =~ "Message 3"
    end

    test "sends done even with no history for completed session", %{conn: conn} do
      session =
        insert(:session,
          status: "completed",
          started_at: DateTime.add(DateTime.utc_now(), -60),
          completed_at: DateTime.utc_now()
        )

      conn = get(conn, "/api/v1/sessions/#{session.id}/events")
      assert conn.status == 200
      body = response(conn, 200)
      assert body =~ "event: done"
    end
  end

  # ---------------------------------------------------------------------------
  # Live session — PubSub integration
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # Terminal-event SSE close (audit fix #2)
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/sessions/:id/events — terminal events close the SSE loop" do
    test "stream closes on system entry with event=error", %{conn: conn} do
      session = insert(:session, status: "running", started_at: DateTime.utc_now())
      session_id = session.id
      topic = "session:#{session_id}"

      error_entry =
        TranscriptEntry.new(
          :system,
          %{"event" => "error", "message" => "subprocess crashed"},
          sequence: 1
        )

      task =
        Task.async(fn ->
          Process.sleep(50)
          Phoenix.PubSub.broadcast(PubSub, topic, {:transcript_entry, error_entry})
        end)

      conn = get(conn, "/api/v1/sessions/#{session_id}/events")
      Task.await(task)

      body = response(conn, 200)
      assert body =~ "event: transcript_entry"
      # done event must be sent after a terminal system entry
      assert body =~ "event: done"
    end

    test "stream closes on system entry with event=session_expired", %{conn: conn} do
      session = insert(:session, status: "running", started_at: DateTime.utc_now())
      session_id = session.id
      topic = "session:#{session_id}"

      expired_entry =
        TranscriptEntry.new(
          :system,
          %{"event" => "session_expired"},
          sequence: 1
        )

      task =
        Task.async(fn ->
          Process.sleep(50)
          Phoenix.PubSub.broadcast(PubSub, topic, {:transcript_entry, expired_entry})
        end)

      conn = get(conn, "/api/v1/sessions/#{session_id}/events")
      Task.await(task)

      body = response(conn, 200)
      assert body =~ "event: done"
    end

    test "stream closes on system entry with event=cancelled", %{conn: conn} do
      session = insert(:session, status: "running", started_at: DateTime.utc_now())
      session_id = session.id
      topic = "session:#{session_id}"

      cancelled_entry =
        TranscriptEntry.new(
          :system,
          %{"event" => "cancelled"},
          sequence: 1
        )

      task =
        Task.async(fn ->
          Process.sleep(50)
          Phoenix.PubSub.broadcast(PubSub, topic, {:transcript_entry, cancelled_entry})
        end)

      conn = get(conn, "/api/v1/sessions/#{session_id}/events")
      Task.await(task)

      body = response(conn, 200)
      assert body =~ "event: done"
    end
  end

  describe "GET /api/v1/sessions/:id/events — live session with PubSub" do
    test "receives session_done and returns done event", %{conn: conn} do
      session = insert(:session, status: "running", started_at: DateTime.utc_now())
      session_id = session.id
      topic = "session:#{session_id}"

      # Spawn a task that broadcasts :session_done after a brief delay
      # This simulates the Runner finishing execution
      task =
        Task.async(fn ->
          Process.sleep(50)
          Phoenix.PubSub.broadcast(PubSub, topic, :session_done)
        end)

      conn = get(conn, "/api/v1/sessions/#{session_id}/events")
      Task.await(task)

      assert conn.status == 200
      body = response(conn, 200)
      assert body =~ "event: done"
    end

    test "receives transcript_entry broadcasts and includes them in stream", %{conn: conn} do
      session = insert(:session, status: "running", started_at: DateTime.utc_now())
      session_id = session.id
      topic = "session:#{session_id}"

      entry =
        TranscriptEntry.new(
          :assistant,
          %{"text" => "Broadcast message"},
          sequence: 0
        )

      task =
        Task.async(fn ->
          Process.sleep(50)
          Phoenix.PubSub.broadcast(PubSub, topic, {:transcript_entry, entry})
          Process.sleep(10)
          Phoenix.PubSub.broadcast(PubSub, topic, :session_done)
        end)

      conn = get(conn, "/api/v1/sessions/#{session_id}/events")
      Task.await(task)

      body = response(conn, 200)
      assert body =~ "transcript_entry"
      assert body =~ "Broadcast message"
      assert body =~ "event: done"
    end

    test "receives session_status broadcast and includes status event", %{conn: conn} do
      session = insert(:session, status: "running", started_at: DateTime.utc_now())
      session_id = session.id
      topic = "session:#{session_id}"

      status_map = %{
        status: "completed",
        cost_usd: "0.0012",
        input_tokens: 100,
        output_tokens: 50
      }

      task =
        Task.async(fn ->
          Process.sleep(50)
          Phoenix.PubSub.broadcast(PubSub, topic, {:session_status, status_map})
          Process.sleep(10)
          Phoenix.PubSub.broadcast(PubSub, topic, :session_done)
        end)

      conn = get(conn, "/api/v1/sessions/#{session_id}/events")
      Task.await(task)

      body = response(conn, 200)
      assert body =~ "event: status"
      assert body =~ "0.0012"
    end

    test "replays history before subscribing to live events", %{conn: conn} do
      session = insert(:session, status: "running", started_at: DateTime.utc_now())
      session_id = session.id

      # Add a history message before subscribing
      Sessions.add_message(session_id, %{
        sequence: 0,
        kind: "assistant",
        content: %{"text" => "Pre-existing message"},
        emitted_at: DateTime.utc_now()
      })

      task =
        Task.async(fn ->
          Process.sleep(50)
          Phoenix.PubSub.broadcast(Canopy.PubSub, "session:#{session_id}", :session_done)
        end)

      conn = get(conn, "/api/v1/sessions/#{session_id}/events")
      Task.await(task)

      body = response(conn, 200)
      # History replayed before live events
      assert body =~ "Pre-existing message"
      assert body =~ "event: done"
    end
  end
end
