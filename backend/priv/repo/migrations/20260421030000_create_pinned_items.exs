defmodule Canopy.Repo.Migrations.CreatePinnedItems do
  use Ecto.Migration

  def change do
    create table(:pinned_items, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :workspace_slug, :string, null: false, size: 128
      add :item_type, :string, null: false, size: 32
      add :item_ref, :string, null: false, size: 256
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pinned_items, [:workspace_slug, :item_type, :item_ref],
             name: :pinned_items_workspace_type_ref_idx
           )

    create index(:pinned_items, [:workspace_slug, :position])
  end
end
