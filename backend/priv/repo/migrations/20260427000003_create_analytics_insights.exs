defmodule Canopy.Repo.Migrations.CreateAnalyticsInsights do
  use Ecto.Migration

  def change do
    create table(:analytics_insights, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :slug, :string, null: false, size: 128
      add :title, :string, null: false, size: 256
      add :body, :text, null: false
      add :severity, :string, null: false, default: "info", size: 16
      add :kind, :string, null: false, default: "anomaly", size: 32
      add :query, :map, default: %{}, null: false
      add :result, :map, default: %{}, null: false
      add :metric, :string, size: 128
      add :detected_at, :utc_datetime_usec, null: false
      add :window_start, :utc_datetime_usec
      add :window_end, :utc_datetime_usec
      add :workspace_slug, :string, size: 128
      add :created_by_agent_id, :binary_id
      add :related_run_id, :binary_id
      add :related_session_id, :binary_id
      add :acknowledged_at, :utc_datetime_usec
      add :acknowledged_by, :string, size: 128
      add :feedback, :string, size: 16
      add :dashboards, {:array, :string}, default: [], null: false
      add :tags, {:array, :string}, default: [], null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:analytics_insights, [:slug])
    create index(:analytics_insights, [:detected_at])
    create index(:analytics_insights, [:severity, :detected_at])
    create index(:analytics_insights, [:kind])
    create index(:analytics_insights, [:workspace_slug, :detected_at])
    create index(:analytics_insights, [:created_by_agent_id])
  end
end
