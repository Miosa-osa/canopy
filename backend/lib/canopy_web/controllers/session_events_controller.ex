defmodule CanopyWeb.SessionEventsController do
  @moduledoc """
  Server-Sent Events (SSE) streaming endpoint for session transcript entries.

  Route: GET /api/v1/sessions/:id/events

  Protocol:
  1. Verify the session exists (404 if not).
  2. Set SSE headers and send chunked HTTP response headers.
  3. Optionally replay history from `?from=<sequence>` via DB.
  4. Subscribe to `"session:<id>"` on Canopy.PubSub.
  5. Loop over incoming PubSub messages, format each as SSE, chunk-send.
  6. On completion event (`event: done`) or client disconnect, unsubscribe and close.

  SSE event format:
    event: transcript_entry
    data: {"kind":"assistant","content":{...},"emitted_at":"..."}

    event: status
    data: {"status":"running","cost_usd":"0.00","input_tokens":0,"output_tokens":0}

    event: done
    data: {}

  Client disconnect is detected via a `{:EXIT, _, _}` or send failure on
  `Plug.Conn.chunk/2`. The loop exits cleanly in both cases.

  Idle timeout: 300 seconds. After 300s without a message the loop sends a
  heartbeat comment (`: keepalive`) and resets the timer. If the session has
  already completed by the time the client subscribes, history is replayed and
  a `done` event is sent immediately.
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Sessions
  alias CanopyWeb.Schemas.RuntimeSchema

  require Logger

  @heartbeat_interval_ms 25_000
  @pubsub Canopy.PubSub

  tags ["sessions"]

  operation :stream,
    summary: "SSE stream for session events",
    description:
      "Streams TranscriptEntry events as Server-Sent Events. Supports ?from=<sequence> for replay.",
    parameters: [
      id: [in: :path, type: :string, required: true],
      from: [
        in: :query,
        type: :integer,
        required: false,
        description: "Replay from sequence number"
      ]
    ],
    responses: [
      ok: {"SSE stream", "text/event-stream", %OpenApiSpex.Schema{type: :string}},
      not_found: {"Not found", "application/json", RuntimeSchema.ErrorResponse}
    ]

  @spec stream(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def stream(conn, %{"id" => id} = params) do
    case Sessions.get(id) do
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Session #{id} does not exist."})

      {:ok, session} ->
        from_seq = parse_from(params["from"])
        conn = init_sse(conn)

        # Replay history before subscribing to avoid missing events
        {:ok, history} = Sessions.list_messages(id, from: from_seq)
        conn = replay_history(conn, history)

        # If session is already terminal, send done immediately after replay
        if session.status in ["completed", "cancelled", "failed"] do
          chunk_event(conn, "done", %{})
        else
          Phoenix.PubSub.subscribe(@pubsub, "session:#{id}")
          conn = sse_loop(conn, id)
          Phoenix.PubSub.unsubscribe(@pubsub, "session:#{id}")
          conn
        end
    end
  end

  # ---------------------------------------------------------------------------
  # SSE helpers
  # ---------------------------------------------------------------------------

  defp init_sse(conn) do
    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> put_resp_header("cache-control", "no-cache")
    |> put_resp_header("connection", "keep-alive")
    |> put_resp_header("x-accel-buffering", "no")
    |> send_chunked(200)
  end

  defp replay_history(conn, []), do: conn

  defp replay_history(conn, messages) do
    Enum.reduce(messages, conn, fn msg, acc ->
      payload = %{
        kind: msg.kind,
        content: msg.content,
        tool_call_id: msg.tool_call_id,
        sequence: msg.sequence,
        emitted_at: DateTime.to_iso8601(msg.emitted_at)
      }

      chunk_event(acc, "transcript_entry", payload)
    end)
  end

  defp sse_loop(conn, session_id) do
    receive do
      # TranscriptEntry broadcast from Runner
      {:transcript_entry, entry} ->
        payload = %{
          kind: entry.kind,
          content: entry.content,
          tool_call_id: entry.tool_call_id,
          sequence: entry.sequence,
          emitted_at: DateTime.to_iso8601(entry.emitted_at)
        }

        conn = chunk_event(conn, "transcript_entry", payload)

        # Completion signal inside the entry stream (system kind with completed event)
        if done_entry?(entry) do
          chunk_event(conn, "done", %{})
        else
          sse_loop(conn, session_id)
        end

      # Session status update (cost, tokens) from Runner finalization
      {:session_status, status_map} ->
        conn = chunk_event(conn, "status", status_map)
        sse_loop(conn, session_id)

      # Explicit completion signal from Runner
      :session_done ->
        chunk_event(conn, "done", %{})

      # Process exit or client disconnect
      {:EXIT, _pid, _reason} ->
        conn

      # Heartbeat to detect dead connections early
      :heartbeat ->
        case Plug.Conn.chunk(conn, ": keepalive\n\n") do
          {:ok, conn} -> sse_loop(conn, session_id)
          {:error, _chunk_err} -> conn
        end
    after
      @heartbeat_interval_ms ->
        case Plug.Conn.chunk(conn, ": keepalive\n\n") do
          {:ok, conn} ->
            # Re-check session status on each heartbeat to detect external completion
            case Sessions.get(session_id) do
              {:ok, %{status: status}} when status in ["completed", "cancelled", "failed"] ->
                chunk_event(conn, "done", %{})

              _other ->
                sse_loop(conn, session_id)
            end

          {:error, _chunk_err} ->
            conn
        end
    end
  end

  # Sends an SSE-formatted event chunk. Returns conn for chaining.
  # On send failure (client disconnected), logs and returns conn unmodified.
  @spec chunk_event(Plug.Conn.t(), String.t(), map()) :: Plug.Conn.t()
  defp chunk_event(conn, event_name, payload) do
    data = Jason.encode!(payload)
    line = "event: #{event_name}\ndata: #{data}\n\n"

    case Plug.Conn.chunk(conn, line) do
      {:ok, conn} ->
        conn

      {:error, reason} ->
        Logger.debug("[SSE] chunk failed session=#{conn.params["id"]} reason=#{inspect(reason)}")
        conn
    end
  end

  # Returns true when the entry signals session completion.
  defp done_entry?(%{kind: :system, content: %{"event" => "completed"}}), do: true
  defp done_entry?(%{kind: :result}), do: true
  defp done_entry?(_entry), do: false

  defp parse_from(nil), do: 0
  defp parse_from(val) when is_integer(val), do: val

  defp parse_from(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, ""} when n >= 0 -> n
      _other -> 0
    end
  end
end
