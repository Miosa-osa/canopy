defmodule CanopyWeb.UserSocket do
  @moduledoc """
  Phoenix socket for user-facing real-time channels.

  Mounted at `/socket` (distinct from the `/live` LiveView socket).
  Routes terminal:session:* topics to SessionTerminalChannel.

  Auth: for Week-0 dev, the connect callback accepts all connections
  unconditionally and assigns a nil user_id.
  TODO(auth): validate a signed token from the `token` query param,
  decode it with Guardian, and assign the real user_id before
  allowing the connection.
  """

  use Phoenix.Socket

  channel "terminal:session:*", CanopyWeb.SessionTerminalChannel
  channel "live_runs:*", CanopyWeb.LiveRunsChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    # TODO(auth): extract and verify params["token"] via Guardian.
    # For now, accept unconditionally — safe because the server only
    # runs locally (Tauri dev / loopback).
    {:ok, assign(socket, :user_id, nil)}
  end

  @impl true
  def id(_socket), do: nil
end
