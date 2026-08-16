defmodule Canopy.Repo.Migrations.AddProjectSlugToGoals do
  use Ecto.Migration

  def change do
    alter table(:goals) do
      add :project_slug, :string
    end

    create index(:goals, [:project_slug], where: "project_slug IS NOT NULL")
  end
end
