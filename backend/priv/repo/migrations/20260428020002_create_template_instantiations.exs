defmodule Canopy.Repo.Migrations.CreateTemplateInstantiations do
  use Ecto.Migration

  def change do
    create table(:template_instantiations, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :template_id, references(:templates, type: :binary_id, on_delete: :nilify_all)
      add :template_slug, :string, null: false, size: 128
      add :template_version, :string, null: false, size: 32
      add :target_workspace_slug, :string, size: 128
      add :target_path, :string, size: 1024
      add :params, :map, default: %{}, null: false
      add :files_written, :integer, default: 0, null: false
      add :agents_created, :integer, default: 0, null: false
      add :skills_installed, :integer, default: 0, null: false
      add :status, :string, null: false, default: "pending", size: 32
      add :error, :text
      add :instantiated_by_agent_id, :binary_id
      add :instantiated_by, :string, size: 128

      timestamps(type: :utc_datetime_usec)
    end

    create index(:template_instantiations, [:template_id])
    create index(:template_instantiations, [:template_slug])
    create index(:template_instantiations, [:target_workspace_slug])
    create index(:template_instantiations, [:status])
    create index(:template_instantiations, [:inserted_at])
  end
end
