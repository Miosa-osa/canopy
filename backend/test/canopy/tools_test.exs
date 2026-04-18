defmodule Canopy.ToolsTest do
  @moduledoc """
  Tests for the `Canopy.Tools` public API — register, list, and dispatch.

  Uses the real `Canopy.Tools.Registry` ETS process. Each test registers its
  own uniquely-named tools to avoid interference with other tests or the
  built-in tools registered at boot.
  """

  use Canopy.DataCase, async: false

  alias Canopy.Tools
  alias Canopy.Tools.{Registry, Tool}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp unique_name(base), do: "#{base}-#{System.unique_integer([:positive])}"

  defp build_tool(name, opts \\ []) do
    %Tool{
      name: name,
      description: opts[:description] || "A test tool",
      parameters: opts[:parameters] || %{"type" => "object", "properties" => %{}},
      handler: opts[:handler] || {__MODULE__, :noop_handler, []},
      requires: opts[:requires] || [],
      mcp_exposed: Keyword.get(opts, :mcp_exposed, true),
      prompt_exposed: Keyword.get(opts, :prompt_exposed, true)
    }
  end

  def noop_handler(_args), do: {:ok, "noop"}
  def echo_handler(%{"value" => v}), do: {:ok, v}
  def failing_handler(_args), do: {:error, :intentional_failure}

  setup do
    on_exit(fn ->
      # Clean up any tools we registered during the test
      :ok
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # list/1
  # ---------------------------------------------------------------------------

  describe "list/0" do
    test "returns a list" do
      result = Tools.list()
      assert is_list(result)
    end

    test "includes a registered tool" do
      name = unique_name("list-test")
      Registry.register(build_tool(name))
      on_exit(fn -> Registry.unregister(name) end)

      names = Tools.list() |> Enum.map(& &1.name)
      assert name in names
    end
  end

  describe "list/1 with mcp_exposed filter" do
    test "returns only mcp_exposed tools when filter is true" do
      mcp_name = unique_name("mcp-yes")
      no_mcp_name = unique_name("mcp-no")

      Registry.register(build_tool(mcp_name, mcp_exposed: true))
      Registry.register(build_tool(no_mcp_name, mcp_exposed: false))

      on_exit(fn ->
        Registry.unregister(mcp_name)
        Registry.unregister(no_mcp_name)
      end)

      filtered = Tools.list(mcp_exposed: true)
      names = Enum.map(filtered, & &1.name)

      assert mcp_name in names
      refute no_mcp_name in names
    end

    test "returns only non-mcp tools when filter is false" do
      mcp_name = unique_name("mcp-yes2")
      no_mcp_name = unique_name("mcp-no2")

      Registry.register(build_tool(mcp_name, mcp_exposed: true))
      Registry.register(build_tool(no_mcp_name, mcp_exposed: false))

      on_exit(fn ->
        Registry.unregister(mcp_name)
        Registry.unregister(no_mcp_name)
      end)

      filtered = Tools.list(mcp_exposed: false)
      names = Enum.map(filtered, & &1.name)

      assert no_mcp_name in names
      refute mcp_name in names
    end
  end

  describe "list/1 with prompt_exposed filter" do
    test "returns only prompt_exposed tools when filter is true" do
      prompt_name = unique_name("prompt-yes")
      no_prompt_name = unique_name("prompt-no")

      Registry.register(build_tool(prompt_name, prompt_exposed: true))
      Registry.register(build_tool(no_prompt_name, prompt_exposed: false))

      on_exit(fn ->
        Registry.unregister(prompt_name)
        Registry.unregister(no_prompt_name)
      end)

      filtered = Tools.list(prompt_exposed: true)
      names = Enum.map(filtered, & &1.name)

      assert prompt_name in names
      refute no_prompt_name in names
    end
  end

  describe "list/1 with requires filter" do
    test "returns only tools that have all required capabilities" do
      fs_name = unique_name("requires-fs")
      net_name = unique_name("requires-net")
      both_name = unique_name("requires-both")

      Registry.register(build_tool(fs_name, requires: [:filesystem]))
      Registry.register(build_tool(net_name, requires: [:network]))
      Registry.register(build_tool(both_name, requires: [:filesystem, :network]))

      on_exit(fn ->
        Registry.unregister(fs_name)
        Registry.unregister(net_name)
        Registry.unregister(both_name)
      end)

      fs_only = Tools.list(requires: [:filesystem]) |> Enum.map(& &1.name)
      assert fs_name in fs_only
      assert both_name in fs_only
      refute net_name in fs_only
    end
  end

  # ---------------------------------------------------------------------------
  # dispatch/2
  # ---------------------------------------------------------------------------

  describe "dispatch/2" do
    test "dispatches a registered tool and returns its result" do
      name = unique_name("dispatch-ok")
      Registry.register(build_tool(name, handler: {__MODULE__, :echo_handler, []}))
      on_exit(fn -> Registry.unregister(name) end)

      assert {:ok, "hello"} = Tools.dispatch(name, %{"value" => "hello"})
    end

    test "returns {:error, :not_found} when tool name is not registered" do
      assert {:error, :not_found} = Tools.dispatch("nonexistent-tool-xyz", %{})
    end

    test "returns {:error, reason} when handler returns an error" do
      name = unique_name("dispatch-fail")
      Registry.register(build_tool(name, handler: {__MODULE__, :failing_handler, []}))
      on_exit(fn -> Registry.unregister(name) end)

      assert {:error, :intentional_failure} = Tools.dispatch(name, %{})
    end

    test "returns {:error, {:handler_raised, _}} when handler raises" do
      name = unique_name("dispatch-raise")

      raising_tool = %Tool{
        name: name,
        description: "raises",
        parameters: %{},
        handler: {__MODULE__, :bad_handler, []},
        requires: []
      }

      Registry.register(raising_tool)
      on_exit(fn -> Registry.unregister(name) end)

      assert {:error, {:handler_raised, _msg}} = Tools.dispatch(name, %{})
    end
  end

  # Exported only to be invokable by MFA in the raising test
  def bad_handler(_args), do: raise("boom")

  # ---------------------------------------------------------------------------
  # register_all_builtins/0
  # ---------------------------------------------------------------------------

  describe "register_all_builtins/0" do
    test "registers the built-in tools" do
      Tools.register_all_builtins()
      names = Tools.list() |> Enum.map(& &1.name)

      assert "read_file" in names
      assert "list_directory" in names
      assert "search_workspace" in names
      assert "get_session_context" in names
      assert "log_message" in names
      assert "create_comment" in names
    end
  end
end
