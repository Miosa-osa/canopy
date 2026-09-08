defmodule Canopy.Repo.Migrations.CreateBuildLayoutUses do
  use Ecto.Migration

  def change do
    create table(:build_layout_uses, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false

      add :layout_id, references(:build_layouts, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, :binary_id
      add :workspace_slug, :string, size: 128
      add :intent, :string, size: 256
      add :opened_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:build_layout_uses, [:layout_id])
    create index(:build_layout_uses, [:user_id])
    create index(:build_layout_uses, [:opened_at])
    create index(:build_layout_uses, [:workspace_slug, :opened_at])
  end
end
