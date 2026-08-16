defmodule Canopy.Analytics.Insight do
  @moduledoc """
  An anomaly, finding, or saved analyst note produced by the Analytics agent
  (Iris) or by a manual user save.

  Insights are the durable artifact of an investigation. They link back to
  the originating run / session / breadcrumbs and can be referenced from
  dashboards, weekly reports, and the activity feed.

  ## Kinds

  - `"anomaly"` — Prophet-style anomaly detected
  - `"trend"` — sustained directional change beyond baseline
  - `"correlation"` — two metrics moved together
  - `"pattern"` — recurring observation worth promoting to an alert
  - `"saved"` — user-saved query result
  - `"forecast"` — projection (e.g. month-end cost)

  ## Severity

  - `"info"` — FYI, surfaced in `#analytics-feed`
  - `"medium"` — surfaced as inbox brief
  - `"high"` — pages Roberto via Slack
  - `"critical"` — escalates to orchestrator-agent immediately

  ## Feedback

  Roberto can react with `"true_positive"` or `"false_positive"` — feeds
  back into Prophet sensitivity tuning per metric.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @kinds ~w(anomaly trend correlation pattern saved forecast)
  @severities ~w(info medium high critical)
  @feedbacks ~w(true_positive false_positive unverified)

  @derive {Jason.Encoder,
           only: [
             :id,
             :slug,
             :title,
             :body,
             :severity,
             :kind,
             :query,
             :result,
             :metric,
             :detected_at,
             :window_start,
             :window_end,
             :workspace_slug,
             :created_by_agent_id,
             :related_run_id,
             :related_session_id,
             :acknowledged_at,
             :acknowledged_by,
             :feedback,
             :dashboards,
             :tags,
             :inserted_at,
             :updated_at
           ]}

  schema "analytics_insights" do
    field :slug, :string
    field :title, :string
    field :body, :string
    field :severity, :string, default: "info"
    field :kind, :string, default: "anomaly"
    field :query, :map, default: %{}
    field :result, :map, default: %{}
    field :metric, :string
    field :detected_at, :utc_datetime_usec
    field :window_start, :utc_datetime_usec
    field :window_end, :utc_datetime_usec
    field :workspace_slug, :string
    field :created_by_agent_id, :binary_id
    field :related_run_id, :binary_id
    field :related_session_id, :binary_id
    field :acknowledged_at, :utc_datetime_usec
    field :acknowledged_by, :string
    field :feedback, :string
    field :dashboards, {:array, :string}, default: []
    field :tags, {:array, :string}, default: []

    timestamps()
  end

  @required ~w(slug title body detected_at)a
  @optional ~w(severity kind query result metric window_start window_end workspace_slug created_by_agent_id related_run_id related_session_id acknowledged_at acknowledged_by feedback dashboards tags)a

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:slug, max: 128)
    |> validate_length(:title, max: 256)
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:severity, @severities)
    |> validate_inclusion(:feedback, [nil | @feedbacks])
    |> unique_constraint(:slug)
  end

  def kinds, do: @kinds
  def severities, do: @severities
  def feedbacks, do: @feedbacks
end
