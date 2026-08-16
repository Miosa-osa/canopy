defmodule Canopy.Analytics.Telemetry do
  @moduledoc """
  Append-only telemetry event for the Analytics super-module.

  Emitted automatically by the runtime adapter `execute/3` middleware on
  start/finish/fail of every agent run. Also emitted by the heartbeat
  scheduler, governance gate, and budget enforcer for cross-cutting events.

  Events are queryable via `Canopy.Analytics.query_telemetry/2`. They feed
  the dashboard widgets, the anomaly detector, and the Iris agent's
  investigation tool.

  ## Event vocabulary

  - `"agent.run.started"` / `"agent.run.finished"` / `"agent.run.failed"`
  - `"session.created"` / `"session.completed"` / `"session.cancelled"`
  - `"governance.approved"` / `"governance.rejected"` / `"governance.escalated"`
  - `"budget.threshold_warned"` / `"budget.ceiling_blocked"`
  - `"heartbeat.fired"` / `"heartbeat.missed"`
  - `"runtime.swapped"` / `"runtime.test_failed"`
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @derive {Jason.Encoder,
           only: [
             :id,
             :ts,
             :event,
             :run_id,
             :session_id,
             :agent_id,
             :workspace_slug,
             :runtime,
             :model,
             :duration_ms,
             :cost_cents,
             :status,
             :payload,
             :inserted_at
           ]}

  schema "analytics_telemetry" do
    field :ts, :utc_datetime_usec
    field :event, :string
    field :run_id, :binary_id
    field :session_id, :binary_id
    field :agent_id, :binary_id
    field :workspace_slug, :string
    field :runtime, :string
    field :model, :string
    field :duration_ms, :integer
    field :cost_cents, :integer
    field :status, :string
    field :payload, :map, default: %{}

    timestamps(updated_at: false)
  end

  @required ~w(event ts)a
  @optional ~w(run_id session_id agent_id workspace_slug runtime model duration_ms cost_cents status payload)a

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:event, max: 64)
    |> validate_inclusion(:status, [nil, "ok", "error", "warn", "info"])
  end
end
