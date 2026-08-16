defmodule Canopy.Agents.Relay.Message do
  @moduledoc """
  Ecto schema for an agent-to-agent relay message.

  Messages can be direct (to a specific agent), channel-scoped, or broadcast
  (to_agent_slug is nil). `thread_id` groups related messages into a
  conversation. `priority` determines inbox ordering.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @derive {Jason.Encoder,
           only: [
             :id,
             :thread_id,
             :from_agent_slug,
             :to_agent_slug,
             :scope,
             :priority,
             :content,
             :metadata,
             :read_at,
             :inserted_at,
             :updated_at
           ]}

  schema "relay_messages" do
    field :thread_id, :string
    field :from_agent_slug, :string
    # nil means broadcast
    field :to_agent_slug, :string
    field :scope, :string, default: "direct"
    field :priority, :string, default: "normal"
    field :content, :string
    field :metadata, :map, default: %{}
    field :read_at, :utc_datetime_usec

    timestamps()
  end

  @valid_scopes ~w(direct channel broadcast)
  @valid_priorities ~w(low normal high urgent)

  @required ~w(from_agent_slug content scope priority)a
  @optional ~w(thread_id to_agent_slug metadata read_at)a

  @doc "Changeset for creating a new relay message."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(message, attrs) do
    message
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:scope, @valid_scopes)
    |> validate_inclusion(:priority, @valid_priorities)
    |> validate_length(:content, min: 1)
    |> maybe_set_thread_id()
  end

  @doc "Changeset for marking a message read."
  @spec mark_read_changeset(%__MODULE__{}, DateTime.t()) :: Ecto.Changeset.t()
  def mark_read_changeset(message, read_at) do
    change(message, read_at: read_at)
  end

  # Auto-assign a thread_id if none provided
  defp maybe_set_thread_id(changeset) do
    case get_field(changeset, :thread_id) do
      nil ->
        thread_id = Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
        put_change(changeset, :thread_id, thread_id)

      _ ->
        changeset
    end
  end
end
