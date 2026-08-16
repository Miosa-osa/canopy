defmodule Canopy.Repo.Migrations.AddReviewIdToArtifacts do
  use Ecto.Migration

  def change do
    alter table(:documents) do
      add :review_id, :binary_id, null: true
    end

    alter table(:tasks) do
      add :review_id, :binary_id, null: true
    end

    alter table(:issues) do
      add :review_id, :binary_id, null: true
    end

    create index(:documents, [:review_id], where: "review_id IS NOT NULL")
    create index(:tasks, [:review_id], where: "review_id IS NOT NULL")
    create index(:issues, [:review_id], where: "review_id IS NOT NULL")
  end
end
