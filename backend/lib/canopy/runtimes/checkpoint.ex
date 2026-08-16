defmodule Canopy.Runtimes.Checkpoint do
  @moduledoc """
  A point-in-time snapshot of a runtime session.

  Combines four resumable artifacts:

  1. `code_hash` — content hash of the workspace at capture (git ref or
     SHA-256 over tracked files).
  2. `transcript_id` + `transcript_sequence` — the position in the session
     transcript at capture time.
  3. `agent_memory` — adapter-specific resume state (persona snapshot, skill
     deck, breadcrumb sequence, system-prompt-bundle key).
  4. `parent_checkpoint_id` — the checkpoint that this one was restored from
     (if any), enabling rollback-of-rollback.

  The Runtime Adapter Agent uses these to restore a session to a prior state
  without losing the ability to roll forward again.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @derive {Jason.Encoder,
           only: [
             :id,
             :session_id,
             :runtime,
             :label,
             :captured_at,
             :code_hash,
             :transcript_id,
             :transcript_sequence,
             :agent_memory,
             :parent_checkpoint_id,
             :workspace_slug,
             :created_by_agent_id,
             :restored_at,
             :metadata,
             :inserted_at,
             :updated_at
           ]}

  schema "runtime_checkpoints" do
    field :session_id, :binary_id
    field :runtime, :string
    field :label, :string
    field :captured_at, :utc_datetime_usec
    field :code_hash, :string
    field :transcript_id, :binary_id
    field :transcript_sequence, :integer
    field :agent_memory, :map, default: %{}
    field :parent_checkpoint_id, :binary_id
    field :workspace_slug, :string
    field :created_by_agent_id, :binary_id
    field :restored_at, :utc_datetime_usec
    field :metadata, :map, default: %{}

    timestamps()
  end

  @required ~w(session_id runtime captured_at)a
  @optional ~w(label code_hash transcript_id transcript_sequence agent_memory
              parent_checkpoint_id workspace_slug created_by_agent_id restored_at metadata)a

  @type t :: %__MODULE__{}

  @doc "Changeset for creating or updating a checkpoint."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:runtime, max: 64)
    |> validate_length(:label, max: 256)
    |> validate_length(:code_hash, max: 128)
  end
end
