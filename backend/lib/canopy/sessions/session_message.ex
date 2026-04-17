defmodule Canopy.Sessions.SessionMessage do
  @moduledoc """
  Ecto schema for a single transcript entry within a session.

  Messages are append-only — there is no `updated_at` timestamp. Each message
  has a monotonically increasing `sequence` number that is unique within its
  session. The `kind` discriminates the payload shape stored in `content`.

  Supported kinds (Paperclip TranscriptEntry union):
    - `assistant`    — text response from the LLM
    - `thinking`     — extended thinking block
    - `tool_call`    — tool invocation request (links via tool_call_id)
    - `tool_result`  — tool execution result (links via tool_call_id)
    - `diff`         — file change patch
    - `stderr`       — subprocess stderr output
    - `stdout`       — subprocess stdout output
    - `system`       — system/status message
    - `user`         — user-submitted message
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_kinds ~w(assistant thinking tool_call tool_result diff stderr stdout system user)

  @derive {Jason.Encoder,
           only: [
             :id,
             :session_id,
             :sequence,
             :kind,
             :content,
             :tool_call_id,
             :emitted_at,
             :inserted_at
           ]}

  # Intentionally omit updated_at — messages are append-only
  @timestamps_opts [inserted_at: :inserted_at, updated_at: false, type: :utc_datetime_usec]

  schema "session_messages" do
    belongs_to :session, Canopy.Sessions.Session

    field :sequence, :integer
    field :kind, :string
    field :content, :map
    field :tool_call_id, :string
    field :emitted_at, :utc_datetime_usec

    timestamps()
  end

  @required ~w(session_id sequence kind content emitted_at)a
  @optional ~w(tool_call_id)a

  @doc "Changeset for appending a new message to a session."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(message, attrs) do
    message
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:kind, @valid_kinds)
    |> validate_number(:sequence, greater_than_or_equal_to: 0)
    |> unique_constraint(:sequence,
      name: :session_messages_session_id_sequence_index,
      message: "has already been taken"
    )
  end
end
