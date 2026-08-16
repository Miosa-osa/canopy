defmodule Canopy.Analytics.Alert do
  @moduledoc """
  Configured alert rule that the Analytics super-module evaluates on every
  scheduled scan or eligible incoming telemetry event.

  Two types:

  - `"threshold"` — fires when `metric` crosses a static `config.value` in
    `config.direction` ("above" / "below") sustained for `config.window_seconds`.
  - `"anomaly"` — fires when Prophet-style detector flags the metric outside
    its predicted band at confidence `sensitivity`.

  ## Config shape (per type)

  Threshold:
  ```
  %{value: 100, direction: "above", window_seconds: 300}
  ```

  Anomaly:
  ```
  %{lookback_hours: 168, season: "weekly", min_confidence: 0.8}
  ```

  ## Routing shape

  ```
  %{
    channels: ["#analytics-alerts"],
    inbox: ["roberto"],
    severity: "high",
    cooldown_seconds: 600
  }
  ```
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @types ~w(threshold anomaly composite)
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
             :sensitivity,
             :workspace_slug,
             :created_by_agent_id,
             :last_evaluated_at,
             :last_fired_at,
             :fire_count,
             :inserted_at,
             :updated_at
           ]}

  schema "analytics_alerts" do
    field :slug, :string
    field :name, :string
    field :description, :string
    field :metric, :string
    field :type, :string, default: "anomaly"
    field :config, :map, default: %{}
    field :routing, :map, default: %{}
    field :enabled, :boolean, default: true
    field :severity, :string, default: "medium"
    field :sensitivity, :float, default: 0.8
    field :workspace_slug, :string
    field :created_by_agent_id, :binary_id
    field :last_evaluated_at, :utc_datetime_usec
    field :last_fired_at, :utc_datetime_usec
    field :fire_count, :integer, default: 0

    timestamps()
  end

  @required ~w(slug name metric type)a
  @optional ~w(description config routing enabled severity sensitivity workspace_slug created_by_agent_id last_evaluated_at last_fired_at fire_count)a

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:slug, max: 128)
    |> validate_length(:name, max: 256)
    |> validate_inclusion(:type, @types)
    |> validate_inclusion(:severity, @severities)
    |> validate_number(:sensitivity, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:fire_count, greater_than_or_equal_to: 0)
    |> unique_constraint(:slug)
  end

  def types, do: @types
  def severities, do: @severities
end
