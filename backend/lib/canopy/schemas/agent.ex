defmodule Canopy.Schemas.Agent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "agents" do
    field :slug, :string
    field :name, :string
    field :role, :string
    field :adapter, :string
    field :model, :string
    field :temperature, :float, default: 0.3
    field :max_concurrent_runs, :integer, default: 1
    field :status, :string, default: "sleeping"
    field :config, :map, default: %{}
    field :system_prompt, :string
    field :avatar_emoji, :string, default: "🤖"

    belongs_to :workspace, Canopy.Schemas.Workspace
    belongs_to :reports_to_agent, Canopy.Schemas.Agent, foreign_key: :reports_to
    has_many :sessions, Canopy.Schemas.Session
    has_many :schedules, Canopy.Schemas.Schedule
    many_to_many :skills, Canopy.Schemas.Skill, join_through: "agent_skills"

    timestamps()
  end

  def changeset(agent, attrs) do
    agent
    |> cast(attrs, [:slug, :name, :role, :adapter, :model, :temperature, :max_concurrent_runs, :status, :config, :system_prompt, :workspace_id, :reports_to, :avatar_emoji])
    |> validate_required([:slug, :name, :role, :adapter, :model, :workspace_id])
    |> validate_inclusion(:status, ~w(active idle working sleeping error paused))
    |> validate_inclusion(:adapter, ~w(osa claude-code codex bash http openclaw cursor gemini))
    |> unique_constraint([:workspace_id, :slug])
  end
end
