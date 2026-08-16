defmodule Canopy.Schedule.Alert do
  @moduledoc """
  Schedule alert (incident) — a grouped failure record.

  Failed runs are clustered into a single Alert per outage rather than one
  notification per failed tick. An alert opens when the first failure of a
  category arrives, accumulates `failure_count` and `related_run_ids` while
  the same root cause keeps occurring, and closes when the spec returns to
  health (or when a human acknowledges, for circuit-breaker incidents).

  ## Categories

  - `"miss"` — a fire window passed without a run firing (Spec eval missed)
  - `"late"` — a run fired after its `grace_seconds` window
  - `"failure"` — a run errored mid-execution
  - `"circuit_breaker"` — `consecutive_failures >= failure_threshold`; spec
    auto-paused, requires human acknowledgment to resume
  - `"overlap"` — repeated overlap-policy invocations indicate misconfigured
    cron period
  - `"calendar_sync"` — incremental sync against an external calendar failed
  - `"schedule_conflict"` — agent heartbeat collides with a human meeting
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @categories ~w(miss late failure circuit_breaker overlap calendar_sync schedule_conflict)
  @severities ~w(info medium high critical)
  @statuses ~w(open acknowledged closed)

  @derive {Jason.Encoder,
           only: [
             :id,
             :slug,
             :spec_id,
             :spec_slug,
             :category,
             :severity,
             :status,
             :summary,
             :detail,
             :first_seen_at,
             :last_seen_at,
             :closed_at,
             :acknowledged_at,
             :acknowledged_by,
             :failure_count,
             :related_run_ids,
             :workspace_slug,
             :resolution_note,
             :inserted_at,
             :updated_at
           ]}

  schema "schedule_alerts" do
    field :slug, :string
    field :spec_id, :binary_id
    field :spec_slug, :string

    field :category, :string
    field :severity, :string, default: "medium"
    field :status, :string, default: "open"

    field :summary, :string
    field :detail, :string

    field :first_seen_at, :utc_datetime_usec
    field :last_seen_at, :utc_datetime_usec
    field :closed_at, :utc_datetime_usec
    field :acknowledged_at, :utc_datetime_usec
    field :acknowledged_by, :string

    field :failure_count, :integer, default: 1
    field :related_run_ids, {:array, :binary_id}, default: []

    field :workspace_slug, :string
    field :resolution_note, :string

    timestamps()
  end

  @required ~w(slug category summary first_seen_at last_seen_at)a
  @optional ~w(spec_id spec_slug severity status detail closed_at acknowledged_at
               acknowledged_by failure_count related_run_ids workspace_slug
               resolution_note)a

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:slug, max: 128)
    |> validate_length(:summary, max: 512)
    |> validate_inclusion(:category, @categories)
    |> validate_inclusion(:severity, @severities)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:failure_count, greater_than_or_equal_to: 1)
    |> unique_constraint(:slug)
  end

  def categories, do: @categories
  def severities, do: @severities
  def statuses, do: @statuses
end
