defmodule Canopy.Channels do
  @moduledoc """
  Public API for the Channels module.

  Channels are team messaging spaces where both users and agents are first-class
  members. Visibility ("public" | "private") controls read access: private channels
  are only visible to their members.

  ## Sub-contexts

  - `Canopy.Channels.Membership` — member add/remove/list/read-receipts/unread counts
  - `Canopy.Channels.Messages` — message CRUD + reactions + pins + threads

  ## Visibility enforcement

  `list/1` and `get/1` accept `current_actor` (a map with `:actor_type` and
  `:actor_id`, or `nil` for unauthenticated). Private channels are filtered out
  unless the actor is a member.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Channels.{Channel, Membership, Messages}
  alias Canopy.Repo

  require Logger

  # ---------------------------------------------------------------------------
  # Channel CRUD
  # ---------------------------------------------------------------------------

  @doc """
  Lists channels, optionally filtered.

  Options:
  - `:workspace_slug` — filter to a specific workspace.
  - `:current_actor` — `%{actor_type: t, actor_id: id}` or `nil`.
    nil or unauthenticated: see only public channels.
    authenticated: see public + private channels where actor is a member.
  - `:include_archived` — boolean (default false).
  """
  @spec list(keyword()) :: {:ok, [Channel.t()]}
  def list(opts \\ []) do
    workspace_slug = Keyword.get(opts, :workspace_slug)
    current_actor = Keyword.get(opts, :current_actor)
    include_archived = Keyword.get(opts, :include_archived, false)

    query = from(c in Channel, order_by: [asc: c.name])

    query =
      if include_archived do
        query
      else
        from(c in query, where: is_nil(c.archived_at))
      end

    query =
      case workspace_slug do
        nil -> query
        slug -> from(c in query, where: c.workspace_slug == ^slug)
      end

    query = apply_visibility_filter(query, current_actor)

    {:ok, Repo.all(query)}
  end

  @doc """
  Creates a channel.

  Returns `{:ok, channel}` or `{:error, changeset}`.
  """
  @spec create(map()) :: {:ok, Channel.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a channel by ID or slug.

  Enforces visibility: private channels return `{:error, :not_found}` when
  `current_actor` is nil or not a member.

  Returns `{:ok, channel}` or `{:error, :not_found}`.
  """
  @spec get(String.t(), keyword()) :: {:ok, Channel.t()} | {:error, :not_found}
  def get(id_or_slug, opts \\ []) do
    current_actor = Keyword.get(opts, :current_actor)

    channel =
      if is_uuid?(id_or_slug) do
        Repo.get(Channel, id_or_slug)
      else
        Repo.get_by(Channel, slug: id_or_slug)
      end

    case channel do
      nil ->
        {:error, :not_found}

      %Channel{visibility: "private"} = ch ->
        if can_see_private?(ch, current_actor) do
          {:ok, ch}
        else
          {:error, :not_found}
        end

      ch ->
        {:ok, ch}
    end
  end

  @doc """
  Updates a channel's attributes.

  Returns `{:ok, channel}` or `{:error, :not_found | changeset}`.
  """
  @spec update(String.t(), map()) ::
          {:ok, Channel.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update(id_or_slug, attrs) do
    with {:ok, channel} <- get(id_or_slug) do
      channel
      |> Channel.changeset(attrs)
      |> Repo.update()
    end
  end

  @doc """
  Archives a channel (soft-delete via archived_at).

  Returns `{:ok, channel}` or `{:error, :not_found}`.
  """
  @spec archive(String.t()) :: {:ok, Channel.t()} | {:error, :not_found}
  def archive(id_or_slug) do
    with {:ok, channel} <- get(id_or_slug) do
      channel
      |> Channel.archive_changeset()
      |> Repo.update()
    end
  end

  # ---------------------------------------------------------------------------
  # Membership delegation
  # ---------------------------------------------------------------------------

  @doc "Adds an actor to a channel. See `Canopy.Channels.Membership.add/2`."
  @spec add_member(Ecto.UUID.t(), map()) :: {:ok, term()} | {:error, term()}
  def add_member(channel_id, actor) do
    result = Membership.add(channel_id, actor)

    if match?({:ok, _}, result) do
      Phoenix.PubSub.broadcast(
        Canopy.PubSub,
        "channel:#{channel_id}",
        {:member_joined, %{actor: actor}}
      )
    end

    result
  end

  @doc "Removes an actor from a channel. See `Canopy.Channels.Membership.remove/2`."
  @spec remove_member(Ecto.UUID.t(), map()) :: {:ok, term()} | {:error, :not_found}
  defdelegate remove_member(channel_id, actor), to: Membership, as: :remove

  @doc "Returns all members of a channel."
  @spec list_members(Ecto.UUID.t()) :: [term()]
  defdelegate list_members(channel_id), to: Membership, as: :list

  @doc "Returns all channels for an actor."
  @spec list_channels_for(map()) :: {:ok, [Channel.t()]}
  def list_channels_for(%{actor_type: actor_type, actor_id: actor_id}) do
    channel_ids = Membership.list_channel_ids_for(actor_type, actor_id)
    channels = Repo.all(from(c in Channel, where: c.id in ^channel_ids, order_by: [asc: c.name]))
    {:ok, channels}
  end

  @doc "Updates role/notifications_enabled for an actor in a channel."
  @spec update_member(Ecto.UUID.t(), map(), map()) :: {:ok, term()} | {:error, term()}
  defdelegate update_member(channel_id, actor, attrs), to: Membership, as: :update

  @doc "Marks read up to a timestamp for an actor."
  @spec mark_read(Ecto.UUID.t(), map(), DateTime.t()) :: {:ok, term()} | {:error, :not_found}
  defdelegate mark_read(channel_id, actor, up_to), to: Membership

  @doc "Returns the unread message count for an actor in a channel."
  @spec unread_count(Ecto.UUID.t(), map()) :: non_neg_integer()
  defdelegate unread_count(channel_id, actor), to: Membership

  # ---------------------------------------------------------------------------
  # Messages delegation
  # ---------------------------------------------------------------------------

  @doc "Lists messages in a channel with cursor pagination."
  @spec list_messages(Ecto.UUID.t(), keyword()) :: {[term()], boolean()}
  defdelegate list_messages(channel_id, opts \\ []), to: Messages, as: :list

  @doc "Creates a message (transactional: INSERT + mentions + thread_count + notifications)."
  @spec create_message(map()) :: {:ok, term()} | {:error, term()}
  defdelegate create_message(attrs), to: Messages, as: :create

  @doc "Edits a message body."
  @spec edit_message(Ecto.UUID.t(), map()) :: {:ok, term()} | {:error, term()}
  defdelegate edit_message(message_id, attrs), to: Messages, as: :edit

  @doc "Soft-deletes a message (sets deleted_at, body → '[deleted]'). Irreversible."
  @spec soft_delete_message(Ecto.UUID.t()) :: {:ok, term()} | {:error, :not_found}
  defdelegate soft_delete_message(message_id), to: Messages, as: :soft_delete

  @doc "Gets a message by ID."
  @spec get_message(Ecto.UUID.t()) :: {:ok, term()} | {:error, :not_found}
  defdelegate get_message(message_id), to: Messages, as: :get

  @doc "Adds a reaction to a message."
  @spec add_reaction(map()) :: {:ok, term()} | {:error, term()}
  defdelegate add_reaction(attrs), to: Messages

  @doc "Removes a reaction."
  @spec remove_reaction(Ecto.UUID.t(), String.t(), String.t(), String.t()) ::
          {:ok, term()} | {:error, :not_found}
  defdelegate remove_reaction(message_id, actor_type, actor_id, emoji), to: Messages

  @doc "Lists reactions for a message."
  @spec list_reactions(Ecto.UUID.t()) :: [term()]
  defdelegate list_reactions(message_id), to: Messages

  @doc "Pins a message in a channel."
  @spec pin_message(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, term()} | {:error, term()}
  defdelegate pin_message(channel_id, message_id, pinned_by_user_id), to: Messages, as: :pin

  @doc "Unpins a message."
  @spec unpin_message(Ecto.UUID.t(), Ecto.UUID.t()) :: {:ok, term()} | {:error, :not_found}
  defdelegate unpin_message(channel_id, message_id), to: Messages, as: :unpin

  @doc "Lists pins for a channel."
  @spec list_pins(Ecto.UUID.t()) :: [term()]
  defdelegate list_pins(channel_id), to: Messages

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec apply_visibility_filter(Ecto.Query.t(), map() | nil) :: Ecto.Query.t()
  defp apply_visibility_filter(query, nil) do
    from(c in query, where: c.visibility == "public")
  end

  defp apply_visibility_filter(query, %{actor_type: actor_type, actor_id: actor_id}) do
    alias Canopy.Channels.Member

    from(c in query,
      where:
        c.visibility == "public" or
          fragment(
            "EXISTS (SELECT 1 FROM channel_members WHERE channel_id = ? AND actor_type = ? AND actor_id = ?)",
            c.id,
            ^actor_type,
            ^actor_id
          )
    )

    # Suppress unused alias warning — Member schema is referenced by table name above.
    _ = Member
    query
  end

  defp apply_visibility_filter(query, _), do: from(c in query, where: c.visibility == "public")

  @spec can_see_private?(Channel.t(), map() | nil) :: boolean()
  defp can_see_private?(_channel, nil), do: false

  defp can_see_private?(channel, %{actor_type: actor_type, actor_id: actor_id}) do
    Membership.member?(channel.id, actor_type, actor_id)
  end

  defp can_see_private?(_channel, _), do: false

  @spec is_uuid?(String.t()) :: boolean()
  defp is_uuid?(str) do
    case Ecto.UUID.cast(str) do
      {:ok, _} -> true
      :error -> false
    end
  end
end
