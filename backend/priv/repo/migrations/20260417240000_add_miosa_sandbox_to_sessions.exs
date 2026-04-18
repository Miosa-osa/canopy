defmodule Canopy.Repo.Migrations.AddMiosaSandboxToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :miosa_sandbox_id, :string, null: true
      add :miosa_sandbox_url, :string, null: true
      # pending | provisioning | ready | destroyed | skipped | failed
      add :miosa_sandbox_status, :string, null: true
    end

    create index(:sessions, [:miosa_sandbox_id])
  end
end
