defmodule Canopy.Repo.Migrations.CreateTemplateVersions do
  use Ecto.Migration

  def change do
    create table(:template_versions, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :template_id, references(:templates, type: :binary_id, on_delete: :delete_all),
        null: false

      add :version, :string, null: false, size: 32
      add :diff, :map, default: %{}, null: false
      add :body_snapshot, :map, default: %{}, null: false
      add :parameters_snapshot, :map, default: %{}, null: false
      add :changelog, :text
      add :sha256, :string, size: 64
      add :authored_by, :string, size: 128
      add :authored_by_agent_id, :binary_id

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:template_versions, [:template_id, :version])
    create index(:template_versions, [:template_id, :inserted_at])
  end
end
