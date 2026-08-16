defmodule CanopyWeb.RelayController do
  @moduledoc """
  HTTP API for the agent-to-agent relay messaging system.

  Routes (registered in router.ex under /api/v1/relay):
    GET    /relay/participants                    — list all participants with status
    POST   /relay/participants                    — register/update a participant
    GET    /relay/inbox/:agent_slug               — list unread messages for agent
    POST   /relay/messages                        — send a message
    POST   /relay/messages/:id/read               — mark a message read
    GET    /relay/threads/:thread_id              — list all messages in a thread
    GET    /relay/channels                        — list all channels
    POST   /relay/channels                        — create a channel
    POST   /relay/channels/:name/join             — join a channel
    POST   /relay/channels/:name/leave            — leave a channel
    POST   /relay/channels/:name/broadcast        — broadcast to a channel
  """

  use CanopyWeb, :controller

  alias Canopy.Agents.Relay

  action_fallback CanopyWeb.FallbackController

  # ---------------------------------------------------------------------------
  # Participants
  # ---------------------------------------------------------------------------

  @spec list_participants(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_participants(conn, _params) do
    participants = Relay.list_participants()
    json(conn, %{data: participants})
  end

  @spec register_participant(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def register_participant(conn, params) do
    agent_slug = Map.fetch!(params, "agent_slug")
    work_context = Map.get(params, "work_context", %{})

    with {:ok, participant} <- Relay.register_participant(agent_slug, work_context) do
      json(conn, participant)
    end
  end

  # ---------------------------------------------------------------------------
  # Inbox
  # ---------------------------------------------------------------------------

  @spec inbox(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def inbox(conn, %{"agent_slug" => agent_slug} = params) do
    opts = build_inbox_opts(params)
    messages = Relay.list_inbox(agent_slug, opts)
    json(conn, %{data: messages, count: length(messages)})
  end

  # ---------------------------------------------------------------------------
  # Messages
  # ---------------------------------------------------------------------------

  @spec send_message(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def send_message(conn, params) do
    with {:ok, message} <- Relay.send_message(params) do
      conn
      |> put_status(:created)
      |> json(message)
    end
  end

  @spec mark_read(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def mark_read(conn, %{"id" => id}) do
    with {:ok, message} <- Relay.mark_read(id) do
      json(conn, message)
    end
  end

  # ---------------------------------------------------------------------------
  # Threads
  # ---------------------------------------------------------------------------

  @spec list_thread(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_thread(conn, %{"thread_id" => thread_id}) do
    messages = Relay.list_thread(thread_id)
    json(conn, %{data: messages, count: length(messages)})
  end

  # ---------------------------------------------------------------------------
  # Channels
  # ---------------------------------------------------------------------------

  @spec list_channels(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_channels(conn, _params) do
    channels = Relay.list_channels()
    json(conn, %{data: channels})
  end

  @spec create_channel(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create_channel(conn, params) do
    name = Map.fetch!(params, "name")
    member_slugs = Map.get(params, "member_slugs", [])

    with {:ok, channel} <- Relay.create_channel(name, member_slugs) do
      conn
      |> put_status(:created)
      |> json(channel)
    end
  end

  @spec join_channel(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def join_channel(conn, %{"name" => channel_name} = params) do
    agent_slug = Map.fetch!(params, "agent_slug")

    with {:ok, channel} <- Relay.join_channel(channel_name, agent_slug) do
      json(conn, channel)
    end
  end

  @spec leave_channel(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def leave_channel(conn, %{"name" => channel_name} = params) do
    agent_slug = Map.fetch!(params, "agent_slug")

    with {:ok, channel} <- Relay.leave_channel(channel_name, agent_slug) do
      json(conn, channel)
    end
  end

  @spec broadcast_channel(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def broadcast_channel(conn, %{"name" => channel_name} = params) do
    from_slug = Map.fetch!(params, "from_agent_slug")
    content = Map.fetch!(params, "content")

    with {:ok, messages} <- Relay.broadcast(channel_name, from_slug, content) do
      json(conn, %{sent: length(messages), messages: messages})
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec build_inbox_opts(map()) :: keyword()
  defp build_inbox_opts(params) do
    opts = []

    opts =
      case params["limit"] do
        nil -> opts
        limit_str -> parse_limit(opts, limit_str)
      end

    opts
  end

  defp parse_limit(opts, limit_str) do
    case Integer.parse(limit_str) do
      {n, ""} when n > 0 -> Keyword.put(opts, :limit, n)
      _ -> opts
    end
  end
end
