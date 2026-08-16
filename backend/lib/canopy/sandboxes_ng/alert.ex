defmodule Canopy.SandboxesNg.Alert do
  @moduledoc """
  Configured alert rule for the Sandboxes super-module. Evaluated on every
  Sandbox Operator heartbeat sweep and on lifecycle-event ingestion.

  Two types:

  - `"threshold"` — fires when `metric` crosses a static `config.value` in
    `config.direction` ("above" / "below") sustained for `config.window_seconds`.
  - `"composite"` — fires when multiple sub-conditions match (e.g.
    `state == "error" AND idle_minutes > 30`).

  ## Common metrics

  - `"sandbox_count"` — total active sandboxes
  - `"public_port_count"` — number of public-visibility forwards
  - `"orphan_sandbox_count"` — sandboxes without an owner agent
  - `"snapshot_storage_bytes"` — sum of snapshot sizes
  - `"compute_cost_cents"` — sandbox compute spend
  - `"error_state_count"` — sandboxes stuck in error state
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @types ~w(threshold composite)
  @severities ~w(info medium high critical)

  @derive {Jason.Encoder,
           only: [
             :id,
             :slug,
             :name,
             :description,
             :metric,
             :type,
             :config,
             :routing,
             :enabled,
             :severity,
             :workspace_slug,
             :created_by_agent_id,
             :last_evaluated_at,
             :last_fired_at,
             :fire_count,
             :inserted_at,
             :updated_at
           ]}

  schema "sandbox_alerts" do
    field :slug, :string
    field :name, :string
    field :description, :string
    field :metric, :string
    field :type, :string, default: "threshold"
    field :config, :map, default: %{}
    field :routing, :map, default: %{}
    field :enabled, :boolean, default: true
    field :severity, :string, default: "medium"
    field :workspace_slug, :string
    field :created_by_agent_id, :binary_id
    field :last_evaluated_at, :utc_datetime_usec
    field :last_fired_at, :utc_datetime_usec
    field :fire_count, :integer, default: 0

    timestamps()
  end

  @required ~w(slug name metric type)a
  @optional ~w(description config routing enabled severity workspace_slug created_by_agent_id last_evaluated_at last_fired_at fire_count)a

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:slug, max: 128)
    |> validate_length(:name, max: 256)
    |> validate_inclusion(:type, @types)
    |> validate_inclusion(:severity, @severities)
    |> validate_number(:fire_count, greater_than_or_equal_to: 0)
    |> unique_constraint(:slug)
  end

  def types, do: @types
  def severities, do: @severities
end
