defmodule Canopy.Runtimes.RuntimeModel do
  @moduledoc """
  Ecto schema for a model offered by a specific runtime.

  A `RuntimeModel` record represents one model option (e.g., `claude-sonnet-4-6`)
  available for a given `Runtime`. Cost fields use decimal precision to avoid
  floating-point rounding errors. Only one model per runtime may be marked as
  `is_default: true` — the API layer enforces this at the context level.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @derive {Jason.Encoder,
           only: [
             :id,
             :runtime_id,
             :model_id,
             :display_name,
             :context_window,
             :input_cost_per_mtok,
             :output_cost_per_mtok,
             :supports_thinking,
             :supports_tools,
             :supports_vision,
             :is_default,
             :inserted_at,
             :updated_at
           ]}

  schema "runtime_models" do
    belongs_to :runtime, Canopy.Runtimes.Runtime

    field :model_id, :string
    field :display_name, :string
    field :context_window, :integer
    field :input_cost_per_mtok, :decimal
    field :output_cost_per_mtok, :decimal
    field :supports_thinking, :boolean, default: false
    field :supports_tools, :boolean, default: true
    field :supports_vision, :boolean, default: false
    field :is_default, :boolean, default: false

    timestamps()
  end

  @required ~w(runtime_id model_id display_name)a
  @optional ~w(
    context_window input_cost_per_mtok output_cost_per_mtok
    supports_thinking supports_tools supports_vision is_default
  )a

  @doc "Changeset for creating or updating a runtime model record."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(model, attrs) do
    model
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:model_id, min: 1, max: 128)
    |> validate_length(:display_name, min: 1, max: 256)
    |> validate_number(:context_window, greater_than: 0)
    |> unique_constraint([:runtime_id, :model_id])
  end
end
