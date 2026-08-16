defmodule Canopy.DriveTest do
  @moduledoc """
  Tests for the Canopy.Drive public API.

  Covers CRUD, tree assembly, move/cycle prevention, reorder, search,
  scope isolation, and validation of polymorphic body shapes.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Drive
  alias Canopy.Drive.Entry

  defp folder!(attrs \\ %{}) do
    {:ok, entry} =
      Drive.create(
        Map.merge(
          %{
            slug: "f-#{System.unique_integer([:positive])}",
            name: "Folder",
            kind: "folder",
            scope: "personal"
          },
          attrs
        )
      )

    entry
  end

  # ---------------------------------------------------------------------------
  # create/1
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "creates a minimal folder entry" do
      assert {:ok, %Entry{} = e} =
               Drive.create(%{
                 slug: "my-folder",
                 name: "My Folder",
                 kind: "folder",
                 scope: "personal"
               })

      assert e.kind == "folder"
      assert e.scope == "personal"
      assert e.position == 0
    end

    test "auto-assigns next position within (scope, parent)" do
      _a = folder!(%{slug: "a"})
      _b = folder!(%{slug: "b"})
      c = folder!(%{slug: "c"})

      assert c.position == 2
    end

    test "rejects invalid kind" do
      assert {:error, cs} =
               Drive.create(%{
                 slug: "x",
                 name: "X",
                 kind: "nope",
                 scope: "personal"
               })

      assert "is invalid" in errors_on(cs).kind
    end

    test "rejects invalid scope" do
      assert {:error, cs} =
               Drive.create(%{
                 slug: "x",
                 name: "X",
                 kind: "folder",
                 scope: "global"
               })

      assert "is invalid" in errors_on(cs).scope
    end

    test "rejects malformed slug" do
      assert {:error, cs} =
               Drive.create(%{
                 slug: "Bad Slug!",
                 name: "X",
                 kind: "folder",
                 scope: "personal"
               })

      refute Enum.empty?(errors_on(cs).slug)
    end

    test "rejects workflow without routine_id in body" do
      assert {:error, cs} =
               Drive.create(%{
                 slug: "wf",
                 name: "WF",
                 kind: "workflow",
                 scope: "personal",
                 body: %{}
               })

      refute Enum.empty?(errors_on(cs).body)
    end

    test "accepts workflow with routine_id" do
      assert {:ok, e} =
               Drive.create(%{
                 slug: "wf",
                 name: "WF",
                 kind: "workflow",
                 scope: "personal",
                 body: %{"routine_id" => Ecto.UUID.generate()}
               })

      assert e.kind == "workflow"
    end

    test "rejects notebook without session_id" do
      assert {:error, cs} =
               Drive.create(%{
                 slug: "nb",
                 name: "NB",
                 kind: "notebook",
                 scope: "personal",
                 body: %{}
               })

      refute Enum.empty?(errors_on(cs).body)
    end

    test "rejects env_vars without vault_secret_ids" do
      assert {:error, cs} =
               Drive.create(%{
                 slug: "ev",
                 name: "EV",
                 kind: "env_vars",
                 scope: "personal",
                 body: %{}
               })

      refute Enum.empty?(errors_on(cs).body)
    end

    test "accepts prompt with arbitrary body" do
      assert {:ok, e} =
               Drive.create(%{
                 slug: "p",
                 name: "P",
                 kind: "prompt",
                 scope: "personal",
                 body: %{"body" => "hello", "variables" => []}
               })

      assert e.body["body"] == "hello"
    end

    test "rejects duplicate slug within same (scope, parent)" do
      assert {:ok, _} =
               Drive.create(%{
                 slug: "dup",
                 name: "A",
                 kind: "folder",
                 scope: "personal"
               })

      assert {:error, cs} =
               Drive.create(%{
                 slug: "dup",
                 name: "B",
                 kind: "folder",
                 scope: "personal"
               })

      refute Enum.empty?(errors_on(cs).slug)
    end

    test "permits duplicate slug across scopes" do
      assert {:ok, _} =
               Drive.create(%{
                 slug: "shared",
                 name: "P",
                 kind: "folder",
                 scope: "personal"
               })

      assert {:ok, _} =
               Drive.create(%{
                 slug: "shared",
                 name: "T",
                 kind: "folder",
                 scope: "team"
               })
    end
  end

  # ---------------------------------------------------------------------------
  # list/1, get/1
  # ---------------------------------------------------------------------------

  describe "list/1 and get/1" do
    setup do
      personal = folder!(%{slug: "p-root", scope: "personal"})
      team = folder!(%{slug: "t-root", scope: "team"})

      child =
        folder!(%{
          slug: "p-child",
          scope: "personal",
          parent_id: personal.id
        })

      {:ok, personal: personal, team: team, child: child}
    end

    test "filters by scope", %{personal: _, team: team} do
      results = Drive.list(scope: "team")
      assert length(results) == 1
      assert hd(results).id == team.id
    end

    test "filters by parent_id", %{personal: personal, child: child} do
      results = Drive.list(scope: "personal", parent_id: personal.id)
      assert length(results) == 1
      assert hd(results).id == child.id
    end

    test "filters by parent_id=:root", %{personal: personal} do
      results = Drive.list(scope: "personal", parent_id: :root)
      assert length(results) == 1
      assert hd(results).id == personal.id
    end

    test "filters by kind" do
      _f = folder!()

      {:ok, _p} =
        Drive.create(%{
          slug: "pmt",
          name: "P",
          kind: "prompt",
          scope: "personal",
          body: %{"body" => "x"}
        })

      results = Drive.list(kind: "prompt")
      assert length(results) == 1
      assert hd(results).kind == "prompt"
    end

    test "excludes archived by default", %{personal: personal} do
      {:ok, _} = Drive.archive(personal)

      ids = Drive.list(scope: "personal") |> Enum.map(& &1.id)
      refute personal.id in ids
    end

    test "includes archived when archived=:all", %{personal: personal} do
      {:ok, _} = Drive.archive(personal)

      ids = Drive.list(scope: "personal", archived: :all) |> Enum.map(& &1.id)
      assert personal.id in ids
    end

    test "get/1 returns nil for unknown id" do
      assert is_nil(Drive.get(Ecto.UUID.generate()))
    end
  end

  # ---------------------------------------------------------------------------
  # archive/1, restore/1
  # ---------------------------------------------------------------------------

  describe "archive/1 and restore/1" do
    test "archive sets archived_at" do
      e = folder!()
      assert is_nil(e.archived_at)

      assert {:ok, archived} = Drive.archive(e)
      refute is_nil(archived.archived_at)
    end

    test "restore clears archived_at" do
      e = folder!()
      {:ok, archived} = Drive.archive(e)

      assert {:ok, restored} = Drive.restore(archived)
      assert is_nil(restored.archived_at)
    end
  end

  # ---------------------------------------------------------------------------
  # move/2
  # ---------------------------------------------------------------------------

  describe "move/2" do
    test "moves entry under new parent" do
      a = folder!(%{slug: "a"})
      b = folder!(%{slug: "b"})

      assert {:ok, moved} = Drive.move(b, a.id)
      assert moved.parent_id == a.id
    end

    test "moves entry to root with :root" do
      a = folder!(%{slug: "a"})
      b = folder!(%{slug: "b", parent_id: a.id})

      assert {:ok, moved} = Drive.move(b, :root)
      assert is_nil(moved.parent_id)
    end

    test "rejects self-move (cycle)" do
      a = folder!(%{slug: "a"})
      assert {:error, :cycle} = Drive.move(a, a.id)
    end

    test "rejects descendant becoming ancestor" do
      a = folder!(%{slug: "a"})
      b = folder!(%{slug: "b", parent_id: a.id})

      # Trying to move A under B (its own descendant) → cycle.
      assert {:error, :cycle} = Drive.move(a, b.id)
    end
  end

  # ---------------------------------------------------------------------------
  # reorder/2
  # ---------------------------------------------------------------------------

  describe "reorder/2" do
    test "writes new positions in batch" do
      a = folder!(%{slug: "a"})
      b = folder!(%{slug: "b"})
      c = folder!(%{slug: "c"})

      assert {:ok, 3} = Drive.reorder(:any, [c.id, a.id, b.id])

      assert Drive.get(c.id).position == 0
      assert Drive.get(a.id).position == 1
      assert Drive.get(b.id).position == 2
    end

    test "accepts {id, pos} pairs" do
      a = folder!(%{slug: "a"})
      assert {:ok, 1} = Drive.reorder(:any, [{a.id, 99}])
      assert Drive.get(a.id).position == 99
    end

    test "rolls back on unknown id" do
      a = folder!(%{slug: "a"})
      missing = Ecto.UUID.generate()

      assert {:error, :not_found} = Drive.reorder(:any, [a.id, missing])
      # a.position still 0 — full rollback
      assert Drive.get(a.id).position == 0
    end
  end

  # ---------------------------------------------------------------------------
  # tree/1
  # ---------------------------------------------------------------------------

  describe "tree/1" do
    test "builds nested structure" do
      a = folder!(%{slug: "a"})
      b = folder!(%{slug: "b", parent_id: a.id})
      _c = folder!(%{slug: "c", parent_id: b.id})

      [%{entry: top, children: [%{entry: mid, children: [%{entry: leaf}]}]}] =
        Drive.tree(scope: "personal")

      assert top.slug == "a"
      assert mid.slug == "b"
      assert leaf.slug == "c"
    end

    test "scope isolation — team tree omits personal entries" do
      _p = folder!(%{slug: "personal-only", scope: "personal"})
      _t = folder!(%{slug: "team-only", scope: "team"})

      [%{entry: only}] = Drive.tree(scope: "team")
      assert only.slug == "team-only"
    end

    test "excludes archived by default" do
      a = folder!(%{slug: "live"})
      hidden = folder!(%{slug: "gone"})
      {:ok, _} = Drive.archive(hidden)

      tree = Drive.tree(scope: "personal")
      slugs = Enum.map(tree, & &1.entry.slug)
      assert "live" in slugs
      refute "gone" in slugs
      _ = a
    end
  end

  # ---------------------------------------------------------------------------
  # search/2
  # ---------------------------------------------------------------------------

  describe "search/2" do
    test "matches against name" do
      _ = folder!(%{slug: "a", name: "Apple"})
      _ = folder!(%{slug: "b", name: "Banana"})

      [match] = Drive.search("apple")
      assert match.name == "Apple"
    end

    test "matches against body" do
      {:ok, _} =
        Drive.create(%{
          slug: "p1",
          name: "Boring",
          kind: "prompt",
          scope: "personal",
          body: %{"body" => "find-me-here"}
        })

      [match] = Drive.search("find-me-here")
      assert match.slug == "p1"
    end

    test "scope filter" do
      _ = folder!(%{slug: "p1", name: "Match", scope: "personal"})
      _ = folder!(%{slug: "t1", name: "Match", scope: "team"})

      results = Drive.search("Match", scope: "team")
      assert length(results) == 1
      assert hd(results).scope == "team"
    end
  end

  # ---------------------------------------------------------------------------
  # get_by_slug/2
  # ---------------------------------------------------------------------------

  describe "get_by_slug/2" do
    test "returns nil when missing" do
      assert is_nil(Drive.get_by_slug("not-real"))
    end

    test "returns first match" do
      e = folder!(%{slug: "found"})
      assert match = Drive.get_by_slug("found")
      assert match.id == e.id
    end

    test "scope filter disambiguates" do
      _p = folder!(%{slug: "shared", scope: "personal"})
      t = folder!(%{slug: "shared", scope: "team"})

      result = Drive.get_by_slug("shared", scope: "team")
      assert result.id == t.id
    end
  end
end
