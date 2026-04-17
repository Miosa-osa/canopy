defmodule Canopy.Repo.Migrations.CreateRuntimes do
  use Ecto.Migration

  def change do
    create table(:runtimes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false
      add :kind, :string, null: false
      add :name, :string, null: false
      add :enabled, :boolean, default: true, null: false
      add :installed, :boolean, default: false, null: false
      add :version, :string
      add :binary_path, :string
      add :config, :map, default: %{}
      add :capabilities, {:array, :string}, default: []
      add :last_detected_at, :utc_datetime

      timestamps()
    end

    create unique_index(:runtimes, [:type])
    create index(:runtimes, [:enabled, :installed])
  end
end
