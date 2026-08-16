defmodule Canopy.Agents.Agent do
  @moduledoc """
  Ecto schema for a Canopy agent persona.

  An agent is a persona defined in a markdown file under `priv/agents/`. The
  `slug` matches the filename (without extension) and serves as the stable
  public identifier. The `persona_path` is relative to `priv/agents/` and
  acts as a backward reference to the seed source file.

  ## Persona storage (Week 2+ / Track #68)

  `persona_markdown` is the authoritative runtime value for an agent's persona
  content. It is populated by `mix canopy.seed.agents` (body extracted from the
  markdown file after the YAML frontmatter block) and updated at runtime via
  `Canopy.Agents.update_persona/2` which writes directly to this DB column.

  The file at `persona_path` is the seed source only — it is never read at
  runtime. Do NOT use `File.read(persona_path)` in production code; read
  `agent.persona_markdown` from the already-loaded DB row instead.

  Hiring an agent (`hired: true`) means the user has opted in: the heartbeat
  scheduler will activate, and the agent appears in the runtime dashboard.
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
             :persona_markdown,
             :default_runtime,
             :default_model,
             :heartbeat_cron,
             :budget_monthly_usd,
             :hired,
             :config,
             :inserted_at,
             :updated_at
           ]}

  schema "agents" do
    field :slug, :string
    field :category, :string
    field :name, :string
    field :description, :string
    field :persona_path, :string
    # Authoritative runtime persona content. Supersedes the file at persona_path.
    # Populated by mix canopy.seed.agents; updated via Agents.update_persona/2.
    field :persona_markdown, :string, default: ""
    field :default_runtime, :string
    field :default_model, :string
    field :heartbeat_cron, :string
    field :budget_monthly_usd, :decimal
    field :hired, :boolean, default: false
    # config holds orchestration settings, e.g. %{"capabilities" => ["write_tasks", ...]}
    field :config, :map, default: %{}

    timestamps()
  end

  @required ~w(slug category name persona_path)a
  @optional ~w(description persona_markdown default_runtime default_model heartbeat_cron budget_monthly_usd hired config)a

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

  @doc """
  Changeset for updating the persona markdown content.

  Sets `persona_markdown` only — does not touch any other field.
  The caller is responsible for loading the agent row before calling this.
  """
  @spec persona_changeset(%__MODULE__{}, String.t()) :: Ecto.Changeset.t()
  def persona_changeset(agent, content) when is_binary(content) do
    agent
    |> cast(%{persona_markdown: content}, [:persona_markdown])
  end
end
