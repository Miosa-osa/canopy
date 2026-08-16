defmodule Canopy.Workspaces.InitJob do
  @moduledoc """
  Ecto schema for a workspace initialisation job.

  Tracks multi-step init progress: clone, detect_base_branch, create_initial_worktree,
  run_setup_script, done.  All step transitions and output appends are persisted so
  a client reloading mid-init sees the correct state.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @valid_statuses ~w(pending running succeeded failed cancelled)
  @valid_steps ~w(detect_base_branch ensure_clone create_initial_worktree run_setup_script done)

  @derive {Jason.Encoder,
           only: [
             :id,
             :workspace_slug,
             :status,
             :current_step,
             :progress_pct,
             :output,
             :error,
             :started_at,
             :finished_at,
             :inserted_at,
             :updated_at
           ]}

  schema "workspace_init_jobs" do
    field :workspace_slug, :string
    field :status, :string, default: "pending"
    field :current_step, :string
    field :progress_pct, :integer, default: 0
    field :output, :string, default: ""
    field :error, :string
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime

    timestamps()
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(job, attrs) do
    job
    |> cast(attrs, [
      :workspace_slug,
      :status,
      :current_step,
      :progress_pct,
      :output,
      :error,
      :started_at,
      :finished_at
    ])
    |> validate_required([:workspace_slug, :status])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:current_step, @valid_steps, allow_nil: true)
    |> validate_number(:progress_pct, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end
end
