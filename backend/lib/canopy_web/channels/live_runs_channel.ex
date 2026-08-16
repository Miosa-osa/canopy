defmodule CanopyWeb.LiveRunsChannel do
  @moduledoc """
  Phoenix Channel for streaming run lifecycle events to the UI.

  ## Topics

  - `live_runs:workspace:<slug>` — all runs in a workspace
  - `live_runs:run:<short_id>`  — per-run stream (log chunks, tool calls)
  - `live_runs:all`             — admin/debug; every run on the machine

  ## Event types (pushed to subscriber)

  - `run_started`      — run transitioned queued → running
  - `run_status`       — run paused or resumed
  - `run_log`          — stdout/stderr chunk from ScrollbackStore
  - `run_event`        — structured agent event (tool lifecycle, permissions)
  - `run_tool_call`    — tool dispatched
  - `run_tool_result`  — tool returned
  - `run_finished`     — run reached terminal status

  ## Auth

  Week-0 dev: all joins are accepted unconditionally.
  TODO(auth): verify a signed token before allowing the join.
  """

  use Phoenix.Channel

  require Logger

  # ---------------------------------------------------------------------------
  # Join
  # ---------------------------------------------------------------------------

  @impl true
  def join("live_runs:workspace:" <> slug, _params, socket) do
    Logger.debug("[LiveRunsChannel] join workspace=#{slug}")
    {:ok, assign(socket, :scope, {:workspace, slug})}
  end

  @impl true
  def join("live_runs:run:" <> short_id, _params, socket) do
    Logger.debug("[LiveRunsChannel] join run=#{short_id}")
    {:ok, assign(socket, :scope, {:run, short_id})}
  end

  @impl true
  def join("live_runs:all", _params, socket) do
    Logger.debug("[LiveRunsChannel] join all")
    {:ok, assign(socket, :scope, :all)}
  end

  @impl true
  def join(topic, _params, _socket) do
    Logger.warning("[LiveRunsChannel] unrecognised topic=#{topic}")
    {:error, %{reason: "invalid_topic"}}
  end

  # ---------------------------------------------------------------------------
  # No inbound events — this is a read-only broadcast channel
  # ---------------------------------------------------------------------------

  @impl true
  def handle_in(event, _params, socket) do
    Logger.debug("[LiveRunsChannel] unexpected inbound event=#{event} — ignored")
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # PubSub → client relay
  # The channel subscribes to its topic at join time via the channel framework.
  # PubSub broadcasts hit handle_info/2 as {:broadcast, event, payload}.
  # We relay them directly to the socket.
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({event, payload}, socket)
      when event in [
             :run_started,
             :run_status,
             :run_log,
             :run_event,
             :run_tool_call,
             :run_tool_result,
             :run_finished
           ] do
    push(socket, Atom.to_string(event), payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}
end
