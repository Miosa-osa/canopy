defmodule Canopy.Repo.Migrations.AddCronSafetyFieldsToRoutines do
  use Ecto.Migration

  def change do
    alter table(:routines) do
      add :error_count, :integer, default: 0, null: false
      add :in_flight, :boolean, default: false, null: false
    end
  end
end
