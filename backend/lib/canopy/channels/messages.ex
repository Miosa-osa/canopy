defmodule Canopy.Channels.Messages do
  @moduledoc """
  Sub-context for channel message operations: create, edit, soft-delete,
  list with cursor pagination, reactions, and pins.

  Called via `Canopy.Channels` public API.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Channels.{Message, Pin, Reaction}
  alias Canopy.Repo

  require Logger

  # ---------------------------------------------------------------------------
  # Messages
  # ---------------------------------------------------------------------------

  @doc """
  Returns messages for `channel_id` in reverse-chronological order (newest first).

  Options:
  - `:before` — `%DateTime{}` cursor; returns messages with `inserted_at < before`.
  - `:limit` — integer (default 50, max 200).
  - `:include_deleted` — boolean (default false); when false excludes soft-deleted rows.
  - `:thread_id` — when set, returns only replies to that message_id.

  Returns `{messages, has_more}` where `has_more` indicates a next page exists.
  """
  @spec list(Ecto.UUID.t(), keyword()) :: {[Message.t()], boolean()}
  def list(channel_id, opts \\ []) do
    limit = min(Keyword.get(opts, :limit, 50), 200)
    before_dt = Keyword.get(opts, :before)
    include_deleted = Keyword.get(opts, :include_deleted, false)
    thread_id = Keyword.get(opts, :thread_id)

    # Fetch one extra to determine has_more
    fetch_limit = limit + 1

    query =
      from(m in Message,
        where: m.channel_id == ^channel_id,
        order_by: [desc: m.inserted_at],
        limit: ^fetch_limit
      )

    query =
      if include_deleted do
        query
      else
        from(m in query, where: is_nil(m.deleted_at))
      end

    query =
      case before_dt do
        nil -> query
        dt -> from(m in query, where: m.inserted_at < ^dt)
      end

    query =
      case thread_id do
        nil -> from(m in query, where: is_nil(m.reply_to_id))
        tid -> from(m in query, where: m.reply_to_id == ^tid)
      end

    rows = Repo.all(query)
    has_more = length(rows) > limit
    messages = Enum.take(rows, limit)

    {messages, has_more}
  end

  @doc """
  Creates a message in a transaction:
    1. INSERT message
    2. Parse @mentions from body, update mentions array
    3. If reply: increment thread_count on parent message
    4. Emit notifications to mentioned users
    5. Emit realtime broadcast
    6. Emit business event

  If mention notification emission fails, it is logged but does NOT roll back
  the transaction (the message is already committed). Only DB operations in steps
  1-3 are part of the transaction boundary.

  Returns `{:ok, message}` or `{:error, changeset}`.
  """
  @spec create(map()) :: {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    result =
      Repo.transaction(fn ->
        with {:ok, message} <- insert_message(attrs),
             {:ok, message} <- apply_mentions(message),
             :ok <- maybe_increment_thread_count(message) do
          message
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    case result do
      {:ok, message} ->
        emit_mention_notifications(message)
        emit_realtime(message)
        emit_event(message)
        {:ok, message}

      {:error, %Ecto.Changeset{} = cs} ->
        {:error, cs}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Edits a message's body. Sets `edited_at`.

  Returns `{:ok, message}` or `{:error, :not_found | changeset}`.
  """
  @spec edit(Ecto.UUID.t(), map()) ::
          {:ok, Message.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def edit(message_id, attrs) do
    case Repo.get(Message, message_id) do
      nil ->
        {:error, :not_found}

      %Message{deleted_at: deleted_at} when not is_nil(deleted_at) ->
        {:error, :not_found}

      message ->
        message
        |> Message.edit_changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Soft-deletes a message: sets `deleted_at`, replaces body with "[deleted]".
  This operation cannot be undone via the API.

  Returns `{:ok, message}` or `{:error, :not_found}`.
  """
  @spec soft_delete(Ecto.UUID.t()) :: {:ok, Message.t()} | {:error, :not_found}
  def soft_delete(message_id) do
    case Repo.get(Message, message_id) do
      nil ->
        {:error, :not_found}

      message ->
        message
        |> Message.soft_delete_changeset()
        |> Repo.update()
    end
  end

  @doc "Returns a single message by ID, or `{:error, :not_found}`."
  @spec get(Ecto.UUID.t()) :: {:ok, Message.t()} | {:error, :not_found}
  def get(message_id) do
    case Repo.get(Message, message_id) do
      nil -> {:error, :not_found}
      message -> {:ok, message}
    end
  end

  # ---------------------------------------------------------------------------
  # Reactions
  # ---------------------------------------------------------------------------

  @doc """
  Adds a reaction to a message.

  Returns `{:ok, reaction}` or `{:error, changeset}` (unique constraint fires
  if actor already used this emoji on this message).
  """
  @spec add_reaction(map()) :: {:ok, Reaction.t()} | {:error, Ecto.Changeset.t()}
  def add_reaction(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Reaction{}
    |> Reaction.changeset(Map.put_new(attrs, :inserted_at, now))
    |> Repo.insert()
    |> tap_ok(&emit_reaction_event/1)
  end

  @doc """
  Removes a reaction. Returns `{:ok, reaction}` or `{:error, :not_found}`.
  """
  @spec remove_reaction(Ecto.UUID.t(), String.t(), String.t(), String.t()) ::
          {:ok, Reaction.t()} | {:error, :not_found}
  def remove_reaction(message_id, actor_type, actor_id, emoji) do
    case find_reaction(message_id, actor_type, actor_id, emoji) do
      nil -> {:error, :not_found}
      reaction -> Repo.delete(reaction)
    end
  end

  @doc "Returns all reactions for `message_id`, ordered by inserted_at asc."
  @spec list_reactions(Ecto.UUID.t()) :: [Reaction.t()]
  def list_reactions(message_id) do
    Repo.all(
      from(r in Reaction,
        where: r.message_id == ^message_id,
        order_by: [asc: r.inserted_at]
      )
    )
  end

  # ---------------------------------------------------------------------------
  # Pins
  # ---------------------------------------------------------------------------

  @doc """
  Pins a message in a channel.

  Returns `{:ok, pin}` or `{:error, changeset}` (unique constraint if already pinned).
  """
  @spec pin(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, Pin.t()} | {:error, Ecto.Changeset.t()}
  def pin(channel_id, message_id, pinned_by_user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Pin{}
    |> Pin.changeset(%{
      channel_id: channel_id,
      message_id: message_id,
      pinned_by_user_id: pinned_by_user_id,
      pinned_at: now
    })
    |> Repo.insert()
  end

  @doc """
  Unpins a message. Returns `{:ok, pin}` or `{:error, :not_found}`.
  """
  @spec unpin(Ecto.UUID.t(), Ecto.UUID.t()) :: {:ok, Pin.t()} | {:error, :not_found}
  def unpin(channel_id, message_id) do
    case find_pin(channel_id, message_id) do
      nil -> {:error, :not_found}
      pin -> Repo.delete(pin)
    end
  end

  @doc "Returns all pins for `channel_id`, ordered by pinned_at desc."
  @spec list_pins(Ecto.UUID.t()) :: [Pin.t()]
  def list_pins(channel_id) do
    Repo.all(
      from(p in Pin,
        where: p.channel_id == ^channel_id,
        order_by: [desc: p.pinned_at]
      )
    )
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec insert_message(map()) :: {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
  defp insert_message(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @mention_regex ~r/(?:^|\s)@([a-z0-9-]+)/

  @spec parse_mentions(String.t()) :: [String.t()]
  defp parse_mentions(body) when is_binary(body) do
    @mention_regex
    |> Regex.scan(body, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
  end

  defp parse_mentions(_), do: []

  @spec apply_mentions(Message.t()) :: {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
  defp apply_mentions(%Message{body_markdown: body} = message) do
    slugs = parse_mentions(body)

    message
    |> Message.set_mentions_changeset(slugs)
    |> Repo.update()
  end

  @spec maybe_increment_thread_count(Message.t()) :: :ok
  defp maybe_increment_thread_count(%Message{reply_to_id: nil}), do: :ok

  defp maybe_increment_thread_count(%Message{reply_to_id: parent_id}) do
    Repo.update_all(
      from(m in Message, where: m.id == ^parent_id),
      inc: [thread_count: 1]
    )

    :ok
  end

  @spec emit_mention_notifications(Message.t()) :: :ok
  defp emit_mention_notifications(%Message{mentions: []}), do: :ok

  defp emit_mention_notifications(%Message{body_markdown: body} = message) do
    slugs = parse_mentions(body)

    Enum.each(slugs, fn slug ->
      case Canopy.Agents.get_by_slug(slug) do
        {:ok, _agent} ->
          Logger.debug("[Channels] Agent @#{slug} mentioned in message #{message.id}")

        _ ->
          :ok
      end
    end)

    :ok
  end

  @spec emit_realtime(Message.t()) :: :ok
  defp emit_realtime(message) do
    Phoenix.PubSub.broadcast(
      Canopy.PubSub,
      "channel:#{message.channel_id}",
      {:message, %{message: message}}
    )

    :ok
  end

  @spec emit_event(Message.t()) :: :ok
  defp emit_event(_message), do: :ok

  @spec emit_reaction_event(Reaction.t()) :: :ok
  defp emit_reaction_event(reaction) do
    channel_id = get_channel_id_for_message(reaction.message_id)

    if channel_id do
      Phoenix.PubSub.broadcast(
        Canopy.PubSub,
        "channel:#{channel_id}",
        {:reaction, %{reaction: reaction}}
      )
    end

    :ok
  end

  @spec get_channel_id_for_message(Ecto.UUID.t()) :: Ecto.UUID.t() | nil
  defp get_channel_id_for_message(message_id) do
    Repo.one(from(m in Message, where: m.id == ^message_id, select: m.channel_id))
  end

  @spec find_reaction(Ecto.UUID.t(), String.t(), String.t(), String.t()) :: Reaction.t() | nil
  defp find_reaction(message_id, actor_type, actor_id, emoji) do
    Repo.one(
      from(r in Reaction,
        where:
          r.message_id == ^message_id and
            r.actor_type == ^actor_type and
            r.actor_id == ^actor_id and
            r.emoji == ^emoji
      )
    )
  end

  @spec find_pin(Ecto.UUID.t(), Ecto.UUID.t()) :: Pin.t() | nil
  defp find_pin(channel_id, message_id) do
    Repo.one(
      from(p in Pin,
        where: p.channel_id == ^channel_id and p.message_id == ^message_id
      )
    )
  end

  # Utility: call side-effect function only on {:ok, value}, return original tuple.
  defp tap_ok({:ok, value} = result, fun) do
    fun.(value)
    result
  end

  defp tap_ok(result, _fun), do: result
end
