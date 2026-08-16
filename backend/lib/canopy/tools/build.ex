defmodule Canopy.Tools.Build do
  @moduledoc """
  Build tool surface for the **Conductor** agent.

  Conductor is the runtime agent for the `/build` cockpit. It orchestrates
  the Mosaic layout (pane creation, splits, focus, close), proposes saved
  layouts that match the user's stated intent, and surfaces relevant context
  (open the right file, jump to the right block, run the right command).

  ## Architectural rule — composition only

  Most tools below are **command emitters** — they DELEGATE to existing
  super-modules (Sessions, Workspaces, Files, Sandboxes, Blocks) to figure
  out *what* should appear in a pane, then return a structured instruction
  the frontend's PaneContent dispatcher honors. The tools never construct
  pane DOM, terminal sessions, or block streams themselves — that machinery
  already exists in the underlying super-modules.

  ## Tool list (12)

  - `build.open_pane` — append a pane to the active layout
  - `build.split_pane` — split an existing pane in a direction
  - `build.close_pane`
  - `build.focus_pane`
  - `build.suggest_layout` — top 3 layouts ranked by use_count + name match
  - `build.save_layout` — capture current layout as a saved layout
  - `build.load_layout` — load a saved layout into the cockpit
  - `build.open_file` — open FileViewer or CodeEditor pane
  - `build.open_block` — open a BlockStream pane focused on a block
  - `build.run_command` — open a Terminal pane and queue the command
  - `build.set_density` — set pane density preference
  - `build.list_layouts` — list available saved layouts

  Tools are registered at application boot via the same registry path used
  by Analytics / Schedule / Sandboxes etc. — see
  `Canopy.Tools.Registry.register_module/1`.
  """

  use Canopy.Tool

  alias Canopy.Build

  @pane_kinds ~w(terminal block_stream code_editor file_viewer diff mcp)
  @densities ~w(compact comfortable roomy)
  @directions ~w(left right up down)

  # ---------------------------------------------------------------------------
  # Tool declarations
  # ---------------------------------------------------------------------------

  tool("build.open_pane",
    description: """
    Append a new pane to the active Build layout. Returns the structured
    instruction the frontend dispatches to the Mosaic store.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "pane_kind" => %{
          "type" => "string",
          "enum" => ["terminal", "block_stream", "code_editor", "file_viewer", "diff", "mcp"],
          "description" => "Which pane component to mount"
        },
        "config" => %{
          "type" => "object",
          "additionalProperties" => true,
          "description" => "Pane-specific configuration (file path, run id, command, etc.)"
        }
      },
      "required" => ["pane_kind"]
    },
    handler: {__MODULE__, :open_pane, []},
    requires: [:build]
  )

  tool("build.split_pane",
    description: """
    Split an existing pane into two. Returns the instruction the frontend
    applies to the Mosaic store.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "pane_id" => %{"type" => "string", "description" => "ID of the pane to split"},
        "direction" => %{
          "type" => "string",
          "enum" => ["left", "right", "up", "down"]
        },
        "new_pane_kind" => %{
          "type" => "string",
          "enum" => ["terminal", "block_stream", "code_editor", "file_viewer", "diff", "mcp"]
        },
        "new_config" => %{"type" => "object", "additionalProperties" => true}
      },
      "required" => ["pane_id", "direction", "new_pane_kind"]
    },
    handler: {__MODULE__, :split_pane, []},
    requires: [:build]
  )

  tool("build.close_pane",
    description: "Close a pane in the active layout.",
    parameters: %{
      "type" => "object",
      "properties" => %{"pane_id" => %{"type" => "string"}},
      "required" => ["pane_id"]
    },
    handler: {__MODULE__, :close_pane, []},
    requires: [:build]
  )

  tool("build.focus_pane",
    description: "Move focus to a specific pane.",
    parameters: %{
      "type" => "object",
      "properties" => %{"pane_id" => %{"type" => "string"}},
      "required" => ["pane_id"]
    },
    handler: {__MODULE__, :focus_pane, []},
    requires: [:build]
  )

  tool("build.suggest_layout",
    description: """
    Returns up to 3 saved layouts ranked by use frequency and name/description
    fuzzy match against the user's stated intent (e.g. "review pr",
    "fix bug", "ship feature"). Used by Conductor to propose a starting
    arrangement.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "intent" => %{"type" => "string", "description" => "Free-text intent"},
        "scope" => %{
          "type" => "string",
          "enum" => ["personal", "team", "workspace"]
        },
        "owner_id" => %{"type" => "string"},
        "workspace_slug" => %{"type" => "string"}
      },
      "required" => ["intent"]
    },
    handler: {__MODULE__, :suggest_layout, []},
    requires: [:build]
  )

  tool("build.save_layout",
    description: """
    Capture the current Mosaic layout as a saved layout under the given
    name and scope. The frontend includes the live layout JSON in `config`.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string"},
        "scope" => %{
          "type" => "string",
          "enum" => ["personal", "team", "workspace"]
        },
        "slug" => %{"type" => "string", "description" => "Optional canonical handle"},
        "owner_id" => %{"type" => "string"},
        "workspace_slug" => %{"type" => "string"},
        "layout_json" => %{
          "type" => "object",
          "additionalProperties" => true,
          "description" => "The full Mosaic tree to persist"
        },
        "description" => %{"type" => "string"},
        "default_pane_kind" => %{"type" => "string"}
      },
      "required" => ["name"]
    },
    handler: {__MODULE__, :save_layout, []},
    requires: [:build]
  )

  tool("build.load_layout",
    description: """
    Load a saved layout into the cockpit. Records a `LayoutUse` row so
    suggestions stay tuned to the user's actual workflow.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "scope" => %{
          "type" => "string",
          "enum" => ["personal", "team", "workspace"]
        },
        "owner_id" => %{"type" => "string"},
        "workspace_slug" => %{"type" => "string"},
        "intent" => %{"type" => "string"}
      },
      "required" => ["slug"]
    },
    handler: {__MODULE__, :load_layout, []},
    requires: [:build]
  )

  tool("build.open_file",
    description: """
    Open a file in a Code Editor or File Viewer pane. The tool resolves the
    path/id via Canopy.Workspaces.Files / Canopy.Files and emits a
    pane-creation instruction; the frontend dispatcher creates the actual
    pane.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "path" => %{"type" => "string", "description" => "Workspace-relative path"},
        "file_id" => %{"type" => "string", "description" => "Indexed file UUID"},
        "workspace_slug" => %{"type" => "string"},
        "editor" => %{
          "type" => "string",
          "enum" => ["code_editor", "file_viewer"],
          "description" => "Default code_editor for editable kinds, file_viewer for read-only"
        }
      }
    },
    handler: {__MODULE__, :open_file, []},
    requires: [:build]
  )

  tool("build.open_block",
    description: """
    Open a Block Stream pane focused on a specific block. The frontend
    pane dispatcher subscribes to the block's session and scrolls to it.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "block_id" => %{"type" => "string"},
        "session_id" => %{"type" => "string"}
      },
      "required" => ["block_id"]
    },
    handler: {__MODULE__, :open_block, []},
    requires: [:build]
  )

  tool("build.run_command",
    description: """
    Open a Terminal pane (or focus the active one) and queue the given
    command for execution. Conductor uses this for "run the tests",
    "show me the diff", etc.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "text" => %{"type" => "string", "description" => "Command to run"},
        "session_id" => %{"type" => "string"},
        "workspace_slug" => %{"type" => "string"},
        "cwd" => %{"type" => "string"}
      },
      "required" => ["text"]
    },
    handler: {__MODULE__, :run_command, []},
    requires: [:build]
  )

  tool("build.set_density",
    description: "Set the active pane density preference.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "level" => %{
          "type" => "string",
          "enum" => ["compact", "comfortable", "roomy"]
        }
      },
      "required" => ["level"]
    },
    handler: {__MODULE__, :set_density, []},
    requires: [:build]
  )

  tool("build.list_layouts",
    description: "List saved layouts available to the current user/workspace.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "scope" => %{
          "type" => "string",
          "enum" => ["personal", "team", "workspace"]
        },
        "owner_id" => %{"type" => "string"},
        "workspace_slug" => %{"type" => "string"},
        "limit" => %{"type" => "integer"}
      }
    },
    handler: {__MODULE__, :list_layouts, []},
    requires: [:build]
  )

  # ---------------------------------------------------------------------------
  # Handlers — most are thin command emitters
  # ---------------------------------------------------------------------------

  @doc false
  def open_pane(args) do
    with {:ok, kind} <- validate_kind(args["pane_kind"]) do
      {:ok,
       %{
         action: "open_pane",
         pane_kind: kind,
         config: args["config"] || %{}
       }}
    end
  end

  @doc false
  def split_pane(args) do
    with {:ok, kind} <- validate_kind(args["new_pane_kind"]),
         {:ok, dir} <- validate_direction(args["direction"]),
         {:ok, pane_id} <- require_string(args["pane_id"], "pane_id") do
      {:ok,
       %{
         action: "split_pane",
         pane_id: pane_id,
         direction: dir,
         new_pane_kind: kind,
         new_config: args["new_config"] || %{}
       }}
    end
  end

  @doc false
  def close_pane(args) do
    with {:ok, pane_id} <- require_string(args["pane_id"], "pane_id") do
      {:ok, %{action: "close_pane", pane_id: pane_id}}
    end
  end

  @doc false
  def focus_pane(args) do
    with {:ok, pane_id} <- require_string(args["pane_id"], "pane_id") do
      {:ok, %{action: "focus_pane", pane_id: pane_id}}
    end
  end

  @doc false
  def suggest_layout(args) do
    with {:ok, intent} <- require_string(args["intent"], "intent") do
      opts =
        []
        |> put_opt(:scope, args["scope"])
        |> put_opt(:owner_id, args["owner_id"])
        |> put_opt(:workspace_slug, args["workspace_slug"])

      results =
        intent
        |> Build.suggest_layout(opts)
        |> Enum.map(fn %{layout: layout, score: score} ->
          %{
            slug: layout.slug,
            name: layout.name,
            scope: layout.scope,
            description: layout.description,
            use_count: layout.use_count,
            score: score
          }
        end)

      {:ok, %{intent: intent, count: length(results), suggestions: results}}
    end
  end

  @doc false
  def save_layout(args) do
    with {:ok, name} <- require_string(args["name"], "name") do
      attrs = %{
        slug: args["slug"] || slugify(name),
        name: name,
        scope: args["scope"] || "personal",
        owner_id: args["owner_id"],
        workspace_slug: args["workspace_slug"],
        layout_json: args["layout_json"] || %{},
        default_pane_kind: args["default_pane_kind"],
        description: args["description"]
      }

      case Build.create_layout(attrs) do
        {:ok, layout} ->
          {:ok,
           %{
             action: "save_layout",
             slug: layout.slug,
             scope: layout.scope,
             id: layout.id
           }}

        {:error, changeset} ->
          {:error, format_changeset(changeset)}
      end
    end
  end

  @doc false
  def load_layout(args) do
    with {:ok, slug} <- require_string(args["slug"], "slug") do
      scope = args["scope"] || "personal"

      case Build.get_layout_by_slug(slug, scope: scope, owner_id: args["owner_id"]) do
        nil ->
          {:error, "layout_not_found: #{slug}"}

        layout ->
          {:ok, _use} =
            Build.record_use(layout,
              user_id: args["owner_id"],
              workspace_slug: args["workspace_slug"],
              intent: args["intent"]
            )

          {:ok,
           %{
             action: "load_layout",
             slug: layout.slug,
             scope: layout.scope,
             layout_json: layout.layout_json,
             density: layout.density,
             pane_title_format: layout.pane_title_format
           }}
      end
    end
  end

  @doc false
  def open_file(args) do
    cond do
      is_binary(args["file_id"]) ->
        {:ok,
         %{
           action: "open_pane",
           pane_kind: file_pane_kind(args["editor"]),
           config: %{file_id: args["file_id"], workspace_slug: args["workspace_slug"]}
         }}

      is_binary(args["path"]) ->
        {:ok,
         %{
           action: "open_pane",
           pane_kind: file_pane_kind(args["editor"]),
           config: %{path: args["path"], workspace_slug: args["workspace_slug"]}
         }}

      true ->
        {:error, "either path or file_id is required"}
    end
  end

  @doc false
  def open_block(args) do
    with {:ok, block_id} <- require_string(args["block_id"], "block_id") do
      {:ok,
       %{
         action: "open_pane",
         pane_kind: "block_stream",
         config: %{block_id: block_id, session_id: args["session_id"]}
       }}
    end
  end

  @doc false
  def run_command(args) do
    with {:ok, text} <- require_string(args["text"], "text") do
      {:ok,
       %{
         action: "open_pane",
         pane_kind: "terminal",
         config: %{
           queued_command: text,
           session_id: args["session_id"],
           workspace_slug: args["workspace_slug"],
           cwd: args["cwd"]
         }
       }}
    end
  end

  @doc false
  def set_density(args) do
    case args["level"] do
      level when level in @densities ->
        {:ok, %{action: "set_density", level: level}}

      _ ->
        {:error, "level must be one of: #{Enum.join(@densities, ", ")}"}
    end
  end

  @doc false
  def list_layouts(args) do
    opts =
      []
      |> put_opt(:scope, args["scope"])
      |> put_opt(:owner_id, args["owner_id"])
      |> put_opt(:workspace_slug, args["workspace_slug"])
      |> put_opt(:limit, args["limit"])

    layouts =
      opts
      |> Build.list_layouts()
      |> Enum.map(fn l ->
        %{
          slug: l.slug,
          name: l.name,
          scope: l.scope,
          workspace_slug: l.workspace_slug,
          use_count: l.use_count,
          last_used_at: l.last_used_at,
          description: l.description
        }
      end)

    {:ok, %{count: length(layouts), layouts: layouts}}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp validate_kind(kind) when kind in @pane_kinds, do: {:ok, kind}

  defp validate_kind(other),
    do: {:error, "invalid pane_kind: #{inspect(other)}"}

  defp validate_direction(dir) when dir in @directions, do: {:ok, dir}

  defp validate_direction(other),
    do: {:error, "invalid direction: #{inspect(other)}"}

  defp require_string(s, _name) when is_binary(s) and s != "", do: {:ok, s}
  defp require_string(_, name), do: {:error, "#{name} is required"}

  defp put_opt(opts, _key, nil), do: opts
  defp put_opt(opts, _key, ""), do: opts
  defp put_opt(opts, key, value), do: [{key, value} | opts]

  defp file_pane_kind("file_viewer"), do: "file_viewer"
  defp file_pane_kind("code_editor"), do: "code_editor"
  defp file_pane_kind(_), do: "code_editor"

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> String.slice(0, 128)
  end

  defp format_changeset(%Ecto.Changeset{errors: errors}) do
    errors
    |> Enum.map_join("; ", fn {field, {msg, _}} -> "#{field}: #{msg}" end)
  end
end
