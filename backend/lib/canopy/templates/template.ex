defmodule Canopy.Templates.Template do
  @moduledoc """
  A reusable scaffold managed by the Template Composer super-module.

  Three kinds of templates exist:

  - `"workspace"` — full workspace scaffold (folders + agent personas + skills +
    SYSTEM.md). Maps to the four starter kits already shipped under
    `priv/workspace_templates/` (sales-engine, dev-shop, content-factory, blank)
    and to user-published forks.
  - `"persona"` — a single agent persona (frontmatter + identity + tools +
    skills + governance). Used standalone or referenced from workspace
    templates.
  - `"workflow"` — a multi-agent pipeline definition (sequence + handoff
    rules). Materializes into a `pipelines.yaml` inside an instantiated
    workspace.

  ## Body shape

  The `:body` jsonb column is freeform per kind:

      # workspace
      %{
        "files" => [%{path, content, executable}],
        "agents" => [%{slug, persona_template_slug}],
        "skills" => [%{slug, source, version}],
        "system_md" => "..."
      }

      # persona
      %{
        "frontmatter" => %{...},
        "identity" => "...",
        "process" => "...",
        "deliverables" => "..."
      }

      # workflow
      %{
        "agents" => [%{role, persona_slug}],
        "tasks" => [%{slug, description, agent, expected_output}],
        "sequence" => [...]
      }

  ## Parameter schema

  The `:parameters` jsonb is a CrewAI-style declaration of substitutable
  variables resolved at instantiate time via Mustache `{{var}}` syntax:

      %{
        "workspace_name" => %{
          "type" => "string",
          "required" => true,
          "description" => "Slug of the new workspace"
        },
        "team_size" => %{
          "type" => "integer",
          "default" => 3,
          "required" => false
        }
      }

  ## Verification

  `:verified` flips true once a curator (Template Composer or Roberto) has
  reviewed for quality + safety. The `verified_by` + `verified_at` columns
  record the audit trail. Only verified templates are surfaced in the
  default gallery view.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @kinds ~w(workspace persona workflow)
  @sources ~w(local git imported user)

  @derive {Jason.Encoder,
           only: [
             :id,
             :slug,
             :name,
             :description,
             :kind,
             :body,
             :parameters,
             :version,
             :parent_template_id,
             :forked_from_slug,
             :verified,
             :verified_by,
             :verified_at,
             :published,
             :source,
             :source_url,
             :tags,
             :icon,
             :popularity_count,
             :created_by_agent_id,
             :inserted_at,
             :updated_at
           ]}

  schema "templates" do
    field :slug, :string
    field :name, :string
    field :description, :string
    field :kind, :string
    field :body, :map, default: %{}
    field :parameters, :map, default: %{}
    field :version, :string, default: "0.1.0"
    field :parent_template_id, :binary_id
    field :forked_from_slug, :string
    field :verified, :boolean, default: false
    field :verified_by, :string
    field :verified_at, :utc_datetime_usec
    field :published, :boolean, default: false
    field :source, :string, default: "local"
    field :source_url, :string
    field :tags, {:array, :string}, default: []
    field :icon, :string
    field :popularity_count, :integer, default: 0
    field :created_by_agent_id, :binary_id

    timestamps()
  end

  @required ~w(slug name kind)a
  @optional ~w(description body parameters version parent_template_id forked_from_slug verified verified_by verified_at published source source_url tags icon popularity_count created_by_agent_id)a

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:slug, max: 128)
    |> validate_length(:name, max: 256)
    |> validate_length(:version, max: 32)
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:source, @sources)
    |> validate_number(:popularity_count, greater_than_or_equal_to: 0)
    |> unique_constraint(:slug)
  end

  def kinds, do: @kinds
  def sources, do: @sources
end
