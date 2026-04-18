defmodule Canopy.Tools.Tool do
  @moduledoc """
  Struct representing a callable tool that agents can invoke.

  Tools are the building block of agent autonomy — they let agents read
  filesystem state, search workspaces, and emit structured logs without
  needing external APIs.

  ## Fields

    * `:name` — unique tool identifier used for dispatch (e.g. `"read_file"`)
    * `:description` — shown to the LLM so it knows when to call the tool
    * `:parameters` — JSON Schema `object` describing accepted arguments
    * `:handler` — MFA tuple `{module, function, extra_args}` for dispatch
    * `:requires` — capability atoms the runtime must have (e.g. `[:filesystem]`)
    * `:mcp_exposed` — if `true`, tool appears in the MCP server manifest
    * `:prompt_exposed` — if `true`, tool is injected as a curl instruction
      for non-MCP runtimes
  """

  @enforce_keys [:name, :description, :parameters, :handler]

  @type capability :: atom()

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          parameters: map(),
          handler: {module(), atom(), list()},
          requires: [capability()],
          mcp_exposed: boolean(),
          prompt_exposed: boolean()
        }

  defstruct [
    :name,
    :description,
    :parameters,
    :handler,
    requires: [],
    mcp_exposed: true,
    prompt_exposed: true
  ]
end
