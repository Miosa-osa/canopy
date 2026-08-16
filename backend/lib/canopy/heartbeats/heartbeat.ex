defmodule Canopy.Heartbeats.Heartbeat do
  @moduledoc """
  Ecto schema for a heartbeat — an immutable event emitted by a live pty run.

  Heartbeats are a low-overhead telemetry log: one row per distinct event
  (with coalescence for high-frequency :output events within 500ms). The
  `preview` field carries the first 200 bytes of the event payload for
  activity-feed display without loading the full session transcript.

  Immutable log: no `updated_at`. Coalescence updates `byte_count` only.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @kinds ~w(output input error exit pause resume)

  @derive {Jason.Encoder,
           only: [
             :id,
             :session_id,
             :kind,
             :byte_count,
             :preview,
             :meta,
             :inserted_at
           ]}

  schema "heartbeats" do
    field :session_id, :binary_id
    field :kind, Ecto.Enum, values: [:output, :input, :error, :exit, :pause, :resume]
    field :byte_count, :integer, default: 0
    field :preview, :string
    field :meta, :map, default: %{}

    timestamps(updated_at: false)
  end

  @doc "Allowed kind values."
  @spec allowed_kinds() :: [String.t()]
  def allowed_kinds, do: @kinds

  @doc "Changeset for inserting a new heartbeat."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(heartbeat, attrs) do
    heartbeat
    |> cast(attrs, [:session_id, :kind, :byte_count, :preview, :meta])
    |> validate_required([:session_id, :kind])
    |> validate_number(:byte_count, greater_than_or_equal_to: 0)
  end
end
