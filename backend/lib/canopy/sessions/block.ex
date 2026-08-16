defmodule Canopy.Sessions.Block do
  @moduledoc """
  Ecto schema for a `session_blocks` row.

  A **Block** is the foundational data unit of the agentic terminal — a
  discrete navigable group (one command + its output, an agent message
  with its tool-calls, an approval card, etc.). Blocks group related
  `SessionMessage` rows; the flat transcript still lives in `session_messages`
  and is unaffected by this primitive.

  ## Kinds

  - `"command"`         — terminal command + its output
  - `"agent_message"`   — an LLM message body (markdown text)
  - `"tool_call"`       — a tool invocation (typically `parent_block_id`
                           points at the agent_message that initiated it)
  - `"tool_result"`     — the result row paired with a tool_call
  - `"approval"`        — inline governance approval prompt
  - `"diff"`            — file change patch
  - `"system_event"`    — small grey row (status / lifecycle / heartbeat)
  - `"error"`           — error row

  ## Status

  - `"running"`           — work in progress, no terminal status yet
  - `"completed"`         — finished cleanly
  - `"failed"`            — terminal failure
  - `"cancelled"`         — user cancelled
  - `"pending_approval"`  — awaiting governance decision

  Sequence is unique per session. The `Canopy.Sessions.Blocks` context module
  is responsible for assigning the next sequence atomically; this schema only
  enforces the format and the unique constraint.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @kinds ~w(command agent_message tool_call tool_result approval diff system_event error)
  @statuses ~w(running completed failed cancelled pending_approval)

  @derive {Jason.Encoder,
           only: [
             :id,
             :session_id,
             :parent_block_id,
             :sequence,
             :kind,
             :status,
             :input_text,
             :output_text,
             :exit_code,
             :started_at,
             :ended_at,
             :duration_ms,
             :cost_cents,
             :metadata,
             :tags,
             :inserted_at,
             :updated_at
           ]}

  schema "session_blocks" do
    belongs_to :session, Canopy.Sessions.Session
    belongs_to :parent_block, __MODULE__, foreign_key: :parent_block_id

    field :sequence, :integer
    field :kind, :string
    field :status, :string, default: "running"

    field :input_text, :string
    field :output_text, :string

    field :exit_code, :integer
    field :started_at, :utc_datetime_usec
    field :ended_at, :utc_datetime_usec
    field :duration_ms, :integer
    field :cost_cents, :integer

    field :metadata, :map, default: %{}
    field :tags, {:array, :string}, default: []

    timestamps()
  end

  @required ~w(session_id sequence kind)a
  @optional ~w(parent_block_id status input_text output_text exit_code started_at ended_at duration_ms cost_cents metadata tags)a

  @type t :: %__MODULE__{}

  @doc "Insert/update changeset."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(block, attrs) do
    block
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:sequence, greater_than_or_equal_to: 0)
    |> validate_number(:cost_cents, greater_than_or_equal_to: 0)
    |> validate_number(:duration_ms, greater_than_or_equal_to: 0)
    |> unique_constraint(:sequence,
      name: :session_blocks_session_id_sequence_index,
      message: "has already been taken"
    )
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:parent_block_id)
  end

  @doc "Status transition changeset — only mutates lifecycle fields."
  @spec status_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def status_changeset(block, attrs) do
    block
    |> cast(attrs, ~w(status ended_at duration_ms exit_code cost_cents output_text)a)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:cost_cents, greater_than_or_equal_to: 0)
    |> validate_number(:duration_ms, greater_than_or_equal_to: 0)
  end

  def kinds, do: @kinds
  def statuses, do: @statuses
end
