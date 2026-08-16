defmodule CanopyWeb.ScrollbackController do
  @moduledoc """
  GET /api/v1/sessions/:id/scrollback

  Returns raw pty output bytes for cold-restore. The client writes these bytes
  directly to xterm.js before opening the WebSocket so the user sees history
  instead of a blank terminal pane.

  Query params:
  - `last_n`  — return approximately last N lines (default 1000)
  - `from`    — byte offset to read from (for polling; overrides last_n)
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Sessions.ScrollbackStore
  alias CanopyWeb.Schemas.ScrollbackSchema

  action_fallback CanopyWeb.FallbackController

  tags ["sessions"]

  operation :show,
    summary: "Fetch terminal scrollback",
    description:
      "Returns buffered pty output for a session. Use `last_n` for cold restore " <>
        "or `from=<offset>` for incremental polling.",
    parameters: [
      id: [in: :path, type: :string, required: true, description: "Session ID"],
      last_n: [in: :query, type: :integer, required: false, description: "Last N lines"],
      from: [in: :query, type: :integer, required: false, description: "Byte offset"]
    ],
    responses: [
      ok: {"Scrollback response", "application/json", ScrollbackSchema.ScrollbackResponse}
    ]

  def show(conn, %{"id" => session_id} = params) do
    opts = build_opts(params)

    case ScrollbackStore.read(session_id, opts) do
      {:ok, data, total_bytes} ->
        encoded = Base.encode64(data)

        json(conn, %{
          session_id: session_id,
          data: encoded,
          offset: total_bytes,
          total_bytes: total_bytes,
          truncated: false
        })

      {:error, :not_found} ->
        # Store not running — session may be complete; try reading the log file directly.
        case read_log_file(session_id, opts) do
          {:ok, data, total_bytes} ->
            json(conn, %{
              session_id: session_id,
              data: Base.encode64(data),
              offset: total_bytes,
              total_bytes: total_bytes,
              truncated: false
            })

          {:error, _} ->
            json(conn, %{
              session_id: session_id,
              data: "",
              offset: 0,
              total_bytes: 0,
              truncated: false
            })
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp build_opts(params) do
    cond do
      Map.has_key?(params, "from") ->
        case Integer.parse(params["from"]) do
          {offset, _} -> [from: offset]
          :error -> []
        end

      Map.has_key?(params, "last_n") ->
        case Integer.parse(params["last_n"]) do
          {n, _} -> [last_n_lines: n]
          :error -> [last_n_lines: 1000]
        end

      true ->
        [last_n_lines: 1000]
    end
  end

  defp read_log_file(session_id, opts) do
    dir = Path.join(System.user_home!(), ".canopy/scrollback")
    path = Path.join(dir, "#{session_id}.log")

    case File.stat(path) do
      {:ok, %{size: total}} ->
        data =
          cond do
            Keyword.has_key?(opts, :from) ->
              offset = Keyword.fetch!(opts, :from)
              read_from(path, offset, total)

            Keyword.has_key?(opts, :last_n_lines) ->
              n = Keyword.fetch!(opts, :last_n_lines)
              read_last_lines(path, n, total)

            true ->
              read_from(path, 0, total)
          end

        {:ok, data, total}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp read_from(_path, offset, total) when offset >= total, do: <<>>

  defp read_from(path, offset, total) do
    length = total - offset

    case :file.open(String.to_charlist(path), [:read, :binary, :raw]) do
      {:ok, fd} ->
        :file.position(fd, offset)
        {:ok, data} = :file.read(fd, length)
        :file.close(fd)
        data

      {:error, _} ->
        <<>>
    end
  end

  defp read_last_lines(path, n, total) do
    chunk = 65_536
    start = max(0, total - chunk * 4)
    data = read_from(path, start, total)
    lines = :binary.split(data, "\n", [:global])
    tail = Enum.take(lines, -n)
    Enum.join(tail, "\n")
  end
end
