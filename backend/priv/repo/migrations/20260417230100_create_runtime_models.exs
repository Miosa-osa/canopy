defmodule Canopy.Repo.Migrations.CreateRuntimeModels do
  use Ecto.Migration

  def change do
    create table(:runtime_models, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :runtime_id, references(:runtimes, type: :binary_id, on_delete: :delete_all),
        null: false

      add :model_id, :string, null: false
      add :display_name, :string, null: false
      add :context_window, :integer
      add :input_cost_per_mtok, :decimal, precision: 12, scale: 6
      add :output_cost_per_mtok, :decimal, precision: 12, scale: 6
      add :supports_thinking, :boolean, default: false, null: false
      add :supports_tools, :boolean, default: true, null: false
      add :supports_vision, :boolean, default: false, null: false
      add :is_default, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:runtime_models, [:runtime_id, :model_id])
    create index(:runtime_models, [:runtime_id, :is_default])
  end
end
