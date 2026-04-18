defmodule Canopy.Channels.Member do
  @moduledoc """
  Ecto schema for the `channel_members` table.

  `actor_type` is either `"user"` (actor_id = UUID string) or
  `"agent"` (actor_id = slug string). Both share the same columns to support
  agents as first-class channel participants.

  Changesets:
  - `changeset/2` — add member with actor_type, actor_id, role.
  - `update_changeset/2` — update role and/or notifications_enabled.
  - `read_changeset/2` — update last_read_at.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias __MODULE__

  @type t :: %Member{
          id: Ecto.UUID.t() | nil,
          channel_id: Ecto.UUID.t() | nil,
          actor_type: String.t() | nil,
          actor_id: String.t() | nil,
          role: String.t() | nil,
          notifications_enabled: boolean() | nil,
          last_read_at: DateTime.t() | nil,
          joined_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder,
           only: [
             :id,
             :channel_id,
             :actor_type,
             :actor_id,
             :role,
             :notifications_enabled,
             :last_read_at,
             :joined_at,
             :inserted_at,
             :updated_at
           ]}

  schema "channel_members" do
    field :channel_id, :binary_id
    field :actor_type, :string
    field :actor_id, :string
    field :role, :string, default: "member"
    field :notifications_enabled, :boolean, default: true
    field :last_read_at, :utc_datetime
    field :joined_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @required [:channel_id, :actor_type, :actor_id, :role, :joined_at]
  @optional [:notifications_enabled, :last_read_at]

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%Member{} = member, attrs) do
    member
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:actor_type, ["user", "agent"])
    |> validate_inclusion(:role, ["member", "admin"])
    |> unique_constraint([:channel_id, :actor_type, :actor_id],
      name: :channel_members_channel_actor_unique_index,
      message: "actor is already a member of this channel"
    )
  end

  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(%Member{} = member, attrs) do
    member
    |> cast(attrs, [:role, :notifications_enabled])
    |> validate_inclusion(:role, ["member", "admin"])
  end

  @spec read_changeset(t(), DateTime.t()) :: Ecto.Changeset.t()
  def read_changeset(%Member{} = member, %DateTime{} = up_to) do
    change(member, last_read_at: DateTime.truncate(up_to, :second))
  end
end
