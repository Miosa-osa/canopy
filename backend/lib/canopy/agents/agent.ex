defmodule Canopy.Agents.Agent do
  @moduledoc """
  Ecto schema for a Canopy agent persona (Week 1 stub).

  An agent is a persona defined in a markdown file under `priv/agents/`. The
  `slug` matches the filename (without extension) and serves as the stable
  public identifier. The `persona_path` is relative to `priv/agents/`.

  Hiring an agent (`hired: true`) means the user has opted in: the heartbeat
  scheduler will activate, and the agent appears in the runtime dashboard.

  Full heartbeat scheduling (Oban cron) is Week 2 scope.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @derive {Jason.Encoder,
           only: [
             :id,
             :slug,
             :category,
             :name,
             :description,
             :persona_path,
             :default_runtime,
             :default_model,
             :heartbeat_cron,
             :budget_monthly_usd,
             :hired,
             :inserted_at,
             :updated_at
           ]}

  schema "agents" do
    field :slug, :string
    field :category, :string
    field :name, :string
    field :description, :string
    field :persona_path, :string
    field :default_runtime, :string
    field :default_model, :string
    field :heartbeat_cron, :string
    field :budget_monthly_usd, :decimal
    field :hired, :boolean, default: false

    timestamps()
  end

  @required ~w(slug category name persona_path)a
  @optional ~w(description default_runtime default_model heartbeat_cron budget_monthly_usd hired)a

  @doc "Changeset for creating or updating an agent."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(agent, attrs) do
    agent
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:slug, min: 1, max: 128)
    |> validate_format(:slug, ~r/\A[a-z0-9][a-z0-9\-]*[a-z0-9]\z|\A[a-z0-9]\z/)
    |> validate_length(:name, min: 1, max: 256)
    |> unique_constraint(:slug)
  end

  @doc "Changeset for toggling hired status."
  @spec hire_changeset(%__MODULE__{}, boolean()) :: Ecto.Changeset.t()
  def hire_changeset(agent, hired) do
    agent
    |> cast(%{hired: hired}, [:hired])
    |> validate_required([:hired])
  end
end
