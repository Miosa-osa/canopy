defmodule Canopy.Repo.Migrations.CreateEnvironmentTables do
  use Ecto.Migration

  def change do
    create table(:app_permissions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false
      add :app_identifier, :string, null: false
      add :app_name, :string, null: false
      add :app_category, :string, default: "other"
      add :granted_by, :string

      timestamps()
    end

    create unique_index(:app_permissions, [:agent_id, :app_identifier])
    create index(:app_permissions, [:agent_id])

    create table(:agent_apps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :agent_id, references(:agents, type: :binary_id, on_delete: :nilify_all)
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all)
      add :template_source, :string
      add :status, :string, default: "stopped"
      add :port, :integer
      add :directory, :string
      add :config, :map, default: %{}
      add :build_log, :text
      add :resource_usage, :map, default: %{}

      timestamps()
    end

    create index(:agent_apps, [:agent_id])
    create index(:agent_apps, [:workspace_id])

    create table(:tool_permissions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false
      add :tool_name, :string, null: false
      add :enabled, :boolean, default: true
      add :config, :map, default: %{}

      timestamps()
    end

    create unique_index(:tool_permissions, [:agent_id, :tool_name])
    create index(:tool_permissions, [:agent_id])
  end
end
