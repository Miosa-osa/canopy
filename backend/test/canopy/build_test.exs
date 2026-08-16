defmodule Canopy.BuildTest do
  @moduledoc """
  Tests for the Canopy.Build public API context.

  Covers layout CRUD, slug uniqueness within scope, suggest_layout ranking,
  default_layout resolution, scope isolation, and use telemetry side
  effects.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Build
  alias Canopy.Build.Layout

  # ---------------------------------------------------------------------------
  # CRUD
  # ---------------------------------------------------------------------------

  describe "create_layout/1" do
    test "creates a layout with required fields" do
      assert {:ok, %Layout{} = layout} =
               Build.create_layout(%{slug: "review-pr", name: "Review PR"})

      assert layout.slug == "review-pr"
      assert layout.name == "Review PR"
      assert layout.scope == "personal"
      assert layout.density == "comfortable"
      assert layout.pane_title_format == "command"
      assert layout.use_count == 0
    end

    test "rejects missing slug" do
      assert {:error, changeset} = Build.create_layout(%{name: "X"})
      assert %{slug: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects missing name" do
      assert {:error, changeset} = Build.create_layout(%{slug: "x"})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects invalid scope" do
      assert {:error, changeset} =
               Build.create_layout(%{slug: "x", name: "X", scope: "global"})

      assert %{scope: [_msg]} = errors_on(changeset)
    end

    test "rejects invalid density" do
      assert {:error, changeset} =
               Build.create_layout(%{slug: "x", name: "X", density: "tiny"})

      assert %{density: [_msg]} = errors_on(changeset)
    end

    test "rejects invalid pane_title_format" do
      assert {:error, changeset} =
               Build.create_layout(%{
                 slug: "x",
                 name: "X",
                 pane_title_format: "emoji"
               })

      assert %{pane_title_format: [_msg]} = errors_on(changeset)
    end

    test "enforces slug uniqueness per (scope, owner_id)" do
      owner = Ecto.UUID.generate()

      assert {:ok, _} =
               Build.create_layout(%{slug: "dup", name: "A", owner_id: owner})

      assert {:error, changeset} =
               Build.create_layout(%{slug: "dup", name: "B", owner_id: owner})

      assert errors_on(changeset)[:slug]
    end

    test "allows same slug across different owners" do
      a = Ecto.UUID.generate()
      b = Ecto.UUID.generate()

      assert {:ok, _} =
               Build.create_layout(%{slug: "personal-default", name: "A", owner_id: a})

      assert {:ok, _} =
               Build.create_layout(%{slug: "personal-default", name: "B", owner_id: b})
    end

    test "allows same slug across different scopes for same owner" do
      owner = Ecto.UUID.generate()

      assert {:ok, _} =
               Build.create_layout(%{
                 slug: "default",
                 name: "Personal Default",
                 scope: "personal",
                 owner_id: owner
               })

      assert {:ok, _} =
               Build.create_layout(%{
                 slug: "default",
                 name: "Workspace Default",
                 scope: "workspace",
                 owner_id: owner,
                 workspace_slug: "ws"
               })
    end
  end

  describe "list_layouts/1" do
    setup do
      a = Ecto.UUID.generate()
      b = Ecto.UUID.generate()

      {:ok, l1} =
        Build.create_layout(%{slug: "a-1", name: "A1", scope: "personal", owner_id: a})

      {:ok, l2} =
        Build.create_layout(%{slug: "a-2", name: "A2", scope: "personal", owner_id: a})

      {:ok, l3} =
        Build.create_layout(%{
          slug: "ws-1",
          name: "WS1",
          scope: "workspace",
          workspace_slug: "alpha"
        })

      {:ok, lb} =
        Build.create_layout(%{slug: "b-1", name: "B1", scope: "personal", owner_id: b})

      {:ok, %{a: a, b: b, l1: l1, l2: l2, l3: l3, lb: lb}}
    end

    test "filters by scope", %{} do
      personal = Build.list_layouts(scope: "personal")
      assert length(personal) == 3

      ws = Build.list_layouts(scope: "workspace")
      assert length(ws) == 1
    end

    test "filters by owner_id (scope isolation)", %{a: a} do
      results = Build.list_layouts(scope: "personal", owner_id: a)
      assert length(results) == 2
      assert Enum.all?(results, &(&1.owner_id == a))
    end

    test "filters by workspace_slug" do
      results = Build.list_layouts(workspace_slug: "alpha")
      assert length(results) == 1
      assert hd(results).workspace_slug == "alpha"
    end

    test "excludes archived by default", %{l1: l1} do
      {:ok, _} = Build.archive_layout(l1)
      slugs = Build.list_layouts() |> Enum.map(& &1.slug)
      refute "a-1" in slugs
    end

    test "include_archived: true returns archived rows", %{l1: l1} do
      {:ok, _} = Build.archive_layout(l1)
      slugs = Build.list_layouts(include_archived: true) |> Enum.map(& &1.slug)
      assert "a-1" in slugs
    end

    test "respects limit" do
      assert length(Build.list_layouts(limit: 1)) == 1
    end
  end

  describe "get_layout_by_slug/2" do
    test "round-trips by (slug, scope, owner_id)" do
      owner = Ecto.UUID.generate()

      {:ok, _} =
        Build.create_layout(%{slug: "fix", name: "Fix Bug", owner_id: owner})

      assert %Layout{name: "Fix Bug"} =
               Build.get_layout_by_slug("fix", scope: "personal", owner_id: owner)
    end

    test "returns nil for missing slug" do
      assert nil == Build.get_layout_by_slug("nope")
    end

    test "scope isolation — wrong scope returns nil" do
      {:ok, _} = Build.create_layout(%{slug: "x", name: "X", scope: "personal"})
      assert nil == Build.get_layout_by_slug("x", scope: "team")
    end
  end

  describe "update_layout/2" do
    test "patches name and density" do
      {:ok, layout} = Build.create_layout(%{slug: "u1", name: "Original"})

      assert {:ok, updated} =
               Build.update_layout(layout, %{name: "Renamed", density: "compact"})

      assert updated.name == "Renamed"
      assert updated.density == "compact"
    end
  end

  describe "archive_layout/1" do
    test "sets archived_at" do
      {:ok, layout} = Build.create_layout(%{slug: "a1", name: "A"})
      assert {:ok, archived} = Build.archive_layout(layout)
      assert archived.archived_at != nil
    end
  end

  # ---------------------------------------------------------------------------
  # record_use/2
  # ---------------------------------------------------------------------------

  describe "record_use/2" do
    test "increments use_count and last_used_at" do
      {:ok, layout} = Build.create_layout(%{slug: "u1", name: "U1"})
      assert layout.use_count == 0
      assert layout.last_used_at == nil

      assert {:ok, _} = Build.record_use(layout, intent: "fix bug")

      reloaded = Build.get_layout!(layout.id)
      assert reloaded.use_count == 1
      assert reloaded.last_used_at != nil
    end

    test "stacks with multiple uses" do
      {:ok, layout} = Build.create_layout(%{slug: "u2", name: "U2"})

      for _ <- 1..3 do
        Build.record_use(layout)
      end

      reloaded = Build.get_layout!(layout.id)
      assert reloaded.use_count == 3
    end
  end

  # ---------------------------------------------------------------------------
  # suggest_layout/2
  # ---------------------------------------------------------------------------

  describe "suggest_layout/2" do
    setup do
      {:ok, review} =
        Build.create_layout(%{
          slug: "review-pr",
          name: "Review PR",
          description: "side-by-side diff plus terminal"
        })

      {:ok, fix} =
        Build.create_layout(%{
          slug: "fix-bug",
          name: "Fix Bug",
          description: "editor + failing test + terminal"
        })

      {:ok, ship} =
        Build.create_layout(%{
          slug: "ship-feature",
          name: "Ship Feature",
          description: "editor + terminal + diff"
        })

      # Bump uses so ranking has signal
      Build.record_use(fix)
      Build.record_use(fix)
      Build.record_use(fix)
      Build.record_use(review)

      {:ok, %{review: review, fix: fix, ship: ship}}
    end

    test "exact name match wins" do
      [top | _] = Build.suggest_layout("review pr")
      assert top.layout.slug == "review-pr"
    end

    test "description match also scores" do
      results = Build.suggest_layout("failing test")
      slugs = Enum.map(results, & &1.layout.slug)
      assert "fix-bug" in slugs
    end

    test "returns at most 3 suggestions" do
      assert length(Build.suggest_layout("anything")) <= 3
    end

    test "use_count breaks ties when no name/description match" do
      [top | _] = Build.suggest_layout("xyz-no-match")
      # fix-bug has 3 uses, review-pr has 1, ship has 0
      assert top.layout.slug == "fix-bug"
    end

    test "scores include name + use boost" do
      [top | _] = Build.suggest_layout("review")
      # review-pr has both name match (2.0) and use_count boost
      assert top.score > 2.0
    end
  end

  # ---------------------------------------------------------------------------
  # default_layout/1 and set_default/2
  # ---------------------------------------------------------------------------

  describe "default_layout/1" do
    test "returns nil when no workspace layout exists" do
      assert nil == Build.default_layout("empty-ws")
    end

    test "prefers a slug=='default' workspace-scoped row" do
      {:ok, _other} =
        Build.create_layout(%{
          slug: "review-pr",
          name: "Review",
          scope: "workspace",
          workspace_slug: "alpha"
        })

      {:ok, default} =
        Build.create_layout(%{
          slug: "default",
          name: "Default",
          scope: "workspace",
          workspace_slug: "alpha"
        })

      assert %Layout{id: id} = Build.default_layout("alpha")
      assert id == default.id
    end

    test "falls back to most-recently-used workspace layout" do
      {:ok, l1} =
        Build.create_layout(%{
          slug: "l1",
          name: "L1",
          scope: "workspace",
          workspace_slug: "beta"
        })

      Build.record_use(l1)
      assert %Layout{slug: "l1"} = Build.default_layout("beta")
    end

    test "skips archived defaults" do
      {:ok, layout} =
        Build.create_layout(%{
          slug: "default",
          name: "Default",
          scope: "workspace",
          workspace_slug: "gamma"
        })

      Build.archive_layout(layout)
      assert nil == Build.default_layout("gamma")
    end
  end

  describe "set_default/2" do
    test "renames slug to 'default' and pins workspace" do
      {:ok, layout} = Build.create_layout(%{slug: "fix-bug", name: "Fix Bug"})
      assert {:ok, updated} = Build.set_default(layout, "alpha")
      assert updated.slug == "default"
      assert updated.scope == "workspace"
      assert updated.workspace_slug == "alpha"
    end
  end
end
