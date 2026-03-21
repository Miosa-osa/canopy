defmodule Canopy.Schemas.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sessions" do
    field :model, :string
    field :status, :string, default: "active"
    field :tokens_input, :integer, default: 0
    field :tokens_output, :integer, default: 0
    field :tokens_cache, :integer, default: 0
    field :cost_cents, :integer, default: 0
    field :workspace_path, :string
    field :workspace_branch, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :agent, Canopy.Schemas.Agent
    belongs_to :schedule, Canopy.Schemas.Schedule
    belongs_to :issue, Canopy.Schemas.Issue
    has_many :events, Canopy.Schemas.SessionEvent

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:model, :status, :tokens_input, :tokens_output, :tokens_cache, :cost_cents, :workspace_path, :workspace_branch, :started_at, :completed_at, :agent_id, :schedule_id, :issue_id])
    |> validate_required([:model, :started_at, :agent_id])
    |> validate_inclusion(:status, ~w(active idle completed failed cancelled))
  end
end
