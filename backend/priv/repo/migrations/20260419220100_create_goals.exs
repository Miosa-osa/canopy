defmodule Canopy.Repo.Migrations.CreateGoals do
  use Ecto.Migration

  def change do
    create table(:goals, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      # Human-readable short ID, e.g. "G-00003721"
      add :short_id, :string, null: false
      add :title, :string, null: false
      add :description, :text
      # proposed | active | blocked | achieved | cancelled
      add :status, :string, null: false, default: "proposed"
      # 0 = none, 1 = low, 2 = medium, 3 = high, 4 = urgent
      add :priority, :integer, null: false, default: 0
      # agent | human
      add :owner_type, :string
      add :owner_id, :string
      add :workspace_slug, :string, null: false
      add :target_date, :utc_datetime
      add :achieved_at, :utc_datetime
      # 0–100
      add :progress_pct, :integer, null: false, default: 0
      add :success_criteria, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:goals, [:short_id])
    create index(:goals, [:workspace_slug, :status])
    create index(:goals, [:workspace_slug, :updated_at])
    create index(:goals, [:owner_id], where: "achieved_at IS NULL", name: :goals_owner_open_idx)
    create index(:goals, [:status])
  end
end
