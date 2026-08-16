defmodule Canopy.Repo.Migrations.CreateAnalyticsBreadcrumbs do
  use Ecto.Migration

  def change do
    create table(:analytics_breadcrumbs, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :run_id, :binary_id, null: false
      add :session_id, :binary_id
      add :sequence, :integer, null: false
      add :ts, :utc_datetime_usec, null: false
      add :type, :string, null: false, size: 32
      add :category, :string, size: 64
      add :level, :string, null: false, default: "info", size: 16
      add :message, :string, size: 1024
      add :data, :map, default: %{}, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:analytics_breadcrumbs, [:run_id, :sequence])
    create index(:analytics_breadcrumbs, [:session_id, :sequence])
    create index(:analytics_breadcrumbs, [:ts])
    create index(:analytics_breadcrumbs, [:level])
  end
end
