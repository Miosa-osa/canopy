defmodule Canopy.Repo.Migrations.CreateRuntimeModelRoles do
  @moduledoc """
  Per-model role assignments — a single model may claim multiple roles
  (chat, autocomplete, edit, apply, embed, rerank, summarize). One model
  per role can be marked as the default.

  Lifted concept: the role-based model dispatch pattern. Each row binds a
  `(runtime, model)` pair to one role, with an optional `default_for_role`
  flag. The Runtime Adapter Agent uses this to route role-specific work to
  the right model.
  """

  use Ecto.Migration

  def change do
    create table(:runtime_model_roles, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :runtime, :string, null: false, size: 64
      add :model, :string, null: false, size: 128
      add :role, :string, null: false, size: 32
      add :default_for_role, :boolean, default: false, null: false
      add :priority, :integer, default: 0, null: false
      add :workspace_slug, :string, size: 128
      add :metadata, :map, default: %{}, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:runtime_model_roles, [:runtime, :model, :role],
             name: :runtime_model_roles_unique_index
           )

    create index(:runtime_model_roles, [:role, :default_for_role])
    create index(:runtime_model_roles, [:runtime])
    create index(:runtime_model_roles, [:workspace_slug])
  end
end
