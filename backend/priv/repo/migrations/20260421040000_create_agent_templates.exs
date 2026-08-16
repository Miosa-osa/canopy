defmodule Canopy.Repo.Migrations.CreateAgentTemplates do
  use Ecto.Migration

  def change do
    create table(:agent_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slug, :string, null: false
      add :name, :string, null: false
      add :description, :string
      add :category, :string, null: false
      add :persona_markdown, :text, null: false, default: ""
      add :default_runtime, :string
      add :default_model, :string
      add :capabilities, {:array, :string}, null: false, default: []
      add :skill_slugs, {:array, :string}, null: false, default: []
      add :icon, :string, null: false, default: "🤖"
      add :color, :string, null: false, default: "#6B7280"
      add :sort_order, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:agent_templates, [:slug])
    create index(:agent_templates, [:category])
    create index(:agent_templates, [:sort_order])
  end
end
