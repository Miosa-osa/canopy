defmodule Canopy.Schedule.Run do
  @moduledoc """
  A single scheduled fire — its lifecycle from enqueue through completion.

  Each `Run` is the durable record of one tick of a `Spec`. The visual
  timeline view consumes these rows directly. Statuses move forward only:

      enqueued → running → completed
                        ↘ failed
                        ↘ cancelled
      enqueued → skipped_overlap        (overlap policy denied this tick)
      enqueued → late                   (fired after grace window)
      enqueued → missed                 (window passed without firing)

  `lateness_ms` is `fired_at − scheduled_at` (positive = late). A run is
  flagged "late" once it exceeds `Spec.grace_seconds`. A run is "missed"
  if `now > scheduled_at + grace_seconds` and it never fired.

  `attempt` increments only when the dispatcher retries — overlap-skipped
  ticks do not increment.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @statuses ~w(enqueued running completed failed skipped_overlap late missed cancelled)

  @derive {Jason.Encoder,
           only: [
             :id,
             :spec_id,
             :spec_slug,
             :agent_slug,
             :workspace_slug,
             :scheduled_at,
             :fired_at,
             :completed_at,
             :status,
             :lateness_ms,
             :duration_ms,
             :attempt,
             :session_id,
             :run_id,
             :payload,
             :error_class,
             :error_message,
             :inserted_at
           ]}

  schema "schedule_runs" do
    field :spec_id, :binary_id
    field :spec_slug, :string
    field :agent_slug, :string
    field :workspace_slug, :string

    field :scheduled_at, :utc_datetime_usec
    field :fired_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec

    field :status, :string, default: "enqueued"
    field :lateness_ms, :integer
    field :duration_ms, :integer
    field :attempt, :integer, default: 1

    field :session_id, :binary_id
    field :run_id, :binary_id
    field :payload, :map, default: %{}
    field :error_class, :string
    field :error_message, :string

    timestamps(updated_at: false)
  end

  @required ~w(spec_id scheduled_at)a
  @optional ~w(spec_slug agent_slug workspace_slug fired_at completed_at status
               lateness_ms duration_ms attempt session_id run_id payload
               error_class error_message)a

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:attempt, greater_than_or_equal_to: 1)
  end

  def statuses, do: @statuses
end
