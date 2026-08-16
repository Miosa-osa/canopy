defmodule Canopy.Skills.CuratorTest do
  @moduledoc """
  Tests for the Canopy.Skills.Curator extension module.

  Covers lockfile pinning, version recording, verification flow, and
  unverified-source discovery. The Curator wraps Canopy.Skills — every
  test seeds a real skill through the public Skills API first.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Skills
  alias Canopy.Skills.Curator
  alias Canopy.Skills.LockfileEntry
  alias Canopy.Skills.Version

  # Helper — creates a backing skill row before each test.
  defp create_skill(slug, opts \\ []) do
    {:ok, skill} =
      Skills.create(%{
        "slug" => slug,
        "name" => Keyword.get(opts, :name, slug),
        "content" => Keyword.get(opts, :content, "# #{slug}\n"),
        "source" => Keyword.get(opts, :source, "local"),
        "provider_format" => "generic"
      })

    skill
  end

  # ---------------------------------------------------------------------------
  # lock_skill / unlock_skill
  # ---------------------------------------------------------------------------

  describe "lock_skill/3" do
    test "creates a new lockfile entry" do
      _ = create_skill("test-skill")

      assert {:ok, %LockfileEntry{} = entry} =
               Curator.lock_skill("default", "test-skill", %{
                 locked_version: "1.0.0",
                 content_hash: "abc123"
               })

      assert entry.workspace_slug == "default"
      assert entry.skill_slug == "test-skill"
      assert entry.locked_version == "1.0.0"
      assert entry.content_hash == "abc123"
      assert entry.locked_by == "skill-curator"
      assert entry.locked_at != nil
    end

    test "updates an existing entry on second call (idempotent)" do
      _ = create_skill("retry-skill")

      assert {:ok, _} =
               Curator.lock_skill("default", "retry-skill", %{
                 locked_version: "1.0.0",
                 content_hash: "first"
               })

      assert {:ok, updated} =
               Curator.lock_skill("default", "retry-skill", %{
                 locked_version: "1.1.0",
                 content_hash: "second"
               })

      assert updated.locked_version == "1.1.0"
      assert updated.content_hash == "second"
      assert length(Curator.list_lockfile(workspace_slug: "default")) == 1
    end

    test "respects custom locked_by" do
      _ = create_skill("by-skill")

      assert {:ok, entry} =
               Curator.lock_skill("default", "by-skill", %{
                 locked_version: "1.0.0",
                 content_hash: "h",
                 locked_by: "rhl"
               })

      assert entry.locked_by == "rhl"
    end

    test "rejects missing required fields" do
      _ = create_skill("missing-fields")

      assert {:error, changeset} =
               Curator.lock_skill("default", "missing-fields", %{
                 # missing locked_version + content_hash
                 source: "local"
               })

      refute changeset.valid?
    end

    test "different workspaces hold separate locks for the same skill" do
      _ = create_skill("multi-ws")

      assert {:ok, _} =
               Curator.lock_skill("ws-a", "multi-ws", %{
                 locked_version: "1.0.0",
                 content_hash: "h1"
               })

      assert {:ok, _} =
               Curator.lock_skill("ws-b", "multi-ws", %{
                 locked_version: "2.0.0",
                 content_hash: "h2"
               })

      assert length(Curator.list_lockfile(skill_slug: "multi-ws")) == 2
    end
  end

  describe "unlock_skill/2" do
    test "removes an existing entry" do
      _ = create_skill("unlock-me")

      {:ok, _} =
        Curator.lock_skill("default", "unlock-me", %{
          locked_version: "1.0.0",
          content_hash: "h"
        })

      assert {:ok, _} = Curator.unlock_skill("default", "unlock-me")
      assert Curator.get_lock("default", "unlock-me") == nil
    end

    test "returns :not_found when no entry exists" do
      assert {:error, :not_found} = Curator.unlock_skill("default", "nope")
    end
  end

  describe "list_lockfile/1" do
    test "filters by workspace" do
      _ = create_skill("ws-filter-1")
      _ = create_skill("ws-filter-2")

      Curator.lock_skill("ws-1", "ws-filter-1", %{locked_version: "1", content_hash: "a"})
      Curator.lock_skill("ws-2", "ws-filter-2", %{locked_version: "1", content_hash: "b"})

      ws1 = Curator.list_lockfile(workspace_slug: "ws-1")
      assert length(ws1) == 1
      assert hd(ws1).workspace_slug == "ws-1"
    end

    test "filters by skill_slug" do
      _ = create_skill("slug-filter")

      Curator.lock_skill("ws-1", "slug-filter", %{locked_version: "1", content_hash: "a"})
      Curator.lock_skill("ws-2", "slug-filter", %{locked_version: "1", content_hash: "b"})

      results = Curator.list_lockfile(skill_slug: "slug-filter")
      assert length(results) == 2
    end

    test "respects limit" do
      _ = create_skill("limit-test")

      for i <- 1..5 do
        Curator.lock_skill("ws-#{i}", "limit-test", %{
          locked_version: "1",
          content_hash: "h#{i}"
        })
      end

      assert length(Curator.list_lockfile(limit: 2)) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # record_version / list_versions
  # ---------------------------------------------------------------------------

  describe "record_version/1 and list_versions/1" do
    test "records and lists versions newest first" do
      skill = create_skill("v-skill")

      assert {:ok, %Version{}} =
               Curator.record_version(%{
                 skill_id: skill.id,
                 skill_slug: skill.slug,
                 version: "1.0.0",
                 content_hash: "h1",
                 published_at: DateTime.utc_now()
               })

      Process.sleep(10)

      assert {:ok, %Version{}} =
               Curator.record_version(%{
                 skill_id: skill.id,
                 skill_slug: skill.slug,
                 version: "1.1.0",
                 content_hash: "h2",
                 published_at: DateTime.utc_now()
               })

      versions = Curator.list_versions("v-skill")
      assert length(versions) == 2
      assert Enum.map(versions, & &1.version) == ["1.1.0", "1.0.0"]
    end

    test "rejects duplicate (skill_id, version) pair" do
      skill = create_skill("dup-version")

      assert {:ok, _} =
               Curator.record_version(%{
                 skill_id: skill.id,
                 skill_slug: skill.slug,
                 version: "1.0.0",
                 content_hash: "h1"
               })

      assert {:error, changeset} =
               Curator.record_version(%{
                 skill_id: skill.id,
                 skill_slug: skill.slug,
                 version: "1.0.0",
                 content_hash: "h2"
               })

      refute changeset.valid?
    end

    test "auto-fills published_at when missing" do
      skill = create_skill("ts-skill")

      assert {:ok, version} =
               Curator.record_version(%{
                 skill_id: skill.id,
                 skill_slug: skill.slug,
                 version: "1.0.0",
                 content_hash: "h"
               })

      assert version.published_at != nil
    end
  end

  describe "get_version/2" do
    test "returns nil for unknown version" do
      assert Curator.get_version("nonexistent", "1.0.0") == nil
    end
  end

  # ---------------------------------------------------------------------------
  # verify / unverify
  # ---------------------------------------------------------------------------

  describe "verify_skill/2" do
    test "marks skill as verified" do
      _ = create_skill("verify-me")

      assert {:ok, payload} = Curator.verify_skill("verify-me", "rhl")
      assert payload.verified == true
      assert payload.verified_by == "rhl"
      assert payload.verified_at != nil
    end

    test "returns :not_found for unknown slug" do
      assert {:error, :not_found} = Curator.verify_skill("does-not-exist", "rhl")
    end

    test "verification persists and is readable via get_verification" do
      _ = create_skill("persist-me")

      Curator.verify_skill("persist-me", "rhl")
      v = Curator.get_verification("persist-me")

      assert v.verified == true
      assert v.verified_by == "rhl"
    end
  end

  describe "unverify_skill/1" do
    test "clears the verified flag" do
      _ = create_skill("clear-me")
      Curator.verify_skill("clear-me", "rhl")

      assert {:ok, payload} = Curator.unverify_skill("clear-me")
      assert payload.verified == false
      assert payload.verified_at == nil
    end

    test "returns :not_found for unknown slug" do
      assert {:error, :not_found} = Curator.unverify_skill("ghost")
    end
  end

  describe "find_unverified/1" do
    test "returns slugs of skills that have not been verified" do
      _ = create_skill("not-verified-1")
      _ = create_skill("not-verified-2")
      _ = create_skill("verified-skill")
      Curator.verify_skill("verified-skill", "rhl")

      slugs = Curator.find_unverified()
      assert "not-verified-1" in slugs
      assert "not-verified-2" in slugs
      refute "verified-skill" in slugs
    end

    test "respects limit" do
      for i <- 1..5 do
        create_skill("unverified-#{i}")
      end

      assert length(Curator.find_unverified(limit: 2)) == 2
    end
  end

  describe "install_requires_approval?/1" do
    test "returns true for unverified skill slug" do
      _ = create_skill("unver-skill")
      assert Curator.install_requires_approval?("unver-skill") == true
    end

    test "returns false for verified skill slug" do
      _ = create_skill("ver-skill")
      Curator.verify_skill("ver-skill", "rhl")
      assert Curator.install_requires_approval?("ver-skill") == false
    end

    test "returns true when slug is unknown" do
      assert Curator.install_requires_approval?("ghost-slug") == true
    end

    test "accepts a map with :verified key" do
      assert Curator.install_requires_approval?(%{verified: true}) == false
      assert Curator.install_requires_approval?(%{verified: false}) == true
    end
  end

  # ---------------------------------------------------------------------------
  # diff_versions
  # ---------------------------------------------------------------------------

  describe "diff_versions/3" do
    test "returns a structured diff for two known versions" do
      skill = create_skill("diff-test")

      Curator.record_version(%{
        skill_id: skill.id,
        skill_slug: "diff-test",
        version: "1.0.0",
        content_hash: "aaa"
      })

      Curator.record_version(%{
        skill_id: skill.id,
        skill_slug: "diff-test",
        version: "2.0.0",
        content_hash: "bbb"
      })

      assert {:ok, diff} = Curator.diff_versions("diff-test", "1.0.0", "2.0.0")
      assert diff.skill_slug == "diff-test"
      assert diff.hash_changed == true
      assert diff.from.version == "1.0.0"
      assert diff.to.version == "2.0.0"
    end

    test "hash_changed is false when content hash matches" do
      skill = create_skill("no-change")

      Curator.record_version(%{
        skill_id: skill.id,
        skill_slug: "no-change",
        version: "1.0.0",
        content_hash: "same"
      })

      Curator.record_version(%{
        skill_id: skill.id,
        skill_slug: "no-change",
        version: "1.0.1",
        content_hash: "same"
      })

      assert {:ok, diff} = Curator.diff_versions("no-change", "1.0.0", "1.0.1")
      assert diff.hash_changed == false
    end

    test "returns :not_found when either version is missing" do
      _ = create_skill("missing-diff")

      assert {:error, :not_found} =
               Curator.diff_versions("missing-diff", "1.0.0", "2.0.0")
    end
  end

  # ---------------------------------------------------------------------------
  # default_workspace
  # ---------------------------------------------------------------------------

  describe "default_workspace/0" do
    test "returns a known constant" do
      assert is_binary(Curator.default_workspace())
    end
  end
end
