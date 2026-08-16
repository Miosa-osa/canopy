defmodule Canopy.Repo.Migrations.CreateRuntimeCheckpoints do
  @moduledoc """
  Per-runtime session checkpoints — code + transcript + agent memory.

  A checkpoint captures the state needed to resume or roll back a session:

  - `code_hash` — content hash of the workspace files at capture time.
  - `transcript_id` — pointer to the transcript at the captured sequence.
  - `agent_memory` — jsonb blob: persona snapshot, skill state, breadcrumb
    seq, and any adapter-specific resume tokens.
  - `parent_checkpoint_id` — restores create a new checkpoint pointing back to
    the one they restored from, so rollback-of-rollback is reversible.
  """

  use Ecto.Migration

  def change do
    create table(:runtime_checkpoints, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :session_id, :binary_id, null: false
      add :runtime, :string, null: false, size: 64
      add :label, :string, size: 256
      add :captured_at, :utc_datetime_usec, null: false
      add :code_hash, :string, size: 128
      add :transcript_id, :binary_id
      add :transcript_sequence, :integer
      add :agent_memory, :map, default: %{}, null: false
      add :parent_checkpoint_id, :binary_id
      add :workspace_slug, :string, size: 128
      add :created_by_agent_id, :binary_id
      add :restored_at, :utc_datetime_usec
      add :metadata, :map, default: %{}, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:runtime_checkpoints, [:session_id, :captured_at])
    create index(:runtime_checkpoints, [:runtime])
    create index(:runtime_checkpoints, [:parent_checkpoint_id])
    create index(:runtime_checkpoints, [:workspace_slug])
    create index(:runtime_checkpoints, [:created_by_agent_id])
  end
end
