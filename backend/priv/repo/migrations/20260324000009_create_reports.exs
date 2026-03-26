defmodule Canopy.Repo.Migrations.CreateReports do
  use Ecto.Migration

  def change do
    create table(:reports, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all)
      add :created_by_id, :binary_id
      add :name, :string, null: false
      add :description, :text
      add :report_type, :string, null: false
      add :config, :map, null: false
      add :schedule, :string
      add :last_generated_at, :utc_datetime
      add :format, :string, default: "table"
      add :status, :string, default: "active"
      add :cached_result, :map
      add :tags, {:array, :string}, default: []
      timestamps()
    end

    create index(:reports, [:workspace_id])
    create index(:reports, [:report_type])
  end
end
