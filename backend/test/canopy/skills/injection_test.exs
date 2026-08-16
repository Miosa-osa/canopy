defmodule Canopy.Skills.InjectionTest do
  @moduledoc """
  Unit tests for Canopy.Skills.Injection.

  Covers compose/1 (no context filter) and compose/2 (with context filter),
  including empty assignment sets, priority ordering, kind rendering,
  and frontmatter-based context filtering.
  """

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Skills
  alias Canopy.Skills.Injection

  # ---------------------------------------------------------------------------
  # compose/1 — no context filter
  # ---------------------------------------------------------------------------

  describe "compose/1 — no assigned skills" do
    test "returns empty string when agent has no assignments" do
      agent = insert(:agent)
      assert Injection.compose(agent) == ""
    end
  end

  describe "compose/1 — with assigned skills" do
    test "includes content of all enabled assigned skills" do
      agent = insert(:agent)

      skill =
        insert(:skill,
          slug: "injected-skill",
          name: "My Skill",
          content: "Do the thing.",
          enabled: true
        )

      {:ok, _} = Skills.assign(agent.slug, skill.slug)

      result = Injection.compose(agent)
      assert result =~ "My Skill"
      assert result =~ "Do the thing."
    end

    test "renders kind as capitalized heading label" do
      agent = insert(:agent)

      skill =
        insert(:skill,
          slug: "workflow-skill",
          name: "My Workflow",
          kind: "workflow",
          enabled: true
        )

      {:ok, _} = Skills.assign(agent.slug, skill.slug)

      result = Injection.compose(agent)
      assert result =~ "## Workflow: My Workflow"
    end

    test "renders prompt kind correctly" do
      agent = insert(:agent)

      skill =
        insert(:skill, slug: "prompt-skill-inj", name: "My Prompt", kind: "prompt", enabled: true)

      {:ok, _} = Skills.assign(agent.slug, skill.slug)

      result = Injection.compose(agent)
      assert result =~ "## Prompt: My Prompt"
    end

    test "orders skills by assignment priority ascending" do
      agent = insert(:agent)
      s1 = insert(:skill, slug: "prio-high", name: "High Priority", enabled: true)
      s2 = insert(:skill, slug: "prio-low", name: "Low Priority", enabled: true)
      {:ok, _} = Skills.assign(agent.slug, s1.slug, priority: 10)
      {:ok, _} = Skills.assign(agent.slug, s2.slug, priority: 0)

      result = Injection.compose(agent)
      low_pos = :binary.match(result, "Low Priority") |> elem(0)
      high_pos = :binary.match(result, "High Priority") |> elem(0)
      assert low_pos < high_pos
    end

    test "separates multiple skills with ---" do
      agent = insert(:agent)
      s1 = insert(:skill, slug: "sep-1", enabled: true)
      s2 = insert(:skill, slug: "sep-2", enabled: true)
      {:ok, _} = Skills.assign(agent.slug, s1.slug, priority: 0)
      {:ok, _} = Skills.assign(agent.slug, s2.slug, priority: 1)

      result = Injection.compose(agent)
      assert result =~ "---"
    end

    test "excludes disabled skills" do
      agent = insert(:agent)
      enabled_skill = insert(:skill, slug: "inj-enabled", name: "Enabled Skill", enabled: true)

      disabled_skill =
        insert(:skill, slug: "inj-disabled", name: "Disabled Skill", enabled: false)

      {:ok, _} = Skills.assign(agent.slug, enabled_skill.slug)
      {:ok, _} = Skills.assign(agent.slug, disabled_skill.slug)

      result = Injection.compose(agent)
      assert result =~ "Enabled Skill"
      refute result =~ "Disabled Skill"
    end

    test "excludes skills with disabled assignment" do
      agent = insert(:agent)

      skill =
        insert(:skill, slug: "dis-assign-skill", name: "Assigned But Disabled", enabled: true)

      {:ok, assignment} = Skills.assign(agent.slug, skill.slug)

      # Manually disable the assignment
      assignment
      |> Canopy.Skills.AgentSkillAssignment.changeset(%{enabled: false})
      |> Canopy.Repo.update!()

      result = Injection.compose(agent)
      refute result =~ "Assigned But Disabled"
    end
  end

  # ---------------------------------------------------------------------------
  # compose/2 — with context filter
  # ---------------------------------------------------------------------------

  describe "compose/2 — context filter" do
    test "includes skills with matching when frontmatter" do
      agent = insert(:agent)

      skill =
        insert(:skill,
          slug: "ctx-match",
          name: "Context Match",
          frontmatter: %{"when" => "code-review"},
          enabled: true
        )

      {:ok, _} = Skills.assign(agent.slug, skill.slug)

      result = Injection.compose(agent, "code-review")
      assert result =~ "Context Match"
    end

    test "excludes skills with non-matching when frontmatter" do
      agent = insert(:agent)

      skill =
        insert(:skill,
          slug: "ctx-no-match",
          name: "No Match",
          frontmatter: %{"when" => "debugging"},
          enabled: true
        )

      {:ok, _} = Skills.assign(agent.slug, skill.slug)

      result = Injection.compose(agent, "code-review")
      refute result =~ "No Match"
    end

    test "includes skills with no when key regardless of context" do
      agent = insert(:agent)

      skill_no_when =
        insert(:skill,
          slug: "ctx-no-when",
          name: "No When Key",
          frontmatter: %{"author" => "Roberto"},
          enabled: true
        )

      skill_nil_fm =
        insert(:skill,
          slug: "ctx-nil-fm",
          name: "Nil Frontmatter",
          frontmatter: nil,
          enabled: true
        )

      {:ok, _} = Skills.assign(agent.slug, skill_no_when.slug)
      {:ok, _} = Skills.assign(agent.slug, skill_nil_fm.slug)

      result = Injection.compose(agent, "code-review")
      assert result =~ "No When Key"
      assert result =~ "Nil Frontmatter"
    end

    test "returns empty string when no skills match context" do
      agent = insert(:agent)

      skill =
        insert(:skill,
          slug: "ctx-wrong",
          name: "Wrong Context",
          frontmatter: %{"when" => "deploy"},
          enabled: true
        )

      {:ok, _} = Skills.assign(agent.slug, skill.slug)

      result = Injection.compose(agent, "code-review")
      assert result == ""
    end
  end
end
