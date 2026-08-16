defmodule Canopy.Agents.Template do
  @moduledoc """
  Ecto schema for an agent template (marketplace preset).

  Templates are read-only reference records seeded from seeds.exs. A user
  can clone a template into a real Agent row via `Canopy.Agents.Templates.from_template/1`.

  Fields mirror the Agent schema where they overlap; `capabilities` and
  `skill_slugs` are arrays that get applied during cloning.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  @derive {Jason.Encoder,
           only: [
             :id,
             :slug,
             :name,
             :description,
             :category,
             :persona_markdown,
             :default_runtime,
             :default_model,
             :capabilities,
             :skill_slugs,
             :icon,
             :color,
             :sort_order,
             :inserted_at,
             :updated_at
           ]}

  schema "agent_templates" do
    field :slug, :string
    field :name, :string
    field :description, :string
    field :category, :string
    field :persona_markdown, :string, default: ""
    field :default_runtime, :string
    field :default_model, :string
    field :capabilities, {:array, :string}, default: []
    field :skill_slugs, {:array, :string}, default: []
    field :icon, :string, default: "🤖"
    field :color, :string, default: "#6B7280"
    field :sort_order, :integer, default: 0

    timestamps()
  end

  @required ~w(slug name category)a
  @optional ~w(description persona_markdown default_runtime default_model capabilities skill_slugs icon color sort_order)a

  @doc "Changeset for creating or upserting a template."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(template, attrs) do
    template
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:slug, min: 1, max: 128)
    |> validate_format(:slug, ~r/\A[a-z0-9][a-z0-9\-]*[a-z0-9]\z|\A[a-z0-9]\z/)
    |> validate_length(:name, min: 1, max: 256)
    |> unique_constraint(:slug)
  end
end
