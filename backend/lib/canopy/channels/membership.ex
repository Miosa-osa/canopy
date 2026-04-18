defmodule Canopy.Channels.Membership do
  @moduledoc """
  Sub-context for channel membership operations.

  Called via `Canopy.Channels` public API — do not call directly from outside
  the Channels boundary.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Channels.Member
  alias Canopy.Repo

  require Logger

  @doc """
  Adds an actor to a channel.

  `actor` is a map with `:actor_type` (`"user"` | `"agent"`) and `:actor_id`.
  Returns `{:ok, member}` or `{:error, changeset}` (including unique constraint
  when actor is already a member).
  """
  @spec add(Ecto.UUID.t(), map()) :: {:ok, Member.t()} | {:error, Ecto.Changeset.t()}
  def add(channel_id, %{actor_type: actor_type, actor_id: actor_id} = opts) do
    role = Map.get(opts, :role, "member")
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Member{}
    |> Member.changeset(%{
      channel_id: channel_id,
      actor_type: actor_type,
      actor_id: actor_id,
      role: role,
      joined_at: now
    })
    |> Repo.insert()
  end

  @doc """
  Removes an actor from a channel.

  Returns `{:ok, member}` or `{:error, :not_found}`.
  """
  @spec remove(Ecto.UUID.t(), map()) :: {:ok, Member.t()} | {:error, :not_found}
  def remove(channel_id, %{actor_type: actor_type, actor_id: actor_id}) do
    case find_member(channel_id, actor_type, actor_id) do
      nil -> {:error, :not_found}
      member -> Repo.delete(member)
    end
  end

  @doc "Returns all members of `channel_id`, ordered by joined_at asc."
  @spec list(Ecto.UUID.t()) :: [Member.t()]
  def list(channel_id) do
    Repo.all(
      from(m in Member,
        where: m.channel_id == ^channel_id,
        order_by: [asc: m.joined_at]
      )
    )
  end

  @doc "Returns all channels an actor belongs to. Returns list of channel_ids."
  @spec list_channel_ids_for(String.t(), String.t()) :: [Ecto.UUID.t()]
  def list_channel_ids_for(actor_type, actor_id) do
    Repo.all(
      from(m in Member,
        where: m.actor_type == ^actor_type and m.actor_id == ^actor_id,
        select: m.channel_id
      )
    )
  end

  @doc """
  Updates role and/or notifications_enabled for an actor in a channel.

  Returns `{:ok, member}` or `{:error, :not_found | changeset}`.
  """
  @spec update(Ecto.UUID.t(), map(), map()) ::
          {:ok, Member.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update(channel_id, %{actor_type: actor_type, actor_id: actor_id}, attrs) do
    case find_member(channel_id, actor_type, actor_id) do
      nil ->
        {:error, :not_found}

      member ->
        member
        |> Member.update_changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Updates last_read_at for an actor in a channel.

  Returns `{:ok, member}` or `{:error, :not_found}`.
  """
  @spec mark_read(Ecto.UUID.t(), map(), DateTime.t()) ::
          {:ok, Member.t()} | {:error, :not_found}
  def mark_read(channel_id, %{actor_type: actor_type, actor_id: actor_id}, up_to) do
    case find_member(channel_id, actor_type, actor_id) do
      nil ->
        {:error, :not_found}

      member ->
        member
        |> Member.read_changeset(up_to)
        |> Repo.update()
    end
  end

  @doc """
  Returns the count of messages in `channel_id` sent after the actor's
  `last_read_at`. Returns 0 if actor is not a member or has no last_read_at.
  """
  @spec unread_count(Ecto.UUID.t(), map()) :: non_neg_integer()
  def unread_count(channel_id, %{actor_type: actor_type, actor_id: actor_id}) do
    case find_member(channel_id, actor_type, actor_id) do
      nil ->
        0

      %Member{last_read_at: nil} ->
        count_all_messages(channel_id)

      %Member{last_read_at: last_read_at} ->
        count_messages_after(channel_id, last_read_at)
    end
  end

  @doc "Returns true if the actor is a member of the channel."
  @spec member?(Ecto.UUID.t(), String.t(), String.t()) :: boolean()
  def member?(channel_id, actor_type, actor_id) do
    find_member(channel_id, actor_type, actor_id) != nil
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec find_member(Ecto.UUID.t(), String.t(), String.t()) :: Member.t() | nil
  defp find_member(channel_id, actor_type, actor_id) do
    Repo.one(
      from(m in Member,
        where:
          m.channel_id == ^channel_id and
            m.actor_type == ^actor_type and
            m.actor_id == ^actor_id
      )
    )
  end

  @spec count_all_messages(Ecto.UUID.t()) :: non_neg_integer()
  defp count_all_messages(channel_id) do
    alias Canopy.Channels.Message

    Repo.one(
      from(msg in Message,
        where: msg.channel_id == ^channel_id and is_nil(msg.deleted_at),
        select: count(msg.id)
      )
    ) || 0
  end

  @spec count_messages_after(Ecto.UUID.t(), DateTime.t()) :: non_neg_integer()
  defp count_messages_after(channel_id, after_dt) do
    alias Canopy.Channels.Message

    Repo.one(
      from(msg in Message,
        where:
          msg.channel_id == ^channel_id and
            is_nil(msg.deleted_at) and
            msg.inserted_at > ^after_dt,
        select: count(msg.id)
      )
    ) || 0
  end
end
