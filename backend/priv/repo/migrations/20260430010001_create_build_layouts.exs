defmodule Canopy.Repo.Migrations.CreateBuildLayouts do
  use Ecto.Migration

  def change do
    create table(:build_layouts, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :slug, :string, null: false, size: 128
      add :name, :string, null: false, size: 256
      add :scope, :string, null: false, default: "personal", size: 16
      add :owner_id, :binary_id
      add :workspace_slug, :string, size: 128
      add :layout_json, :map, default: %{}, null: false
      add :default_pane_kind, :string, size: 32
      add :density, :string, default: "comfortable", size: 16
      add :pane_title_format, :string, default: "command", size: 16
      add :description, :text
      add :archived_at, :utc_datetime_usec
      add :last_used_at, :utc_datetime_usec
      add :use_count, :integer, default: 0, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:build_layouts, [:scope, :owner_id])
    create index(:build_layouts, [:workspace_slug])
    create index(:build_layouts, [:last_used_at])
    create unique_index(:build_layouts, [:slug, :scope, :owner_id], name: :build_layouts_slug_scope_owner_index)
  end
end
