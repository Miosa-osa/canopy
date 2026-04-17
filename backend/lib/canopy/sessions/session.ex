defmodule Canopy.Sessions.Session do
  @moduledoc """
  Ecto schema for a Canopy session — one agent execution against a runtime.

  Sessions form chains via `parent_session_id`: each compaction or resume
  links back to its predecessor. The root session has a nil parent.

  Triple-key resume (Paperclip pattern): `id + cwd + prompt_bundle_key` are
  compared before resuming. If any key mismatches, the adapter starts fresh.
  The `prompt_bundle_key` is the SHA256 of AGENTS.md + injected skills — it
  only changes when the skill bundle changes, saving tokens on resumes.

  Status lifecycle: pending → running → completed | cancelled | failed
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @valid_statuses ~w(pending running completed cancelled failed)

  @derive {Jason.Encoder,
           only: [
             :id,
             :runtime_type,
             :model_id,
             :agent_slug,
             :workspace_slug,
             :status,
             :cwd,
             :prompt,
             :prompt_bundle_key,
             :wake_reason,
             :parent_session_id,
             :sequence_number,
             :external_session_id,
             :started_at,
             :completed_at,
             :error_reason,
             :cost_usd,
             :input_tokens,
             :output_tokens,
             :cache_read_tokens,
             :cache_write_tokens,
             :metadata,
             :inserted_at,
             :updated_at
           ]}

  schema "sessions" do
    field :runtime_type, :string
    field :model_id, :string
    field :agent_slug, :string
    field :workspace_slug, :string
    field :status, :string, default: "pending"
    field :cwd, :string
    field :prompt, :string
    field :prompt_bundle_key, :string
    field :wake_reason, :string
    field :parent_session_id, :binary_id
    field :sequence_number, :integer, default: 0
    field :external_session_id, :string
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec
    field :error_reason, :string
    field :cost_usd, :decimal, default: Decimal.new("0")
    field :input_tokens, :integer, default: 0
    field :output_tokens, :integer, default: 0
    field :cache_read_tokens, :integer, default: 0
    field :cache_write_tokens, :integer, default: 0
    field :metadata, :map, default: %{}

    timestamps()
  end

  @required ~w(runtime_type cwd)a
  @optional ~w(
    model_id agent_slug workspace_slug status prompt prompt_bundle_key
    wake_reason parent_session_id sequence_number external_session_id
    started_at completed_at error_reason cost_usd
    input_tokens output_tokens cache_read_tokens cache_write_tokens metadata
  )a

  @doc "Changeset for creating a new session."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(session, attrs) do
    session
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:runtime_type, min: 1, max: 64)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_length(:prompt_bundle_key, is: 64, allow_nil: true)
  end

  @doc "Changeset for status transitions and finalization."
  @spec status_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def status_changeset(session, attrs) do
    session
    |> cast(attrs, [:status, :started_at, :completed_at, :error_reason])
    |> validate_required([:status])
    |> validate_inclusion(:status, @valid_statuses)
  end

  @doc "Changeset for recording final cost + token usage."
  @spec finalize_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def finalize_changeset(session, attrs) do
    session
    |> cast(attrs, [
      :status,
      :completed_at,
      :cost_usd,
      :input_tokens,
      :output_tokens,
      :cache_read_tokens,
      :cache_write_tokens,
      :error_reason
    ])
    |> validate_inclusion(:status, @valid_statuses)
  end
end
