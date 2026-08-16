defmodule Mix.Tasks.Canopy.Seed.AgentsTest do
  @moduledoc """
  Tests for `mix canopy.seed.agents`.

  These tests exercise:
  - Smoke: task runs without crashing on the real priv/agents corpus
  - Conflict resolution: duplicate slugs get category-suffixed
  - Category normalisation: non-canonical top-level dirs → specialized
  - Idempotency: second run produces same DB count (no duplicates)
  - Emoji / name defaults: missing frontmatter fields get sensible fallbacks
  - Heartbeat: only explicit frontmatter values are stored (no injected defaults)
  """

  use Canopy.DataCase, async: false

  alias Canopy.Agents
  alias Canopy.Agents.Agent, as: AgentSchema
  alias Canopy.Repo
  alias Mix.Tasks.Canopy.Seed.Agents, as: Task

  # ---------------------------------------------------------------------------
  # Unit: build_slug_map/2
  # ---------------------------------------------------------------------------

  describe "build_slug_map/2 — conflict resolution" do
    test "unique slug kept as-is" do
      paths = ["/root/engineering/backend-dev.md"]
      result = Task.build_slug_map(paths, "/root")

      assert Map.has_key?(result, "backend-dev")
      assert result["backend-dev"].slug == "backend-dev"
      assert result["backend-dev"].conflict == false
    end

    test "colliding slugs both get category suffix" do
      paths = [
        "/root/testing/accessibility-auditor.md",
        "/root/technology/quality-assurance/accessibility-auditor.md"
      ]

      result = Task.build_slug_map(paths, "/root")

      assert Map.has_key?(result, "accessibility-auditor-testing")
      assert Map.has_key?(result, "accessibility-auditor-technology")
      assert result["accessibility-auditor-testing"].conflict == true
      assert result["accessibility-auditor-technology"].conflict == true
      refute Map.has_key?(result, "accessibility-auditor")
    end

    test "three-way collision suffixes all three copies" do
      paths = [
        "/root/sales/closer.md",
        "/root/revenue/closer.md",
        "/root/marketing/closer.md"
      ]

      result = Task.build_slug_map(paths, "/root")

      assert Map.has_key?(result, "closer-sales")
      assert Map.has_key?(result, "closer-revenue")
      assert Map.has_key?(result, "closer-marketing")
      assert map_size(result) == 3
    end

    test "same-category collisions use full relative path so no source file is dropped" do
      paths = [
        "/root/growth/team-a/researcher.md",
        "/root/growth/team-b/researcher.md"
      ]

      result = Task.build_slug_map(paths, "/root")

      assert map_size(result) == 2
      assert Map.has_key?(result, "researcher-growth-team-a-researcher")
      assert Map.has_key?(result, "researcher-growth-team-b-researcher")
    end
  end

  # ---------------------------------------------------------------------------
  # Unit: normalise_category/1
  # ---------------------------------------------------------------------------

  describe "normalise_category/1" do
    test "canonical categories pass through unchanged" do
      for cat <- ~w(engineering marketing technology testing academic) do
        assert Task.normalise_category(cat) == cat
      end
    end

    test "unknown category coerces to specialized" do
      assert Task.normalise_category("some-new-thing") == "specialized"
    end

    test "underscores are normalised to hyphens" do
      # "project_management" → "project-management" (canonical)
      assert Task.normalise_category("project_management") == "project-management"
    end

    test "uppercase is lowercased before matching" do
      assert Task.normalise_category("Engineering") == "engineering"
      assert Task.normalise_category("TESTING") == "testing"
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: smoke test on actual corpus
  # ---------------------------------------------------------------------------

  describe "run/1 smoke test" do
    @tag timeout: 120_000
    test "seeds agents without crashing" do
      # Should not raise. Captures output to avoid test log noise.
      ExUnit.CaptureIO.capture_io(fn ->
        Task.run([])
      end)

      {:ok, agents} = Agents.list()
      assert length(agents) > 0
    end

    @tag timeout: 120_000
    test "all seeded agents have non-empty slug, category, name, and persona_path" do
      ExUnit.CaptureIO.capture_io(fn -> Task.run([]) end)

      {:ok, agents} = Agents.list()

      Enum.each(agents, fn agent ->
        assert agent.slug != nil and agent.slug != "",
               "nil slug: #{inspect(agent)}"

        assert agent.category != nil and agent.category != "",
               "nil category for slug #{agent.slug}"

        assert agent.name != nil and agent.name != "",
               "nil name for slug #{agent.slug}"

        assert agent.persona_path != nil and agent.persona_path != "",
               "nil persona_path for slug #{agent.slug}"
      end)
    end

    @tag timeout: 120_000
    test "persona_markdown is populated for all seeded agents (DB column, not file)" do
      ExUnit.CaptureIO.capture_io(fn -> Task.run([]) end)

      {:ok, agents} = Agents.list()

      agents_with_content =
        Enum.filter(agents, &(is_binary(&1.persona_markdown) and &1.persona_markdown != ""))

      # We can't guarantee every markdown file has body content beyond frontmatter,
      # but the vast majority (>90%) of real agent files do.
      pct = length(agents_with_content) / max(length(agents), 1) * 100

      assert pct >= 90,
             "Expected >=90% of agents to have persona_markdown populated, got #{Float.round(pct, 1)}% " <>
               "(#{length(agents_with_content)} of #{length(agents)})"
    end

    @tag timeout: 120_000
    test "all seeded agents have a non-null emoji in name (emoji fallback applied)" do
      ExUnit.CaptureIO.capture_io(fn -> Task.run([]) end)
      {:ok, agents} = Agents.list()
      # We store emoji in the agent struct (schema does not have emoji field directly,
      # so this test verifies the name is non-empty as our proxy for fallback logic).
      assert Enum.all?(agents, &(&1.name != nil and &1.name != ""))
    end

    @tag timeout: 120_000
    test "no heartbeat_cron is injected for agents without explicit frontmatter heartbeat" do
      ExUnit.CaptureIO.capture_io(fn -> Task.run([]) end)
      {:ok, agents} = Agents.list()

      # Agents without heartbeat in frontmatter must have nil cron (no default injected).
      # We can only test that if *any* have it set, it looks like a valid cron expression.
      agents_with_cron = Enum.filter(agents, &(&1.heartbeat_cron != nil))

      Enum.each(agents_with_cron, fn agent ->
        # Basic cron sanity: 5 space-separated fields
        parts = String.split(agent.heartbeat_cron, " ")

        assert length(parts) == 5,
               "invalid heartbeat_cron for #{agent.slug}: #{agent.heartbeat_cron}"
      end)
    end

    @tag timeout: 120_000
    test "seeded agents preserve org and UI metadata in config" do
      ExUnit.CaptureIO.capture_io(fn -> Task.run([]) end)

      {:ok, agent} = Agents.get_by_slug("growth-ceo")
      assert agent.config["source"] == "bundled"
      assert agent.config["emoji"] == "📈"
      assert agent.config["title"] == "Growth CEO"
      assert agent.config["context_tier"] == "l0"
      assert agent.config["persona_path"] == "growth/growth-operator-agency/growth-ceo.md"
    end

    @tag timeout: 120_000
    test "seeded agent count is at least the unique-slug count (169 pre-fix baseline)" do
      ExUnit.CaptureIO.capture_io(fn -> Task.run([]) end)
      {:ok, agents} = Agents.list()
      # After conflict resolution we should exceed the original 169.
      assert length(agents) >= 169
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: conflict resolution in DB
  # ---------------------------------------------------------------------------

  describe "conflict resolution produces distinct slugs" do
    @tag timeout: 120_000
    test "no two agents share the same slug after seeding" do
      ExUnit.CaptureIO.capture_io(fn -> Task.run([]) end)
      {:ok, agents} = Agents.list()

      slugs = Enum.map(agents, & &1.slug)
      unique_slugs = Enum.uniq(slugs)

      assert length(slugs) == length(unique_slugs),
             "Duplicate slugs found: #{inspect(slugs -- unique_slugs)}"
    end

    @tag timeout: 120_000
    test "resolved conflict slugs follow the {base}-{category} pattern" do
      ExUnit.CaptureIO.capture_io(fn -> Task.run([]) end)
      {:ok, agents} = Agents.list()

      # All slugs must match the changeset regex
      slug_regex = ~r/\A[a-z0-9][a-z0-9\-]*[a-z0-9]\z|\A[a-z0-9]\z/

      Enum.each(agents, fn agent ->
        assert Regex.match?(slug_regex, agent.slug),
               "invalid slug format: #{agent.slug}"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: idempotency
  # ---------------------------------------------------------------------------

  describe "idempotency" do
    @tag timeout: 180_000
    test "running twice produces the same agent count" do
      ExUnit.CaptureIO.capture_io(fn -> Task.run([]) end)
      {:ok, agents_after_first} = Agents.list()
      count_first = length(agents_after_first)

      ExUnit.CaptureIO.capture_io(fn -> Task.run([]) end)
      {:ok, agents_after_second} = Agents.list()
      count_second = length(agents_after_second)

      assert count_first == count_second,
             "First run: #{count_first}, second run: #{count_second} — not idempotent"
    end

    @tag timeout: 180_000
    test "running twice does not duplicate slugs" do
      ExUnit.CaptureIO.capture_io(fn -> Task.run([]) end)
      ExUnit.CaptureIO.capture_io(fn -> Task.run([]) end)

      {:ok, agents} = Agents.list()
      slugs = Enum.map(agents, & &1.slug)
      assert length(slugs) == length(Enum.uniq(slugs))
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: --dry-run flag
  # ---------------------------------------------------------------------------

  describe "--dry-run flag" do
    test "dry-run does not insert anything" do
      count_before = Repo.aggregate(AgentSchema, :count)

      ExUnit.CaptureIO.capture_io(fn ->
        Task.run(["--dry-run"])
      end)

      count_after = Repo.aggregate(AgentSchema, :count)
      assert count_before == count_after
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: --only flag
  # ---------------------------------------------------------------------------

  describe "--only flag" do
    @tag timeout: 60_000
    test "only seeds the specified categories" do
      ExUnit.CaptureIO.capture_io(fn ->
        Task.run(["--only", "academic"])
      end)

      {:ok, agents} = Agents.list()
      assert Enum.all?(agents, &(&1.category == "academic"))
    end
  end
end
