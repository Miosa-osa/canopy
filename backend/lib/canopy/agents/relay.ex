defmodule Canopy.Agents.Relay do
  @moduledoc """
  Context module for the agent-to-agent relay messaging system.

  Agents register as participants, send direct/channel/broadcast messages, and
  read their inbox. Real-time delivery fires via Phoenix.PubSub on:

  - Direct:    `relay:<to_agent_slug>`
  - Channel:   `relay:channel:<channel_name>`
  - Broadcast: `relay:broadcast`

  Priority ordering in `list_inbox/2`:
    urgent → high → normal → low (then oldest-first within each tier)
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Agents.Relay.Channel
  alias Canopy.Agents.Relay.Message
  alias Canopy.Agents.Relay.Participant
  alias Canopy.Repo

  @pubsub Canopy.PubSub

  # Priority sort order for inbox (lower = higher priority)
  @priority_order %{"urgent" => 0, "high" => 1, "normal" => 2, "low" => 3}

  # ---------------------------------------------------------------------------
  # Participants
  # ---------------------------------------------------------------------------

  @doc """
  Registers or updates a participant.

  Upserts on `agent_slug`. Sets `last_seen_at` to now and status to "online".
  """
  @spec register_participant(String.t(), map()) ::
          {:ok, Participant.t()} | {:error, Ecto.Changeset.t()}
  def register_participant(agent_slug, work_context \\ %{}) do
    attrs = %{
      agent_slug: agent_slug,
      status: "online",
      work_context: work_context,
      last_seen_at: DateTime.utc_now()
    }

    %Participant{}
    |> Participant.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:status, :work_context, :last_seen_at, :updated_at]},
      conflict_target: :agent_slug,
      returning: true
    )
  end

  @doc "Updates status for an existing participant."
  @spec update_status(String.t(), String.t()) ::
          {:ok, Participant.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_status(agent_slug, status) do
    with {:ok, participant} <- get_participant(agent_slug) do
      participant
      |> Participant.status_changeset(status)
      |> Repo.update()
    end
  end

  @doc "Updates work_context for an existing participant."
  @spec update_work_context(String.t(), map()) ::
          {:ok, Participant.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_work_context(agent_slug, context) when is_map(context) do
    with {:ok, participant} <- get_participant(agent_slug) do
      participant
      |> Participant.context_changeset(context)
      |> Repo.update()
    end
  end

  @doc "Lists all registered participants."
  @spec list_participants(keyword()) :: [Participant.t()]
  def list_participants(_opts \\ []) do
    Repo.all(from(p in Participant, order_by: [asc: p.agent_slug]))
  end

  # ---------------------------------------------------------------------------
  # Messages
  # ---------------------------------------------------------------------------

  @doc """
  Creates and delivers a relay message.

  Required attrs: `from_agent_slug`, `content`, `scope`.
  Optional: `to_agent_slug`, `thread_id`, `priority`, `metadata`.
  """
  @spec send_message(map()) :: {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
  def send_message(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> tap_broadcast()
  end

  @doc """
  Lists unread messages for `agent_slug`, priority-ordered then oldest-first.

  Opts:
    - `:limit` (integer, default 50)
  """
  @spec list_inbox(String.t(), keyword()) :: [Message.t()]
  def list_inbox(agent_slug, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    agent_slug
    |> inbox_query()
    |> Repo.all()
    |> Enum.sort_by(fn msg ->
      {Map.get(@priority_order, msg.priority, 99), msg.inserted_at}
    end)
    |> Enum.take(limit)
  end

  @doc "Marks a message as read."
  @spec mark_read(Ecto.UUID.t()) :: {:ok, Message.t()} | {:error, :not_found}
  def mark_read(message_id) do
    case Repo.get(Message, message_id) do
      nil -> {:error, :not_found}
      msg -> msg |> Message.mark_read_changeset(DateTime.utc_now()) |> Repo.update()
    end
  end

  @doc "Returns all messages in a thread, ordered oldest-first."
  @spec list_thread(String.t()) :: [Message.t()]
  def list_thread(thread_id) do
    Repo.all(
      from(m in Message,
        where: m.thread_id == ^thread_id,
        order_by: [asc: m.inserted_at]
      )
    )
  end

  # ---------------------------------------------------------------------------
  # Channels
  # ---------------------------------------------------------------------------

  @doc "Creates a named channel with an initial member list."
  @spec create_channel(String.t(), [String.t()]) ::
          {:ok, Channel.t()} | {:error, Ecto.Changeset.t()}
  def create_channel(name, member_slugs \\ []) do
    %Channel{}
    |> Channel.changeset(%{name: name, member_slugs: member_slugs})
    |> Repo.insert()
  end

  @doc "Adds `agent_slug` to a channel's member list (idempotent)."
  @spec join_channel(String.t(), String.t()) ::
          {:ok, Channel.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def join_channel(channel_name, agent_slug) do
    with {:ok, channel} <- get_channel(channel_name) do
      new_slugs = Enum.uniq([agent_slug | channel.member_slugs])
      channel |> Channel.members_changeset(new_slugs) |> Repo.update()
    end
  end

  @doc "Removes `agent_slug` from a channel's member list (idempotent)."
  @spec leave_channel(String.t(), String.t()) ::
          {:ok, Channel.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def leave_channel(channel_name, agent_slug) do
    with {:ok, channel} <- get_channel(channel_name) do
      new_slugs = Enum.reject(channel.member_slugs, &(&1 == agent_slug))
      channel |> Channel.members_changeset(new_slugs) |> Repo.update()
    end
  end

  @doc """
  Sends a broadcast message to all members of a channel.

  Persists one `Message` per member (scope: "channel") and broadcasts via
  PubSub on `relay:channel:<channel_name>`.
  """
  @spec broadcast(String.t(), String.t(), String.t()) ::
          {:ok, [Message.t()]} | {:error, :not_found}
  def broadcast(channel_name, from_slug, content) do
    with {:ok, channel} <- get_channel(channel_name) do
      messages =
        Enum.flat_map(channel.member_slugs, fn member_slug ->
          case send_message(%{
                 from_agent_slug: from_slug,
                 to_agent_slug: member_slug,
                 scope: "channel",
                 priority: "normal",
                 content: content,
                 metadata: %{"channel" => channel_name}
               }) do
            {:ok, msg} -> [msg]
            _ -> []
          end
        end)

      Phoenix.PubSub.broadcast(
        @pubsub,
        "relay:channel:#{channel_name}",
        {:relay_broadcast, %{from: from_slug, channel: channel_name, content: content}}
      )

      {:ok, messages}
    end
  end

  @doc "Lists all channels."
  @spec list_channels() :: [Channel.t()]
  def list_channels do
    Repo.all(from(c in Channel, order_by: [asc: c.name]))
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec get_participant(String.t()) :: {:ok, Participant.t()} | {:error, :not_found}
  defp get_participant(agent_slug) do
    case Repo.get_by(Participant, agent_slug: agent_slug) do
      nil -> {:error, :not_found}
      p -> {:ok, p}
    end
  end

  @spec get_channel(String.t()) :: {:ok, Channel.t()} | {:error, :not_found}
  defp get_channel(name) do
    case Repo.get_by(Channel, name: name) do
      nil -> {:error, :not_found}
      c -> {:ok, c}
    end
  end

  # Inbox: unread messages addressed to this agent (direct or channel-scoped)
  @spec inbox_query(String.t()) :: Ecto.Query.t()
  defp inbox_query(agent_slug) do
    from(m in Message,
      where: m.to_agent_slug == ^agent_slug and is_nil(m.read_at),
      order_by: [asc: m.inserted_at]
    )
  end

  # After insert, fire PubSub for real-time delivery
  @spec tap_broadcast({:ok, Message.t()} | {:error, term()}) ::
          {:ok, Message.t()} | {:error, term()}
  defp tap_broadcast({:ok, msg} = result) do
    topic =
      case msg.scope do
        "direct" when not is_nil(msg.to_agent_slug) ->
          "relay:#{msg.to_agent_slug}"

        "channel" ->
          channel = get_in(msg.metadata, ["channel"])
          if channel, do: "relay:channel:#{channel}", else: nil

        "broadcast" ->
          "relay:broadcast"

        _ ->
          nil
      end

    if topic do
      Phoenix.PubSub.broadcast(@pubsub, topic, {:relay_message, msg})
    end

    result
  end

  defp tap_broadcast(error), do: error
end
