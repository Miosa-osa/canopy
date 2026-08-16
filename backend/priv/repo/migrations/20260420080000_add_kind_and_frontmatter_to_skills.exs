defmodule Canopy.Repo.Migrations.AddKindAndFrontmatterToSkills do
  use Ecto.Migration

  def change do
    alter table(:skills) do
      # "prompt" | "workflow" | "reference"
      add :kind, :string, null: false, default: "prompt"
      # Optional YAML frontmatter parsed into a JSON map (e.g. %{"when" => "code-review"})
      add :frontmatter, :map, default: nil
    end

    create index(:skills, [:kind])
  end
end
