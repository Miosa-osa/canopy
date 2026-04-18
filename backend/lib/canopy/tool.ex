defmodule Canopy.Tool do
  @moduledoc """
  Compile-time macro for declaring tools on a module.

  Ported from Core-OSS's `@tool` decorator pattern (Python) to idiomatic
  Elixir using `Module.register_attribute/3` and `@before_compile`.

  ## Usage

      defmodule MyTools do
        use Canopy.Tool

        tool "echo_message",
          description: "Echo a message back to the caller",
          parameters: %{
            type: "object",
            properties: %{message: %{type: "string"}},
            required: ["message"]
          },
          handler: {__MODULE__, :echo_message, []},
          requires: []

        def echo_message(%{"message" => msg}), do: {:ok, msg}
      end

  After `use Canopy.Tool`, the module gains a `__canopy_tools__/0` function
  that returns the list of `%Canopy.Tools.Tool{}` structs declared via `tool/2`.
  Call `Canopy.Tools.Registry.register_module(MyTools)` to register all of them.
  """

  defmacro __using__(_) do
    quote do
      import Canopy.Tool, only: [tool: 2]
      Module.register_attribute(__MODULE__, :canopy_tools, accumulate: true)
      @before_compile Canopy.Tool
    end
  end

  @doc """
  Declares a tool on the current module.

  `name` must be a compile-time string literal. `opts` accepts:

    * `:description` — (required) string shown to the LLM
    * `:parameters` — (required) JSON Schema map
    * `:handler` — (required) `{module, function, extra_args}` MFA tuple
    * `:requires` — list of capability atoms (default `[]`)
    * `:mcp_exposed` — boolean (default `true`)
    * `:prompt_exposed` — boolean (default `true`)
  """
  defmacro tool(name, opts) do
    quote do
      @canopy_tools %Canopy.Tools.Tool{
        name: unquote(name),
        description: unquote(opts[:description]),
        parameters: unquote(opts[:parameters]),
        handler: unquote(opts[:handler]),
        requires: unquote(opts[:requires] || []),
        mcp_exposed: unquote(Keyword.get(opts, :mcp_exposed, true)),
        prompt_exposed: unquote(Keyword.get(opts, :prompt_exposed, true))
      }
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    tools = Module.get_attribute(env.module, :canopy_tools) |> Enum.reverse()

    quote do
      @doc "Returns the list of tools declared on this module via `tool/2`."
      @spec __canopy_tools__() :: [Canopy.Tools.Tool.t()]
      def __canopy_tools__, do: unquote(Macro.escape(tools))
    end
  end
end
