defmodule Canopy.Repo.Migrations.AddIssueIdToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :issue_id, references(:issues, type: :binary_id, on_delete: :nilify_all), null: true
    end

    create index(:sessions, [:issue_id])
  end
end
