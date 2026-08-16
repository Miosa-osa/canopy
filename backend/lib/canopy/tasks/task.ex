defmodule Canopy.Tasks.Task do
  @moduledoc "Ecto schema for a task."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_statuses ~w(todo in_progress done cancelled)
  @valid_priorities 0..3

  @derive {Jason.Encoder,
           only: [
             :id,
             :short_id,
             :parent_id,
             :project_slug,
             :title,
             :description,
             :status,
             :priority,
             :assignee_type,
             :assignee_id,
             :workspace_slug,
             :session_id,
             :dispatched_at,
             :due_at,
             :completed_at,
             :labels,
             :review_id,
             :created_by_run_id,
             :claimed_by_agent_id,
             :claimed_at,
             :auto_assignable,
             :required_skills,
             :inserted_at,
             :updated_at
           ]}

  schema "tasks" do
    field :short_id, :string
    field :parent_id, :binary_id
    field :project_slug, :string
    field :title, :string
    field :description, :string
    field :status, :string, default: "todo"
    field :priority, :integer, default: 0
    field :assignee_type, :string
    field :assignee_id, :string
    field :workspace_slug, :string
    field :session_id, :binary_id
    field :dispatched_at, :utc_datetime
    field :due_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :labels, {:array, :string}, default: []
    field :review_id, :binary_id
    field :created_by_run_id, :binary_id
    # Agent-kanban claim fields (see Canopy.Tasks.Kanban).
    field :claimed_by_agent_id, :string
    field :claimed_at, :utc_datetime_usec
    field :auto_assignable, :boolean, default: false
    field :required_skills, {:array, :string}, default: []

    timestamps()
  end

  @required ~w(title)a
  @optional ~w(short_id parent_id project_slug description status priority
               assignee_type assignee_id workspace_slug session_id dispatched_at
               due_at completed_at labels review_id created_by_run_id
               claimed_by_agent_id claimed_at auto_assignable required_skills)a

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(task, attrs) do
    task
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:title, min: 1, max: 512)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:priority, Enum.to_list(@valid_priorities))
    |> unique_constraint(:short_id)
  end
end
