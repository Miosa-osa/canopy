defmodule Canopy.Repo.Migrations.AddRunAndSessionToHookEvents do
  @moduledoc """
  Links hook_events to Canopy sessions and runs so the /sessions/:id view
  can render an agent lifecycle tab.

  Adds:
    run_id              — foreign key to runs.id (nullable)
    canopy_session_id   — foreign key to sessions.id (nullable, UUID)
                          Named differently from session_id (the agent string) to avoid confusion.
  """

  use Ecto.Migration

  def change do
    alter table(:hook_events) do
      add :run_id, :binary_id, null: true
      add :canopy_session_id, :binary_id, null: true
    end

    create index(:hook_events, [:run_id])
    create index(:hook_events, [:canopy_session_id])
  end
end
