defmodule Canopy.Runs.Run do
  @moduledoc """
  Ecto schema for a run — an execution record tying every agent-originated action
  back to a specific tracked invocation.

  Status lifecycle: queued → running → paused → succeeded | failed | cancelled

  Short IDs use the format R-XXXXXXXX (8 random uppercase hex characters).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_statuses ~w(queued running paused succeeded failed cancelled)

  @derive {Jason.Encoder,
           only: [
             :id,
             :short_id,
             :session_id,
             :agent_slug,
             :workspace_slug,
             :issue_short_id,
             :task_short_id,
             :project_slug,
             :process_pid,
             :status,
             :prompt_bundle_key,
             :usage_json,
             :log_ref,
             :context_snapshot,
             :started_at,
             :finished_at,
             :error_reason,
             :wake_reason,
             :inserted_at,
             :updated_at
           ]}

  schema "runs" do
    field :short_id, :string
    field :session_id, :binary_id
    field :agent_slug, :string
    field :workspace_slug, :string
    field :issue_short_id, :string
    field :task_short_id, :string
    field :project_slug, :string
    field :process_pid, :integer
    field :status, :string, default: "queued"
    field :prompt_bundle_key, :string
    field :usage_json, :map, default: %{}
    field :log_ref, :string
    field :context_snapshot, :map
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime
    field :error_reason, :string
    field :wake_reason, :string

    timestamps()
  end

  @required ~w(workspace_slug started_at)a
  @optional ~w(short_id session_id agent_slug issue_short_id task_short_id project_slug
               process_pid status prompt_bundle_key usage_json log_ref context_snapshot
               finished_at error_reason wake_reason)a

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(run, attrs) do
    run
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:status, @valid_statuses)
  end
end
