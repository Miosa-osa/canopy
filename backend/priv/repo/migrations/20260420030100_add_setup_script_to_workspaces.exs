defmodule Canopy.Repo.Migrations.AddSetupScriptToWorkspaces do
  use Ecto.Migration

  def change do
    alter table(:workspaces) do
      add :setup_script, :text, default: nil
    end
  end
end
