defmodule Canopy.Schedule.Spec do
  @moduledoc """
  Schedule spec — the declarative description of when something should fire.

  A `Spec` is the union of multiple time sources minus an exclusion list:

      crons     ∪  intervals  ∪  calendars     −     skips

  Stored as a single jsonb document under `model`. The shape is intentionally
  open so we can evolve without migrations. Resolved policy fields are also
  surfaced as columns for cheap querying (timezone, overlap_policy, jitter,
  grace_seconds, failure_threshold).

  ## Statuses

  - `"active"` — eligible for firing on each evaluator tick
  - `"paused"` — fires are suppressed (manual pause or circuit-breaker)
  - `"archived"` — soft-deleted, retained for run history

  ## Overlap policies (Temporal-style)

  - `"skip"` — if previous run still in flight, drop this tick
  - `"buffer_one"` — queue the tick to fire when the running one finishes
  - `"cancel_other"` — cancel the running run, fire this one
  - `"terminate_other"` — hard-stop the running run, fire this one

  The runtime (`Canopy.Schedule.Dispatcher`) is the only consumer of these
  policies; the schema only validates the value.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @overlap_policies ~w(skip buffer_one cancel_other terminate_other)
  @statuses ~w(active paused archived)

  @derive {Jason.Encoder,
           only: [
             :id,
             :slug,
             :name,
             :description,
             :agent_id,
             :agent_slug,
             :workspace_slug,
             :model,
             :timezone,
             :overlap_policy,
             :jitter_seconds,
             :grace_seconds,
             :failure_threshold,
             :concurrency_key,
             :start_at,
             :end_at,
             :next_fire_at,
             :last_fire_at,
             :status,
             :paused_reason,
             :paused_at,
             :consecutive_failures,
             :run_count,
             :error_count,
             :inserted_at,
             :updated_at
           ]}

  schema "schedule_specs" do
    field :slug, :string
    field :name, :string
    field :description, :string
    field :agent_id, :binary_id
    field :agent_slug, :string
    field :workspace_slug, :string

    # ScheduleSpec model — the canonical declaration. Open jsonb shape:
    #   %{
    #     "crons" => ["0 9 * * 1-5", ...],
    #     "intervals" => [%{"every_seconds" => 300, "phase" => "00:00:30"}],
    #     "calendars" => [%{"weekday" => "mon", "hour" => 9, "minute" => 0}],
    #     "skips" => [%{"date" => "2026-12-25"}, ...]
    #   }
    field :model, :map, default: %{}

    field :timezone, :string, default: "UTC"
    field :overlap_policy, :string, default: "skip"
    field :jitter_seconds, :integer, default: 0
    field :grace_seconds, :integer, default: 0
    field :failure_threshold, :integer, default: 5
    field :concurrency_key, :string

    field :start_at, :utc_datetime_usec
    field :end_at, :utc_datetime_usec
    field :next_fire_at, :utc_datetime_usec
    field :last_fire_at, :utc_datetime_usec

    field :status, :string, default: "active"
    field :paused_reason, :string
    field :paused_at, :utc_datetime_usec

    field :consecutive_failures, :integer, default: 0
    field :run_count, :integer, default: 0
    field :error_count, :integer, default: 0

    timestamps()
  end

  @required ~w(slug name)a
  @optional ~w(description agent_id agent_slug workspace_slug model timezone
               overlap_policy jitter_seconds grace_seconds failure_threshold
               concurrency_key start_at end_at next_fire_at last_fire_at
               status paused_reason paused_at consecutive_failures run_count
               error_count)a

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:slug, max: 128)
    |> validate_length(:name, max: 256)
    |> validate_length(:timezone, max: 64)
    |> validate_inclusion(:overlap_policy, @overlap_policies)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:jitter_seconds, greater_than_or_equal_to: 0, less_than_or_equal_to: 3600)
    |> validate_number(:grace_seconds, greater_than_or_equal_to: 0, less_than_or_equal_to: 86_400)
    |> validate_number(:failure_threshold, greater_than_or_equal_to: 1, less_than_or_equal_to: 100)
    |> validate_number(:consecutive_failures, greater_than_or_equal_to: 0)
    |> validate_number(:run_count, greater_than_or_equal_to: 0)
    |> validate_number(:error_count, greater_than_or_equal_to: 0)
    |> validate_window()
    |> unique_constraint(:slug)
  end

  defp validate_window(changeset) do
    start_at = get_field(changeset, :start_at)
    end_at = get_field(changeset, :end_at)

    if start_at && end_at && DateTime.compare(start_at, end_at) == :gt do
      add_error(changeset, :end_at, "must be after start_at")
    else
      changeset
    end
  end

  def overlap_policies, do: @overlap_policies
  def statuses, do: @statuses
end
