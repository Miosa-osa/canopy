defmodule Canopy.Tools.RegistryTest do
  @moduledoc """
  Tests for `Canopy.Tools.Registry` — ETS-backed GenServer semantics.

  Covers: register, register_module, unregister, lookup, list (with filters),
  and dispatch with handler invocation and error cases.
  """

  use ExUnit.Case, async: false

  alias Canopy.Tools.{Registry, Tool}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp unique_name(base), do: "#{base}-#{System.unique_integer([:positive])}"

  defp build_tool(name, opts \\ []) do
    %Tool{
      name: name,
      description: opts[:description] || "Registry test tool",
      parameters: %{"type" => "object", "properties" => %{}},
      handler: opts[:handler] || {__MODULE__, :noop, []},
      requires: opts[:requires] || [],
      mcp_exposed: Keyword.get(opts, :mcp_exposed, true),
      prompt_exposed: Keyword.get(opts, :prompt_exposed, true)
    }
  end

  def noop(_args), do: {:ok, :noop}
  def double_handler(%{"x" => x}), do: {:ok, x * 2}
  def error_handler(_args), do: {:error, :forced}

  # ---------------------------------------------------------------------------
  # register/1 + lookup/1
  # ---------------------------------------------------------------------------

  describe "register/1 and lookup/1" do
    test "registers a tool and retrieves it by name" do
      name = unique_name("reg-lookup")
      tool = build_tool(name)
      Registry.register(tool)
      on_exit(fn -> Registry.unregister(name) end)

      assert {:ok, ^tool} = Registry.lookup(name)
    end

    test "returns {:error, :not_found} for unknown name" do
      assert {:error, :not_found} = Registry.lookup("no-such-tool-xyz")
    end

    test "overwrite: registering same name replaces prior entry" do
      name = unique_name("reg-overwrite")
      old_tool = build_tool(name, description: "old")
      new_tool = build_tool(name, description: "new")

      Registry.register(old_tool)
      Registry.register(new_tool)
      on_exit(fn -> Registry.unregister(name) end)

      assert {:ok, %Tool{description: "new"}} = Registry.lookup(name)
    end
  end

  # ---------------------------------------------------------------------------
  # register_module/1
  # ---------------------------------------------------------------------------

  describe "register_module/1" do
    defmodule SampleToolModule do
      use Canopy.Tool

      tool("sample_bulk_a",
        description: "bulk a",
        parameters: %{},
        handler: {Canopy.Tools.RegistryTest, :noop, []},
        requires: []
      )

      tool("sample_bulk_b",
        description: "bulk b",
        parameters: %{},
        handler: {Canopy.Tools.RegistryTest, :noop, []},
        requires: []
      )
    end

    test "registers all tools declared by the module" do
      Registry.register_module(SampleToolModule)

      on_exit(fn ->
        Registry.unregister("sample_bulk_a")
        Registry.unregister("sample_bulk_b")
      end)

      assert {:ok, %Tool{name: "sample_bulk_a"}} = Registry.lookup("sample_bulk_a")
      assert {:ok, %Tool{name: "sample_bulk_b"}} = Registry.lookup("sample_bulk_b")
    end
  end

  # ---------------------------------------------------------------------------
  # unregister/1
  # ---------------------------------------------------------------------------

  describe "unregister/1" do
    test "removes a registered tool" do
      name = unique_name("unreg")
      Registry.register(build_tool(name))
      Registry.unregister(name)

      assert {:error, :not_found} = Registry.lookup(name)
    end

    test "is idempotent — unregistering a missing name does not raise" do
      assert :ok = Registry.unregister("definitely-not-registered")
    end
  end

  # ---------------------------------------------------------------------------
  # list/1 — filters
  # ---------------------------------------------------------------------------

  describe "list/0" do
    test "returns a list (may include other tests' tools)" do
      assert is_list(Registry.list())
    end

    test "includes a newly registered tool" do
      name = unique_name("list-check")
      Registry.register(build_tool(name))
      on_exit(fn -> Registry.unregister(name) end)

      names = Registry.list() |> Enum.map(& &1.name)
      assert name in names
    end
  end

  describe "list/1 — mcp_exposed filter" do
    test "true: returns tools with mcp_exposed true" do
      yes = unique_name("mcp-yes")
      no = unique_name("mcp-no")
      Registry.register(build_tool(yes, mcp_exposed: true))
      Registry.register(build_tool(no, mcp_exposed: false))

      on_exit(fn ->
        Registry.unregister(yes)
        Registry.unregister(no)
      end)

      names = Registry.list(mcp_exposed: true) |> Enum.map(& &1.name)
      assert yes in names
      refute no in names
    end

    test "false: returns tools with mcp_exposed false" do
      yes = unique_name("mcp-yes2")
      no = unique_name("mcp-no2")
      Registry.register(build_tool(yes, mcp_exposed: true))
      Registry.register(build_tool(no, mcp_exposed: false))

      on_exit(fn ->
        Registry.unregister(yes)
        Registry.unregister(no)
      end)

      names = Registry.list(mcp_exposed: false) |> Enum.map(& &1.name)
      assert no in names
      refute yes in names
    end
  end

  describe "list/1 — prompt_exposed filter" do
    test "returns tools matching prompt_exposed: true" do
      yes = unique_name("prompt-yes")
      no = unique_name("prompt-no")
      Registry.register(build_tool(yes, prompt_exposed: true))
      Registry.register(build_tool(no, prompt_exposed: false))

      on_exit(fn ->
        Registry.unregister(yes)
        Registry.unregister(no)
      end)

      names = Registry.list(prompt_exposed: true) |> Enum.map(& &1.name)
      assert yes in names
      refute no in names
    end
  end

  describe "list/1 — requires filter" do
    test "keeps only tools that satisfy ALL required capabilities" do
      fs = unique_name("cap-fs")
      net = unique_name("cap-net")
      both = unique_name("cap-both")
      none = unique_name("cap-none")

      Registry.register(build_tool(fs, requires: [:filesystem]))
      Registry.register(build_tool(net, requires: [:network]))
      Registry.register(build_tool(both, requires: [:filesystem, :network]))
      Registry.register(build_tool(none, requires: []))

      on_exit(fn ->
        Registry.unregister(fs)
        Registry.unregister(net)
        Registry.unregister(both)
        Registry.unregister(none)
      end)

      # Asking for :filesystem — should include :filesystem and :both
      names = Registry.list(requires: [:filesystem]) |> Enum.map(& &1.name)
      assert fs in names
      assert both in names
      refute net in names
      refute none in names
    end

    test "empty requires filter returns all tools" do
      name = unique_name("cap-open")
      Registry.register(build_tool(name, requires: [:filesystem]))
      on_exit(fn -> Registry.unregister(name) end)

      names = Registry.list(requires: []) |> Enum.map(& &1.name)
      assert name in names
    end
  end

  # ---------------------------------------------------------------------------
  # dispatch/2
  # ---------------------------------------------------------------------------

  describe "dispatch/2" do
    test "invokes the handler and returns {:ok, result}" do
      name = unique_name("dispatch-ok")
      Registry.register(build_tool(name, handler: {__MODULE__, :double_handler, []}))
      on_exit(fn -> Registry.unregister(name) end)

      assert {:ok, 84} = Registry.dispatch(name, %{"x" => 42})
    end

    test "returns {:error, :not_found} for unknown tool name" do
      assert {:error, :not_found} = Registry.dispatch("ghost-tool-xyz", %{})
    end

    test "returns {:error, reason} when handler returns error" do
      name = unique_name("dispatch-err")
      Registry.register(build_tool(name, handler: {__MODULE__, :error_handler, []}))
      on_exit(fn -> Registry.unregister(name) end)

      assert {:error, :forced} = Registry.dispatch(name, %{})
    end

    test "wraps handler exceptions in {:error, {:handler_raised, msg}}" do
      name = unique_name("dispatch-raise")

      tool = %Tool{
        name: name,
        description: "raises",
        parameters: %{},
        handler: {__MODULE__, :raise_handler, []},
        requires: []
      }

      Registry.register(tool)
      on_exit(fn -> Registry.unregister(name) end)

      assert {:error, {:handler_raised, _msg}} = Registry.dispatch(name, %{})
    end
  end

  def raise_handler(_args), do: raise("intentional crash in test")
end
