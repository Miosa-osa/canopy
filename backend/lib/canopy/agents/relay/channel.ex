defmodule Canopy.Agents.Relay.Channel do
  @moduledoc """
  Ecto schema for a named relay channel agents can join.

  `member_slugs` is a PostgreSQL text array holding the agent slugs of all
  current members. Membership is managed via `join_channel/2` and
  `leave_channel/2` in the relay context.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :description,
             :member_slugs,
             :inserted_at,
             :updated_at
           ]}

  schema "relay_channels" do
    field :name, :string
    field :description, :string
    field :member_slugs, {:array, :string}, default: []

    timestamps()
  end

  @required ~w(name)a
  @optional ~w(description member_slugs)a

  @doc "Changeset for creating a channel."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:name, min: 1, max: 128)
    |> validate_format(:name, ~r/\A[a-z0-9][a-z0-9\-_]*\z/)
    |> unique_constraint(:name)
  end

  @doc "Changeset for updating member list."
  @spec members_changeset(%__MODULE__{}, [String.t()]) :: Ecto.Changeset.t()
  def members_changeset(channel, slugs) when is_list(slugs) do
    channel
    |> cast(%{member_slugs: slugs}, [:member_slugs])
  end
end
