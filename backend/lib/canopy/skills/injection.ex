defmodule Canopy.Skills.Injection do
  @moduledoc """
  Composes an agent's assigned skills into a single markdown string for
  injection into the agent's system prompt.

  ## Usage

      # All assigned skills for an agent (no context filter):
      Injection.compose(agent)

      # Filter by frontmatter context tag (e.g. only skills whose `when` matches):
      Injection.compose(agent, "code-review")

  Skills are ordered by assignment priority (ascending) then by skill slug as a
  stable tiebreaker. Only enabled assignments and enabled skills are included.

  Returns an empty string when the agent has no assigned skills — safe to
  concatenate directly with the persona markdown.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Repo
  alias Canopy.Skills.AgentSkillAssignment
  alias Canopy.Skills.Skill

  @doc """
  Builds the composed skill markdown for `agent`.

  `agent` must have a `:slug` field (accepts an Agent struct or any map/struct
  with a `:slug` key).

  Returns a markdown string. Empty string when no skills are assigned.
  """
  @spec compose(map()) :: String.t()
  def compose(agent), do: compose(agent, nil)

  @doc """
  Builds the composed skill markdown for `agent`, optionally filtered by
  frontmatter context tag.

  When `context` is non-nil, only skills whose `frontmatter["when"]` matches
  `context` (or skills with no `when` key in frontmatter) are included.
  """
  @spec compose(map(), String.t() | nil) :: String.t()
  def compose(%{slug: agent_slug}, context) do
    agent_slug
    |> load_assigned_skills()
    |> filter_by_context(context)
    |> render_all()
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec load_assigned_skills(String.t()) :: [Skill.t()]
  defp load_assigned_skills(agent_slug) do
    Repo.all(
      from(a in AgentSkillAssignment,
        join: s in Skill,
        on: s.slug == a.skill_slug,
        where: a.agent_slug == ^agent_slug and a.enabled == true and s.enabled == true,
        order_by: [asc: a.priority, asc: s.slug],
        select: s
      )
    )
  end

  @spec filter_by_context([Skill.t()], String.t() | nil) :: [Skill.t()]
  defp filter_by_context(skills, nil), do: skills

  defp filter_by_context(skills, context) do
    Enum.filter(skills, fn skill ->
      case skill.frontmatter do
        %{"when" => tag} -> tag == context
        _ -> true
      end
    end)
  end

  @spec render_all([Skill.t()]) :: String.t()
  defp render_all([]), do: ""

  defp render_all(skills) do
    skills
    |> Enum.map_join("\n\n---\n\n", &render_skill/1)
  end

  @spec render_skill(Skill.t()) :: String.t()
  defp render_skill(skill) do
    kind_label = String.capitalize(skill.kind)

    """
    ## #{kind_label}: #{skill.name}

    #{String.trim(skill.content)}
    """
    |> String.trim_trailing()
  end
end
