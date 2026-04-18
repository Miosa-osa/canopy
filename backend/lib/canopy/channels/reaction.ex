defmodule Canopy.Channels.Reaction do
  @moduledoc """
  Ecto schema for the `channel_reactions` table.

  Reactions are immutable — no update changeset. The unique index on
  (message_id, actor_type, actor_id, emoji) prevents double-reactions.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias __MODULE__

  @type t :: %Reaction{
          id: Ecto.UUID.t() | nil,
          message_id: Ecto.UUID.t() | nil,
          actor_type: String.t() | nil,
          actor_id: String.t() | nil,
          emoji: String.t() | nil,
          inserted_at: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder,
           only: [
             :id,
             :message_id,
             :actor_type,
             :actor_id,
             :emoji,
             :inserted_at
           ]}

  schema "channel_reactions" do
    field :message_id, :binary_id
    field :actor_type, :string
    field :actor_id, :string
    field :emoji, :string

    field :inserted_at, :utc_datetime
  end

  @required [:message_id, :actor_type, :actor_id, :emoji]

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%Reaction{} = reaction, attrs) do
    reaction
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> validate_inclusion(:actor_type, ["user", "agent"])
    |> validate_length(:emoji, min: 1, max: 10)
    |> unique_constraint([:message_id, :actor_type, :actor_id, :emoji],
      name: :channel_reactions_unique_index,
      message: "actor has already reacted with this emoji"
    )
  end
end
