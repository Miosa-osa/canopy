defmodule Canopy.Agents.ToolCall do
  @moduledoc """
  Ecto schema for an agent tool call audit record.

  Every call to `Canopy.Agents.Tools.execute/3` writes one row here regardless
  of outcome: `:ok`, `:error`, or `:pending_review`. This provides a full audit
  trail of what tools agents invoked during a session.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_statuses ~w(ok error pending_review)

  @derive {Jason.Encoder,
           only: [
             :id,
             :session_id,
             :run_id,
             :agent_id,
             :tool_name,
             :params,
             :result,
             :status,
             :error,
             :review_id,
             :inserted_at
           ]}

  schema "agent_tool_calls" do
    field :session_id, :binary_id
    field :run_id, :binary_id
    field :agent_id, :string
    field :tool_name, :string
    field :params, :map, default: %{}
    field :result, :map
    field :status, :string, default: "ok"
    field :error, :string
    field :review_id, :binary_id

    timestamps(updated_at: false)
  end

  @required ~w(session_id agent_id tool_name status)a
  @optional ~w(params result error review_id run_id)a

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(tool_call, attrs) do
    tool_call
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_length(:tool_name, min: 1, max: 128)
    |> validate_length(:agent_id, min: 1, max: 128)
  end
end
