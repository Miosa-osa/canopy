defmodule Canopy.Repo.Migrations.AddWorktreeToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :worktree_path, :string
      add :branch, :string
      add :base_branch, :string
    end
  end
end
