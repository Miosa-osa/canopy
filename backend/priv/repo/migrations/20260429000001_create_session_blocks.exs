defmodule Canopy.Repo.Migrations.CreateSessionBlocks do
  @moduledoc """
  Block primitive — groups related SessionMessages into navigable units.

  Sits **beside** `session_messages` (flat append-only transcript). The Block
  is a higher-level discrete unit (one command + its output, an agent message
  with its tool-calls nested under it, an approval card, etc.) that the
  agentic-terminal UI can navigate, pin, share, and re-run.

  Sequence is monotonic per-session, enforced at insert time by the context
  module via a sub-query selecting `coalesce(max(sequence) + 1, 0)` inside
  the same transaction. The unique index `(session_id, sequence)` is the
  authoritative constraint — concurrent inserts that race surface as a
  changeset error and are retried by the caller.
  """

  use Ecto.Migration

  def change do
    create table(:session_blocks, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false

      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all),
        null: false

      add :parent_block_id,
          references(:session_blocks, type: :binary_id, on_delete: :nilify_all)

      add :sequence, :integer, null: false
      add :kind, :string, null: false, size: 32
      add :status, :string, null: false, default: "running", size: 24

      add :input_text, :text
      add :output_text, :text

      add :exit_code, :integer
      add :started_at, :utc_datetime_usec
      add :ended_at, :utc_datetime_usec
      add :duration_ms, :integer
      add :cost_cents, :integer

      add :metadata, :map, default: %{}, null: false
      add :tags, {:array, :string}, default: [], null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:session_blocks, [:session_id, :sequence])
    create index(:session_blocks, [:session_id, :started_at])
    create index(:session_blocks, [:kind])
    create index(:session_blocks, [:status])
    create index(:session_blocks, [:started_at])
    create index(:session_blocks, [:parent_block_id])
    create index(:session_blocks, [:tags], using: "GIN")
  end
end
