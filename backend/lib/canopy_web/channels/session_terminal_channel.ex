defmodule CanopyWeb.SessionTerminalChannel do
  @moduledoc """
  Phoenix Channel that bridges a browser xterm.js session to a local pty.

  Topic format: "terminal:session:<uuid>"

  Inbound events (from browser):
  - "input"  %{"data" => binary}  — forward to pty stdin
  - "resize" %{"cols" => int, "rows" => int} — resize the pty window

  Outbound events (pushed to browser):
  - "output" %{data: binary} — pty stdout bytes
  - "exit"   %{code: integer | nil} — pty process exited

  The channel subscribes to pty output via PtyBridge.attach/2.
  On disconnect the bridge process is stopped (pty is killed).
  """

  use Phoenix.Channel

  alias Canopy.Agents.SpawnPipeline
  alias Canopy.Sessions
  alias Canopy.Sessions.PtyBridge

  require Logger

  # ---------------------------------------------------------------------------
  # Join
  # ---------------------------------------------------------------------------

  @impl true
  def join("terminal:session:" <> session_id, _params, socket) do
    case Sessions.get(session_id) do
      {:error, :not_found} ->
        {:error, %{reason: "not_found"}}

      {:ok, session} ->
        # Use SpawnPipeline instead of raw bridge start.
        # Idempotent: if the pty is already running (session created with
        # interactive: true), pipeline returns the existing run + os_pid.
        case SpawnPipeline.spawn(session, wake_reason: "user_prompt") do
          {:ok, _result} ->
            :ok = PtyBridge.attach(session_id, self())
            {:ok, assign(socket, :session_id, session_id)}

          {:error, _stage, reason} ->
            Logger.warning(
              "[SessionTerminalChannel] SpawnPipeline failed session_id=#{session_id}: #{inspect(reason)}"
            )

            {:error, %{reason: "pty_start_failed"}}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Inbound events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_in("input", %{"data" => data}, socket) do
    PtyBridge.send_input(socket.assigns.session_id, data)
    {:noreply, socket}
  end

  @impl true
  def handle_in("resize", %{"cols" => cols, "rows" => rows}, socket) do
    PtyBridge.resize(socket.assigns.session_id, cols, rows)
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Pty output messages (from PtyBridge)
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({:pty_output, data}, socket) do
    push(socket, "output", %{data: data})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:pty_exit, code}, socket) do
    push(socket, "exit", %{code: code})
    {:stop, :normal, socket}
  end

  # ---------------------------------------------------------------------------
  # Terminate — kill pty when channel closes
  # ---------------------------------------------------------------------------

  @impl true
  def terminate(_reason, socket) do
    # Detach this subscriber from the pty output broadcast, but do NOT kill
    # the pty — another channel (e.g. the Terminal Harness) may still be
    # subscribed, and the pty should outlive any single WebSocket. The pty
    # is only explicitly killed via POST /sessions/:id/stop or when the
    # session row is deleted.
    session_id = socket.assigns[:session_id]

    if session_id do
      PtyBridge.detach(session_id, self())
    end

    :ok
  end
end
