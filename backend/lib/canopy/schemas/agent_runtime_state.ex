defmodule Canopy.Schemas.AgentRuntimeState do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "agent_runtime_states" do
    field :session_id, :string
    field :workspace_path, :string
    field :last_run_at, :utc_datetime

    belongs_to :agent, Canopy.Schemas.Agent

    timestamps(type: :utc_datetime)
  end

  def changeset(state, attrs) do
    state
    |> cast(attrs, [:agent_id, :session_id, :workspace_path, :last_run_at])
    |> validate_required([:agent_id])
    |> foreign_key_constraint(:agent_id)
    |> unique_constraint(:agent_id)
  end
end
