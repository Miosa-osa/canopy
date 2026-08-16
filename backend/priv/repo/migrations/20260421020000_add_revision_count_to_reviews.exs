defmodule Canopy.Repo.Migrations.AddRevisionCountToReviews do
  use Ecto.Migration

  def change do
    alter table(:reviews) do
      add :revision_count, :integer, null: false, default: 0
    end
  end
end
