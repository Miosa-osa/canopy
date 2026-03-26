defmodule Canopy.Schemas.CostEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "cost_events" do
    field :model, :string
    field :tokens_input, :integer, default: 0
    field :tokens_output, :integer, default: 0
    field :tokens_cache, :integer, default: 0
    field :cost_cents, :integer, default: 0
    field :inserted_at, :utc_datetime

    belongs_to :agent, Canopy.Schemas.Agent
    belongs_to :session, Canopy.Schemas.Session
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :model,
      :tokens_input,
      :tokens_output,
      :tokens_cache,
      :cost_cents,
      :agent_id,
      :session_id,
      :inserted_at
    ])
    |> validate_required([:model, :agent_id])
  end
end
