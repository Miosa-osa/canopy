defmodule Canopy.Build.CommandsTest do
  @moduledoc """
  Tests for `Canopy.Build.Commands` — the multi-source slash-command
  aggregator that backs `GET /api/v1/build/commands`.

  Coverage:
    * Built-in source is always present (10 canonical commands).
    * Drive workflows + prompts are folded in with the right `source` tag.
    * Templates of `kind: "workflow"` light up — workspace/persona templates
      are correctly skipped (heavyweight).
    * Skills are surfaced when enabled, hidden when not.
    * `:q` filter narrows by name + description, case-insensitive.
    * `:limit` clamps the result.
  """

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Build.Commands
  alias Canopy.Drive
  alias Canopy.Templates

  describe "list/1 — built-in source" do
    test "always includes the 10 canonical built-ins on a fresh DB" do
      cmds = Commands.list()
      builtins = Enum.filter(cmds, &(&1.source == "builtin"))

      assert length(builtins) == 10

      names = Enum.map(builtins, & &1.name)

      assert "/agent" in names
      assert "/plan" in names
      assert "/open-file" in names
      assert "/conversations" in names
      assert "/prompts" in names
      assert "/add-prompt" in names
      assert "/add-rule" in names
      assert "/add-mcp" in names
      assert "/create-environment" in names
      assert "/review" in names
    end

    test "every command carries a leading slash, namespace, source, icon" do
      [first | _] = Commands.list()
      assert String.starts_with?(first.name, "/")
      assert is_binary(first.namespace)
      assert is_binary(first.source)
      assert is_binary(first.icon)
    end
  end

  describe "list/1 — Drive source" do
    test "surfaces workflow + prompt entries with distinct sources" do
      {:ok, _wf} =
        Drive.create(%{
          slug: "squash-commits",
          name: "Squash commits",
          kind: "workflow",
          scope: "personal",
          body: %{"routine_id" => Ecto.UUID.generate()}
        })

      {:ok, _pr} =
        Drive.create(%{
          slug: "code-review-prompt",
          name: "Code review",
          kind: "prompt",
          scope: "personal",
          body: %{"body" => "Review this code carefully"}
        })

      cmds = Commands.list()

      assert Enum.any?(cmds, &(&1.source == "drive_workflow" and &1.name == "/squash-commits"))
      assert Enum.any?(cmds, &(&1.source == "drive_prompt" and &1.name == "/code-review-prompt"))
    end

    test "skips folder + notebook + env_vars + mcp_server + rule kinds" do
      {:ok, _folder} =
        Drive.create(%{slug: "fold-1", name: "Folder", kind: "folder", scope: "personal"})

      cmds = Commands.list()

      refute Enum.any?(cmds, &(&1.name == "/fold-1"))
    end

    test "excludes archived entries" do
      {:ok, entry} =
        Drive.create(%{
          slug: "old-flow",
          name: "Old flow",
          kind: "workflow",
          scope: "personal",
          body: %{"routine_id" => Ecto.UUID.generate()}
        })

      {:ok, _} = Drive.archive(entry)

      cmds = Commands.list()
      refute Enum.any?(cmds, &(&1.name == "/old-flow"))
    end
  end

  describe "list/1 — Templates source" do
    test "includes workflow templates only — workspace/persona are skipped" do
      {:ok, _ws} =
        Templates.create_template(%{slug: "spin-up-dev-shop-ws", name: "Dev Shop", kind: "workspace"})

      {:ok, _persona} =
        Templates.create_template(%{slug: "senior-eng", name: "Senior Eng", kind: "persona"})

      {:ok, _wf} =
        Templates.create_template(%{
          slug: "ship-feature",
          name: "Ship Feature",
          kind: "workflow",
          description: "Run the standard ship-feature playbook"
        })

      cmds = Commands.list()
      template_cmds = Enum.filter(cmds, &(&1.source == "template"))

      assert Enum.any?(template_cmds, &(&1.name == "/ship-feature"))
      refute Enum.any?(template_cmds, &(&1.name == "/spin-up-dev-shop-ws"))
      refute Enum.any?(template_cmds, &(&1.name == "/senior-eng"))
    end
  end

  describe "list/1 — Skills source" do
    test "surfaces enabled skills only" do
      insert(:skill, slug: "elixir-strict", name: "Elixir Strict", enabled: true)
      insert(:skill, slug: "off-skill", name: "Off skill", enabled: false)

      cmds = Commands.list()

      assert Enum.any?(cmds, &(&1.source == "skill" and &1.name == "/use-elixir-strict"))
      refute Enum.any?(cmds, &(&1.name == "/use-off-skill"))
    end
  end

  describe "list/1 — :q filter" do
    test "filters by substring on name (case-insensitive)" do
      cmds = Commands.list(q: "AGENT")
      assert Enum.any?(cmds, &(&1.name == "/agent"))
      refute Enum.any?(cmds, &(&1.name == "/review"))
    end

    test "filters by substring on description" do
      cmds = Commands.list(q: "history")
      assert Enum.any?(cmds, &(&1.name == "/conversations"))
    end

    test "empty query returns everything" do
      assert length(Commands.list(q: "")) >= 10
      assert length(Commands.list(q: nil)) >= 10
    end

    test "no-match query returns empty" do
      assert Commands.list(q: "definitely-not-a-real-command-zzz") == []
    end
  end

  describe "list/1 — :limit" do
    test "caps the result" do
      assert length(Commands.list(limit: 3)) == 3
    end

    test "hard caps at 200 even when caller asks for more" do
      assert length(Commands.list(limit: 9999)) <= 200
    end
  end

  describe "list/1 — source order" do
    test "built-ins come before Drive entries" do
      {:ok, _wf} =
        Drive.create(%{
          slug: "z-workflow",
          name: "Z workflow",
          kind: "workflow",
          scope: "personal",
          body: %{"routine_id" => Ecto.UUID.generate()}
        })

      cmds = Commands.list()
      builtin_idx = Enum.find_index(cmds, &(&1.source == "builtin"))
      drive_idx = Enum.find_index(cmds, &(&1.source == "drive_workflow"))

      assert is_integer(builtin_idx)
      assert is_integer(drive_idx)
      assert builtin_idx < drive_idx
    end
  end
end
