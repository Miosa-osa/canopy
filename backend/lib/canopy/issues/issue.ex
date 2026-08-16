defmodule Canopy.Issues.Issue do
  @moduledoc "Ecto schema for a developer-facing issue."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_statuses ~w(backlog open in_progress in_review closed)
  @valid_priorities 0..4

  @derive {Jason.Encoder,
           only: [
             :id,
             :short_id,
             :title,
             :description,
             :status,
             :priority,
             :assignee_type,
             :assignee_id,
             :workspace_slug,
             :project_slug,
             :parent_id,
             :session_id,
             :dispatched_at,
             :completed_at,
             :branch,
             :pr_url,
             :labels,
             :estimate_minutes,
             :due_at,
             :review_id,
             :created_by_run_id,
             :checked_out_by_agent,
             :checked_out_at,
             :checkout_expires_at,
             :inserted_at,
             :updated_at
           ]}

  schema "issues" do
    field :short_id, :string
    field :title, :string
    field :description, :string
    field :status, :string, default: "open"
    field :priority, :integer, default: 0
    field :assignee_type, :string
    field :assignee_id, :string
    field :workspace_slug, :string
    field :project_slug, :string
    field :parent_id, :binary_id
    field :session_id, :binary_id
    field :dispatched_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :branch, :string
    field :pr_url, :string
    field :labels, {:array, :string}, default: []
    field :estimate_minutes, :integer
    field :due_at, :utc_datetime
    field :review_id, :binary_id
    field :created_by_run_id, :binary_id
    field :checked_out_by_agent, :string
    field :checked_out_at, :utc_datetime
    field :checkout_expires_at, :utc_datetime

    timestamps()
  end

  @required ~w(title workspace_slug)a
  @optional ~w(short_id description status priority assignee_type assignee_id
               project_slug parent_id session_id dispatched_at completed_at
               branch pr_url labels estimate_minutes due_at review_id created_by_run_id
               checked_out_by_agent checked_out_at checkout_expires_at)a

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(issue, attrs) do
    issue
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:title, min: 1, max: 512)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:priority, Enum.to_list(@valid_priorities))
    |> validate_number(:estimate_minutes, greater_than: 0)
    |> validate_number(:priority, greater_than_or_equal_to: 0, less_than_or_equal_to: 4)
    |> unique_constraint(:short_id)
  end
end
