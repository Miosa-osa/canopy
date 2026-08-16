defmodule Canopy.Repo.Migrations.AddAuthProfileToRuntimes do
  use Ecto.Migration

  def change do
    alter table(:runtimes) do
      add :auth_profile, :map, null: true, default: nil
    end
  end
end
