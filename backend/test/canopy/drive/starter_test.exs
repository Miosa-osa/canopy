defmodule Canopy.Drive.StarterTest do
  @moduledoc """
  Tests for the Drive starter-content seeder.

  Asserts:
  - first run inserts the full set of expected entries
  - second run is a no-op (idempotent — slug-based skip)
  - parent/child hierarchy is wired correctly
  - per-kind body validation passes for every starter entry
  - `entries/0` returns a deterministic list
  """

  use Canopy.DataCase, async: true

  alias Canopy.Drive
  alias Canopy.Drive.Starter

  # ---------------------------------------------------------------------------
  # entries/0 — pure data
  # ---------------------------------------------------------------------------

  describe "entries/0" do
    test "is deterministic across calls" do
      assert Starter.entries() == Starter.entries()
    end

    test "every entry has the required keys" do
      for entry <- Starter.entries() do
        assert Map.has_key?(entry, :slug)
        assert Map.has_key?(entry, :name)
        assert Map.has_key?(entry, :kind)
        assert Map.has_key?(entry, :scope)
        assert Map.has_key?(entry, :parent_slug)
        assert Map.has_key?(entry, :body)
      end
    end

    test "all slugs are unique" do
      slugs = Enum.map(Starter.entries(), & &1.slug)
      assert length(slugs) == length(Enum.uniq(slugs))
    end

    test "all entries are personal scope" do
      for entry <- Starter.entries() do
        assert entry.scope == "personal"
      end
    end

    test "every parent_slug references a folder defined earlier in the list" do
      {_, valid?} =
        Enum.reduce(Starter.entries(), {MapSet.new(), true}, fn entry, {seen, ok?} ->
          parent_ok? =
            case entry.parent_slug do
              nil -> true
              slug -> MapSet.member?(seen, slug)
            end

          new_seen =
            if entry.kind == "folder", do: MapSet.put(seen, entry.slug), else: seen

          {new_seen, ok? and parent_ok?}
        end)

      assert valid?, "every non-root entry must have a parent_slug already seen as a folder"
    end

    test "kind breakdown is the documented count" do
      kinds = Starter.entries() |> Enum.frequencies_by(& &1.kind)

      assert kinds["folder"] == 4
      assert kinds["prompt"] == 6
      assert kinds["workflow"] == 3
      assert kinds["rule"] == 3
    end
  end

  # ---------------------------------------------------------------------------
  # seed!/0 — first run, second run, hierarchy
  # ---------------------------------------------------------------------------

  describe "seed!/0" do
    test "first run inserts the full starter set" do
      {inserted, skipped, errored} = Starter.seed!()

      total = length(Starter.entries())
      assert inserted == total
      assert skipped == 0
      assert errored == 0
    end

    test "is idempotent on second run" do
      {first_inserted, _, _} = Starter.seed!()
      {second_inserted, second_skipped, second_errored} = Starter.seed!()

      assert first_inserted == length(Starter.entries())
      assert second_inserted == 0
      assert second_skipped == length(Starter.entries())
      assert second_errored == 0
    end

    test "second run does not duplicate entries" do
      Starter.seed!()
      Starter.seed!()

      total_in_db = length(Drive.list(scope: "personal", limit: 1000))
      assert total_in_db == length(Starter.entries())
    end

    test "user edits to a starter entry are preserved on re-seed" do
      Starter.seed!()

      original = Drive.get_by_slug("explain-this-code", scope: "personal")
      refute is_nil(original)

      {:ok, edited} =
        Drive.update(original, %{
          body: %{
            "body" => "USER EDITED CONTENT",
            "variables" => []
          }
        })

      assert edited.body["body"] == "USER EDITED CONTENT"

      Starter.seed!()

      after_reseed = Drive.get_by_slug("explain-this-code", scope: "personal")
      assert after_reseed.body["body"] == "USER EDITED CONTENT"
    end
  end

  # ---------------------------------------------------------------------------
  # Hierarchy — folders link children correctly
  # ---------------------------------------------------------------------------

  describe "hierarchy" do
    setup do
      Starter.seed!()
      :ok
    end

    test "root contains the four starter folders plus the welcome prompt" do
      roots = Drive.list(scope: "personal", parent_id: :root, limit: 1000)
      slugs = Enum.map(roots, & &1.slug) |> Enum.sort()

      assert "starter-prompts" in slugs
      assert "starter-workflows" in slugs
      assert "starter-rules" in slugs
      assert "mcp-servers" in slugs
      assert "getting-started-with-canopy" in slugs
    end

    test "Starter prompts folder contains the 5 prompt entries" do
      parent = Drive.get_by_slug("starter-prompts", scope: "personal", parent_id: :root)
      refute is_nil(parent)

      children = Drive.list(scope: "personal", parent_id: parent.id, limit: 1000)
      slugs = Enum.map(children, & &1.slug) |> Enum.sort()

      assert slugs == [
               "explain-this-code",
               "find-performance-issues",
               "generate-tests-for-this-function",
               "refactor-for-readability",
               "write-commit-message"
             ]

      for child <- children do
        assert child.kind == "prompt"
      end
    end

    test "Starter workflows folder contains the 3 workflow placeholders" do
      parent = Drive.get_by_slug("starter-workflows", scope: "personal", parent_id: :root)
      children = Drive.list(scope: "personal", parent_id: parent.id, limit: 1000)
      slugs = Enum.map(children, & &1.slug) |> Enum.sort()

      assert slugs == [
               "run-all-tests",
               "squash-the-last-n-commits",
               "undo-last-git-commit"
             ]

      for child <- children do
        assert child.kind == "workflow"
        # body must include routine_id key for the changeset to validate
        assert Map.has_key?(child.body, "routine_id")
      end
    end

    test "Starter rules folder contains the 3 rule entries" do
      parent = Drive.get_by_slug("starter-rules", scope: "personal", parent_id: :root)
      children = Drive.list(scope: "personal", parent_id: parent.id, limit: 1000)
      slugs = Enum.map(children, & &1.slug) |> Enum.sort()

      assert slugs == [
               "always-use-parameterized-queries",
               "match-existing-code-style",
               "no-emojis-in-code"
             ]

      for child <- children do
        assert child.kind == "rule"
        assert is_binary(child.body["body"])
        assert is_list(child.body["applies_to"])
      end
    end

    test "MCP Servers folder is empty (placeholder for Phase B)" do
      parent = Drive.get_by_slug("mcp-servers", scope: "personal", parent_id: :root)
      children = Drive.list(scope: "personal", parent_id: parent.id, limit: 1000)
      assert children == []
    end
  end

  # ---------------------------------------------------------------------------
  # Per-kind body validation — every starter entry must satisfy the
  # changeset's per-kind requirements (otherwise seed!/0 errors).
  # ---------------------------------------------------------------------------

  describe "per-kind body shapes" do
    setup do
      Starter.seed!()
      :ok
    end

    test "every workflow entry has routine_id key (even if nil)" do
      workflows = Drive.list(scope: "personal", kind: "workflow", limit: 1000)
      assert length(workflows) == 3

      for w <- workflows do
        assert Map.has_key?(w.body, "routine_id"),
               "workflow #{w.slug} must have routine_id in body"
      end
    end

    test "every prompt entry has body and variables keys" do
      prompts = Drive.list(scope: "personal", kind: "prompt", limit: 1000)

      for p <- prompts do
        assert is_binary(p.body["body"]),
               "prompt #{p.slug} must have a string body"

        assert is_list(p.body["variables"]),
               "prompt #{p.slug} must have a list of variables"
      end
    end

    test "every rule entry has body and applies_to keys" do
      rules = Drive.list(scope: "personal", kind: "rule", limit: 1000)

      for r <- rules do
        assert is_binary(r.body["body"]),
               "rule #{r.slug} must have a string body"

        assert is_list(r.body["applies_to"]),
               "rule #{r.slug} must have applies_to list"
      end
    end

    test "no MCP server entries are created (placeholder folder only)" do
      mcp_entries = Drive.list(scope: "personal", kind: "mcp_server", limit: 1000)
      assert mcp_entries == []
    end
  end

  # ---------------------------------------------------------------------------
  # Error path — failed creates should be counted, not crash
  # ---------------------------------------------------------------------------

  describe "error handling" do
    test "pre-existing rows from a failed run are skipped on next run" do
      # Simulate: a prior run partially completed (only the folder exists).
      {:ok, _} =
        Drive.create(%{
          slug: "starter-prompts",
          name: "Starter prompts",
          kind: "folder",
          scope: "personal"
        })

      {inserted, skipped, errored} = Starter.seed!()

      # The folder is skipped, all 15 children get inserted.
      total = length(Starter.entries())
      assert skipped == 1
      assert inserted == total - 1
      assert errored == 0
    end
  end
end
