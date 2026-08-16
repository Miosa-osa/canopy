defmodule Canopy.Repo.Migrations.CreateWorkspaceStates do
  @moduledoc """
  Per-workspace key/value state store. Module-agnostic dictionary for any
  feature that needs to persist UI/runtime state scoped to a single workspace
  (Mosaic layouts, side-rail section, recent files, density, etc.).

  Identity: composite (workspace_slug, key). One row per (workspace, key) pair.
  Cascading: rows are removed in `Canopy.Workspaces.States.delete_all/1` when a
  workspace is hard-deleted; soft-deleted workspaces retain their state so a
  restore reattaches the same UI.
  """
  use Ecto.Migration

  def change do
    create table(:workspace_states, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :workspace_slug, :string, null: false, size: 128
      add :key, :string, null: false, size: 128
      add :value, :map, default: %{}, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:workspace_states, [:workspace_slug])

    create unique_index(:workspace_states, [:workspace_slug, :key],
             name: :workspace_states_slug_key_index
           )
  end
end
