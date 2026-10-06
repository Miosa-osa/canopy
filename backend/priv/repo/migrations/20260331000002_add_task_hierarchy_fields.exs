defmodule Canopy.Repo.Migrations.AddTaskHierarchyFields do
  use Ecto.Migration

  def change do
    alter table(:issues) do
      add :parent_issue_id, references(:issues, type: :binary_id, on_delete: :nilify_all)
    end

    alter table(:goals) do
      add :evidence_gate, :string
    end

    create index(:issues, [:parent_issue_id])
  end
end
