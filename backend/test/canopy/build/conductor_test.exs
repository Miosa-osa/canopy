defmodule Canopy.Build.ConductorTest do
  @moduledoc """
  Tests for the Conductor boot bootstrap surface.

  Covers:
    * `hire_if_missing/0` creates an agent row with the correct slug, role,
      and persona fields.
    * `hire_if_missing/0` is idempotent — calling it twice does not error or
      duplicate.
    * `hire_if_missing/0` preserves runtime-edited `persona_markdown` on
      re-hire (mirrors the Iris persona-edit guard).
    * `register_tools/0` makes all 12 build.* tools resolvable via
      `Canopy.Tools.Registry.lookup/1`.
    * `announce_online/0` posts to `#build-feed` exactly once across repeated
      calls (idempotent via `agents.config["announced_online"]`).
    * `announce_online/0` no-ops cleanly when the channel does not exist.

  Mirrors `Canopy.Analytics.IrisTest` line-for-line where applicable —
  Conductor's bootstrap is a parallel of Iris's.
  """

  use Canopy.DataCase, async: false

  alias Canopy.Agents
  alias Canopy.Build.Conductor
  alias Canopy.Channels
  alias Canopy.Tools.Registry, as: ToolRegistry

  @slug "conductor"
  @announce_channel_slug "build-feed"
  @build_tool_names [
    "build.open_pane",
    "build.split_pane",
    "build.close_pane",
    "build.focus_pane",
    "build.suggest_layout",
    "build.save_layout",
    "build.load_layout",
    "build.open_file",
    "build.open_block",
    "build.run_command",
    "build.set_density",
    "build.list_layouts"
  ]

  describe "hire_if_missing/0" do
    test "creates an agent row with the right slug, role, and persona fields" do
      assert {:ok, agent} = Conductor.hire_if_missing()

      assert agent.slug == @slug
      assert agent.name == "Conductor"
      assert agent.category == "specialized"
      assert agent.persona_path == "conductor/persona.md"
      assert agent.default_runtime == "claude-local"
      assert agent.default_model == "claude-sonnet-4-7"
      assert agent.heartbeat_cron == "0 */6 * * *"
      assert agent.hired == true
      assert Decimal.equal?(agent.budget_monthly_usd, Decimal.new(4000))

      # The DB row is reachable via the public Agents API.
      assert {:ok, fetched} = Agents.get_by_slug(@slug)
      assert fetched.id == agent.id
    end

    test "is idempotent — calling twice does not error or duplicate" do
      {:ok, first} = Conductor.hire_if_missing()
      {:ok, second} = Conductor.hire_if_missing()

      assert first.id == second.id
      assert second.hired == true

      {:ok, all} = Agents.list()
      assert Enum.count(all, &(&1.slug == @slug)) == 1
    end

    test "re-hires an agent that was previously fired" do
      {:ok, _first} = Conductor.hire_if_missing()
      {:ok, _fired} = Agents.fire(@slug)

      {:ok, fetched} = Agents.get_by_slug(@slug)
      assert fetched.hired == false

      {:ok, rehired} = Conductor.hire_if_missing()
      assert rehired.hired == true
    end

    test "preserves runtime-edited persona_markdown on re-hire" do
      {:ok, _first} = Conductor.hire_if_missing()
      {:ok, _edited} = Agents.update_persona(@slug, "CUSTOM EDITED PERSONA")

      {:ok, rehired} = Conductor.hire_if_missing()
      assert rehired.persona_markdown == "CUSTOM EDITED PERSONA"
    end
  end

  describe "register_tools/0" do
    test "makes all 12 build tools resolvable via Registry.lookup/1" do
      assert :ok = Conductor.register_tools()

      for name <- @build_tool_names do
        assert {:ok, tool} = ToolRegistry.lookup(name),
               "expected #{name} to be registered after Conductor.register_tools/0"

        assert tool.name == name
      end
    end

    test "is idempotent — re-registering does not raise" do
      assert :ok = Conductor.register_tools()
      assert :ok = Conductor.register_tools()

      # All 12 still resolvable.
      for name <- @build_tool_names do
        assert {:ok, _tool} = ToolRegistry.lookup(name)
      end
    end
  end

  describe "announce_online/0" do
    test "posts to #build-feed exactly once across repeated calls" do
      {:ok, _agent} = Conductor.hire_if_missing()

      {:ok, channel} =
        Channels.create(%{
          slug: @announce_channel_slug,
          name: "build-feed",
          visibility: "public"
        })

      assert :ok = Conductor.announce_online()
      assert :ok = Conductor.announce_online()
      assert :ok = Conductor.announce_online()

      {messages, _has_more} = Channels.list_messages(channel.id, limit: 10)

      online_messages =
        Enum.filter(messages, fn m ->
          is_binary(m.body_markdown) and String.contains?(m.body_markdown, "Conductor")
        end)

      assert length(online_messages) == 1,
             "expected exactly one announcement message, got #{length(online_messages)}"

      {:ok, fetched} = Agents.get_by_slug(@slug)
      assert Map.get(fetched.config || %{}, "announced_online") == true
    end

    test "is a clean no-op when the #build-feed channel is missing" do
      {:ok, _agent} = Conductor.hire_if_missing()
      assert :ok = Conductor.announce_online()

      # Flag stays unset so the next boot (with the channel created) can post.
      {:ok, fetched} = Agents.get_by_slug(@slug)
      refute Map.get(fetched.config || %{}, "announced_online") == true
    end
  end
end
