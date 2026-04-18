defmodule Canopy.Channels.Pin do
  @moduledoc """
  Ecto schema for the `channel_pins` table.

  A message can only be pinned once per channel. The unique index on
  (channel_id, message_id) enforces this constraint at the DB level.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias __MODULE__

  @type t :: %Pin{
          id: Ecto.UUID.t() | nil,
          channel_id: Ecto.UUID.t() | nil,
          message_id: Ecto.UUID.t() | nil,
          pinned_by_user_id: Ecto.UUID.t() | nil,
          pinned_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder,
           only: [
             :id,
             :channel_id,
             :message_id,
             :pinned_by_user_id,
             :pinned_at,
             :inserted_at
           ]}

  schema "channel_pins" do
    field :channel_id, :binary_id
    field :message_id, :binary_id
    field :pinned_by_user_id, :binary_id
    field :pinned_at, :utc_datetime

    field :inserted_at, :utc_datetime
  end

  @required [:channel_id, :message_id, :pinned_by_user_id, :pinned_at]

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%Pin{} = pin, attrs) do
    pin
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> unique_constraint([:channel_id, :message_id],
      name: :channel_pins_unique_index,
      message: "message is already pinned in this channel"
    )
  end
end
