defmodule Canopy.Agents.Relay.Participant do
  @moduledoc """
  Ecto schema representing an agent's presence in the relay system.

  A participant is created via upsert when an agent registers itself with a
  work context. `status` tracks availability; `work_context` holds a free-form
  map describing what the agent is currently doing.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @derive {Jason.Encoder,
           only: [
             :id,
             :agent_slug,
             :status,
             :work_context,
             :last_seen_at,
             :inserted_at,
             :updated_at
           ]}

  schema "relay_participants" do
    field :agent_slug, :string
    field :status, :string, default: "online"
    field :work_context, :map, default: %{}
    field :last_seen_at, :utc_datetime_usec

    timestamps()
  end

  @valid_statuses ~w(online busy offline)

  @required ~w(agent_slug)a
  @optional ~w(status work_context last_seen_at)a

  @doc "Changeset for registering or updating a participant."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(participant, attrs) do
    participant
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:agent_slug, min: 1, max: 128)
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint(:agent_slug)
  end

  @doc "Changeset for updating status only."
  @spec status_changeset(%__MODULE__{}, String.t()) :: Ecto.Changeset.t()
  def status_changeset(participant, status) do
    participant
    |> cast(%{status: status, last_seen_at: DateTime.utc_now()}, [:status, :last_seen_at])
    |> validate_inclusion(:status, @valid_statuses)
  end

  @doc "Changeset for updating work context only."
  @spec context_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def context_changeset(participant, context) do
    participant
    |> cast(%{work_context: context, last_seen_at: DateTime.utc_now()}, [
      :work_context,
      :last_seen_at
    ])
  end
end
