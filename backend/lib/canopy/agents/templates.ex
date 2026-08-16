defmodule Canopy.Agents.Templates do
  @moduledoc """
  Public API for the agent template marketplace.

  Templates are read-only presets. Cloning one via `from_template/1` inserts a
  real Agent row (hired: true) and creates AgentSkillAssignment rows for each
  skill_slug in the template.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Agents
  alias Canopy.Agents.Template
  alias Canopy.Repo
  alias Canopy.Skills.AgentSkillAssignment

  @doc """
  Returns all templates, ordered by sort_order then name.

  Options:
  - `:category` — filter to a single category string.
  """
  @spec list(keyword()) :: {:ok, [Template.t()]}
  def list(opts \\ []) do
    category_filter = Keyword.get(opts, :category)

    query =
      from(t in Template, order_by: [asc: t.sort_order, asc: t.name])
      |> apply_category_filter(category_filter)

    {:ok, Repo.all(query)}
  end

  @doc "Returns a template by slug, or `{:error, :not_found}`."
  @spec get_by_slug(String.t()) :: {:ok, Template.t()} | {:error, :not_found}
  def get_by_slug(slug) do
    case Repo.get_by(Template, slug: slug) do
      nil -> {:error, :not_found}
      template -> {:ok, template}
    end
  end

  @doc """
  Clones a template into a real hired agent.

  Accepts:
  - `template_slug` (required) — which template to clone
  - `name` (optional) — override the template's name
  - `slug` (optional) — override the generated slug (default: template slug)

  On success:
  1. Creates an Agent row with hired: true, copying template fields.
  2. Creates AgentSkillAssignment rows for each skill_slug.

  Returns `{:ok, agent}` or `{:error, reason}`.
  """
  @spec from_template(map()) ::
          {:ok, Canopy.Agents.Agent.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def from_template(%{"template_slug" => template_slug} = params) do
    with {:ok, template} <- get_by_slug(template_slug) do
      agent_name = Map.get(params, "name") || template.name
      agent_slug = Map.get(params, "slug") || template.slug

      agent_attrs = %{
        slug: agent_slug,
        name: agent_name,
        category: template.category,
        description: template.description,
        persona_markdown: template.persona_markdown,
        persona_path: "user/#{agent_slug}.md",
        default_runtime: template.default_runtime,
        default_model: template.default_model,
        config: %{"capabilities" => template.capabilities, "from_template" => template.slug}
      }

      with {:ok, agent} <- Agents.create(agent_attrs) do
        assign_skills(agent.slug, template.skill_slugs)
        {:ok, agent}
      end
    end
  end

  def from_template(_params), do: {:error, :template_slug_required}

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec apply_category_filter(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  defp apply_category_filter(query, nil), do: query

  defp apply_category_filter(query, category),
    do: from(t in query, where: t.category == ^category)

  @spec assign_skills(String.t(), [String.t()]) :: :ok
  defp assign_skills(_agent_slug, []), do: :ok

  defp assign_skills(agent_slug, skill_slugs) do
    skill_slugs
    |> Enum.with_index()
    |> Enum.each(fn {skill_slug, idx} ->
      %AgentSkillAssignment{}
      |> AgentSkillAssignment.changeset(%{
        agent_slug: agent_slug,
        skill_slug: skill_slug,
        priority: idx,
        enabled: true
      })
      |> Repo.insert(
        on_conflict: :nothing,
        conflict_target: [:agent_slug, :skill_slug]
      )
    end)

    :ok
  end
end
