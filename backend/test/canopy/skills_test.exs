defmodule Canopy.SkillsTest do
  @moduledoc """
  Tests for the Canopy.Skills public API context module.
  Covers CRUD, filtering, bundle_key computation, and inject_for.
  """

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Skills

  # ---------------------------------------------------------------------------
  # list/1
  # ---------------------------------------------------------------------------

  describe "list/1" do
    test "returns empty list when no skills exist" do
      assert {:ok, []} = Skills.list()
    end

    test "returns all skills ordered by name" do
      insert(:skill, slug: "z-skill", name: "Zebra")
      insert(:skill, slug: "a-skill", name: "Alpha")
      assert {:ok, [first, second]} = Skills.list()
      assert first.name == "Alpha"
      assert second.name == "Zebra"
    end

    test "filters by source" do
      insert(:skill, slug: "local-skill", source: "local")
      insert(:skill, slug: "hub-skill", source: "clawhub")
      assert {:ok, skills} = Skills.list(source: "local")
      slugs = Enum.map(skills, & &1.slug)
      assert "local-skill" in slugs
      refute "hub-skill" in slugs
    end

    test "filters by enabled: true" do
      insert(:skill, slug: "on-skill", enabled: true)
      insert(:skill, slug: "off-skill", enabled: false)
      assert {:ok, skills} = Skills.list(enabled: true)
      slugs = Enum.map(skills, & &1.slug)
      assert "on-skill" in slugs
      refute "off-skill" in slugs
    end

    test "filters by enabled: false" do
      insert(:skill, slug: "en2-on", enabled: true)
      insert(:skill, slug: "en2-off", enabled: false)
      assert {:ok, skills} = Skills.list(enabled: false)
      slugs = Enum.map(skills, & &1.slug)
      refute "en2-on" in slugs
      assert "en2-off" in slugs
    end

    test "filters by tag" do
      insert(:skill, slug: "tagged-skill", tags: ["elixir", "backend"])
      insert(:skill, slug: "other-skill", tags: ["frontend"])
      assert {:ok, skills} = Skills.list(tag: "elixir")
      slugs = Enum.map(skills, & &1.slug)
      assert "tagged-skill" in slugs
      refute "other-skill" in slugs
    end

    test "combines source and enabled filters" do
      insert(:skill, slug: "c-en", source: "clawhub", enabled: true)
      insert(:skill, slug: "c-dis", source: "clawhub", enabled: false)
      insert(:skill, slug: "l-en", source: "local", enabled: true)
      assert {:ok, skills} = Skills.list(source: "clawhub", enabled: true)
      slugs = Enum.map(skills, & &1.slug)
      assert "c-en" in slugs
      refute "c-dis" in slugs
      refute "l-en" in slugs
    end
  end

  # ---------------------------------------------------------------------------
  # get_by_slug/1
  # ---------------------------------------------------------------------------

  describe "get_by_slug/1" do
    test "returns skill when found" do
      insert(:skill, slug: "found-me", name: "Found Me")
      assert {:ok, skill} = Skills.get_by_slug("found-me")
      assert skill.slug == "found-me"
      assert skill.name == "Found Me"
    end

    test "returns :not_found for unknown slug" do
      assert {:error, :not_found} = Skills.get_by_slug("no-such-skill-xyz")
    end
  end

  # ---------------------------------------------------------------------------
  # create/1
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "inserts a valid skill" do
      attrs = skill_attrs(slug: "created-skill")
      assert {:ok, skill} = Skills.create(attrs)
      assert skill.slug == "created-skill"
      assert skill.id != nil
    end

    test "auto-computes content_hash from content" do
      content = "# Auto hash test"
      attrs = Map.merge(skill_attrs(slug: "hash-skill"), %{"content" => content})
      # Remove explicit hash to let create compute it
      attrs = Map.delete(attrs, "content_hash")
      assert {:ok, skill} = Skills.create(attrs)
      expected = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
      assert skill.content_hash == expected
    end

    test "returns changeset error for invalid attrs" do
      assert {:error, %Ecto.Changeset{}} = Skills.create(%{"slug" => "bad slug!"})
    end

    test "enforces unique slug" do
      attrs = skill_attrs(slug: "unique-test")
      assert {:ok, _} = Skills.create(attrs)
      assert {:error, changeset} = Skills.create(attrs)
      assert "has already been taken" in errors_on(changeset).slug
    end
  end

  # ---------------------------------------------------------------------------
  # update/2
  # ---------------------------------------------------------------------------

  describe "update/2" do
    test "updates skill attributes" do
      skill = insert(:skill, slug: "to-update", name: "Old Name")
      assert {:ok, updated} = Skills.update(skill, %{"name" => "New Name"})
      assert updated.name == "New Name"
    end

    test "recomputes content_hash when content changes" do
      skill = insert(:skill, slug: "hash-update")
      new_content = "# Updated content"
      assert {:ok, updated} = Skills.update(skill, %{"content" => new_content})
      expected = :crypto.hash(:sha256, new_content) |> Base.encode16(case: :lower)
      assert updated.content_hash == expected
    end

    test "returns changeset error for invalid attrs" do
      skill = insert(:skill, slug: "update-invalid")
      assert {:error, %Ecto.Changeset{}} = Skills.update(skill, %{"slug" => "bad slug!"})
    end
  end

  # ---------------------------------------------------------------------------
  # delete/1
  # ---------------------------------------------------------------------------

  describe "delete/1" do
    test "removes a skill from the database" do
      skill = insert(:skill, slug: "to-delete")
      assert {:ok, _} = Skills.delete(skill)
      assert {:error, :not_found} = Skills.get_by_slug("to-delete")
    end
  end

  # ---------------------------------------------------------------------------
  # bundle_key/1
  # ---------------------------------------------------------------------------

  describe "bundle_key/1" do
    test "returns deterministic hash for a list of skills" do
      skill1 = insert(:skill, slug: "bk-1", content: "# Skill One")
      skill2 = insert(:skill, slug: "bk-2", content: "# Skill Two")
      assert {:ok, key1} = Skills.bundle_key([skill1, skill2])
      assert {:ok, key2} = Skills.bundle_key([skill2, skill1])
      # Order-independent due to slug-sort
      assert key1 == key2
    end

    test "returns a 64-char hex string (SHA256)" do
      skill = insert(:skill, slug: "bk-hex")
      assert {:ok, key} = Skills.bundle_key([skill])
      assert String.length(key) == 64
      assert key =~ ~r/\A[a-f0-9]+\z/
    end

    test "different content produces different keys" do
      skill1 = insert(:skill, slug: "bk-diff-1", content: "# Alpha")
      skill2 = insert(:skill, slug: "bk-diff-2", content: "# Beta")
      assert {:ok, key1} = Skills.bundle_key([skill1])
      assert {:ok, key2} = Skills.bundle_key([skill2])
      refute key1 == key2
    end

    test "empty list returns hash of empty string" do
      assert {:ok, key} = Skills.bundle_key([])
      expected = :crypto.hash(:sha256, "") |> Base.encode16(case: :lower)
      assert key == expected
    end

    test "accepts slugs and fetches enabled skills" do
      insert(:skill, slug: "bk-slug-1", content: "# Content A", enabled: true)
      insert(:skill, slug: "bk-slug-2", content: "# Content B", enabled: false)

      {:ok, struct1} = Skills.get_by_slug("bk-slug-1")
      assert {:ok, key_by_struct} = Skills.bundle_key([struct1])
      assert {:ok, key_by_slug} = Skills.bundle_key(["bk-slug-1"])

      # Only enabled skills are included when slugs provided — same result
      assert key_by_struct == key_by_slug
    end
  end

  # ---------------------------------------------------------------------------
  # inject_for/2
  # ---------------------------------------------------------------------------

  describe "inject_for/2" do
    test "returns empty string when no enabled skills exist" do
      result = Skills.inject_for("my-agent", "claude-local")
      assert result == ""
    end

    test "includes claude-format skills for claude-local runtime" do
      insert(:skill,
        slug: "cl-skill",
        name: "Claude Skill",
        provider_format: "claude",
        enabled: true
      )

      result = Skills.inject_for("my-agent", "claude-local")
      assert result =~ "Claude Skill"
    end

    test "includes generic skills for any runtime" do
      insert(:skill,
        slug: "gen-skill",
        name: "Generic Skill",
        provider_format: "generic",
        enabled: true
      )

      result = Skills.inject_for("my-agent", "codex-local")
      assert result =~ "Generic Skill"
    end

    test "excludes disabled skills" do
      insert(:skill,
        slug: "dis-skill",
        name: "Disabled",
        enabled: false,
        provider_format: "generic"
      )

      result = Skills.inject_for("my-agent", "claude-local")
      refute result =~ "Disabled"
    end

    test "includes skill name as heading" do
      insert(:skill,
        slug: "heading-skill",
        name: "My Heading Skill",
        provider_format: "generic",
        enabled: true
      )

      result = Skills.inject_for("some-agent", "unknown-runtime")
      assert result =~ "## Skill: My Heading Skill"
    end

    test "includes skill content body" do
      content = "Do the thing correctly."

      insert(:skill,
        slug: "content-skill",
        content: content,
        provider_format: "generic",
        enabled: true
      )

      result = Skills.inject_for("some-agent", "claude-local")
      assert result =~ content
    end
  end

  # ---------------------------------------------------------------------------
  # upsert/1
  # ---------------------------------------------------------------------------

  describe "upsert/1" do
    test "inserts when skill does not exist" do
      attrs = skill_attrs(slug: "upsert-new")
      assert {:ok, skill} = Skills.upsert(attrs)
      assert skill.slug == "upsert-new"
    end

    test "updates when skill already exists" do
      _existing = insert(:skill, slug: "upsert-existing", name: "Old")
      attrs = Map.merge(skill_attrs(slug: "upsert-existing"), %{"name" => "New"})
      assert {:ok, skill} = Skills.upsert(attrs)
      assert skill.name == "New"
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp skill_attrs(overrides) do
    overrides = Map.new(overrides, fn {k, v} -> {to_string(k), v} end)
    content = overrides["content"] || "# Default content"

    Map.merge(
      %{
        "slug" => "default-skill",
        "name" => "Default Skill",
        "content" => content,
        "content_hash" => :crypto.hash(:sha256, content) |> Base.encode16(case: :lower),
        "source" => "local",
        "provider_format" => "generic",
        "tags" => [],
        "enabled" => true
      },
      overrides
    )
  end
end
