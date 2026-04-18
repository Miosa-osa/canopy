defmodule Canopy.Tools.BuiltIn do
  @moduledoc """
  Built-in tools shipped with Canopy.

  Declared using `use Canopy.Tool` so the macro generates `__canopy_tools__/0`
  at compile time. These are registered at application boot via
  `Canopy.Tools.register_all_builtins/0`.

  ## Security

  All filesystem tools are **workspace-scoped**. Callers must supply a
  `workspace_slug` that resolves to an existing workspace; file paths are
  relative to that workspace's `root_path` and are validated by
  `Canopy.Workspaces.Files` (which enforces traversal guards and size limits).

  Errors returned by the filesystem tools:
    * `{:error, :missing_workspace_slug}` — `workspace_slug` key absent from args
    * `{:error, :workspace_not_found}` — no workspace with that slug exists
    * `{:error, :path_traversal}` — relative path escapes the workspace root

  ## Available Tools

    * `read_file` — reads a file relative to a workspace (requires `:filesystem`)
    * `list_directory` — lists entries relative to a workspace (requires `:filesystem`)
    * `search_workspace` — searches workspace slugs/names/paths
    * `get_session_context` — returns the caller's session metadata
    * `log_message` — emits a structured log at a given level
    * `create_comment` — stores a comment string and returns it (stub)
  """

  use Canopy.Tool

  alias Canopy.Workspaces
  alias Canopy.Workspaces.Files

  # ---------------------------------------------------------------------------
  # Tool declarations (compile-time)
  # ---------------------------------------------------------------------------

  tool("read_file",
    description: """
    Read the text content of a file inside a workspace.
    The path must be relative to the workspace root — absolute paths are rejected.
    Returns the file contents as a string.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{
          "type" => "string",
          "description" => "Slug of the workspace that contains the file"
        },
        "path" => %{
          "type" => "string",
          "description" => "Relative path inside the workspace (e.g. \"README.md\")"
        }
      },
      "required" => ["workspace_slug", "path"]
    },
    handler: {__MODULE__, :read_file, []},
    requires: [:filesystem]
  )

  tool("list_directory",
    description: """
    List the entries (files and subdirectories) of a directory inside a workspace.
    The path must be relative to the workspace root.
    Returns a list of maps with `name`, `type` (file|directory), and `size` keys.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{
          "type" => "string",
          "description" => "Slug of the workspace to list files in"
        },
        "path" => %{
          "type" => "string",
          "description" => "Relative directory path inside the workspace (default: root)"
        },
        "include_hidden" => %{
          "type" => "boolean",
          "description" => "Include dot-files (default false)"
        }
      },
      "required" => ["workspace_slug"]
    },
    handler: {__MODULE__, :list_directory, []},
    requires: [:filesystem]
  )

  tool("search_workspace",
    description: """
    Search workspace records by name, slug, or root path.
    Returns matching workspaces from the Canopy database.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "query" => %{
          "type" => "string",
          "description" => "Search term matched against name, slug, and root_path"
        },
        "limit" => %{
          "type" => "integer",
          "description" => "Maximum number of results to return (default 10)"
        }
      },
      "required" => ["query"]
    },
    handler: {__MODULE__, :search_workspace, []},
    requires: []
  )

  tool("get_session_context",
    description: """
    Return metadata about the current agent session: session_id, runtime_type,
    workspace slug (if any), and current working directory.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "session_id" => %{
          "type" => "string",
          "description" => "ID of the session to retrieve context for"
        }
      },
      "required" => ["session_id"]
    },
    handler: {__MODULE__, :get_session_context, []},
    requires: []
  )

  tool("log_message",
    description: """
    Emit a structured log message at the specified level.
    Useful for agents to leave an audit trail without modifying files.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "level" => %{
          "type" => "string",
          "enum" => ["debug", "info", "warning", "error"],
          "description" => "Log level"
        },
        "message" => %{"type" => "string", "description" => "Log message"},
        "metadata" => %{
          "type" => "object",
          "description" => "Optional key-value metadata to attach to the log entry"
        }
      },
      "required" => ["level", "message"]
    },
    handler: {__MODULE__, :log_message, []},
    requires: [],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("create_comment",
    description: """
    Store a comment string associated with a resource (stub — returns the
    comment back). Full persistence is Week 3 scope.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "resource_id" => %{"type" => "string", "description" => "ID of the resource to annotate"},
        "body" => %{"type" => "string", "description" => "Comment text"}
      },
      "required" => ["resource_id", "body"]
    },
    handler: {__MODULE__, :create_comment, []},
    requires: []
  )

  # ---------------------------------------------------------------------------
  # Handler implementations
  # ---------------------------------------------------------------------------

  @doc """
  Reads a file's content scoped to the given workspace.

  Requires `workspace_slug` and a relative `path`. The workspace root is
  resolved via `Canopy.Workspaces.get_by_slug/1`; the file is read via
  `Canopy.Workspaces.Files.read_file/2`, which enforces traversal guards and
  a 10 MB size limit.
  """
  @spec read_file(map()) :: {:ok, String.t()} | {:error, atom() | String.t()}
  def read_file(args) do
    with {:ok, slug} <- require_slug(args),
         {:ok, workspace} <- resolve_workspace(slug),
         rel_path = Map.get(args, "path", ""),
         {:ok, content} <- Files.read_file(workspace, rel_path) do
      {:ok, content}
    else
      {:error, :missing_workspace_slug} -> {:error, :missing_workspace_slug}
      {:error, :workspace_not_found} -> {:error, :workspace_not_found}
      {:error, :traversal} -> {:error, :path_traversal}
      {:error, :not_found} -> {:error, "File not found"}
      {:error, :too_large} -> {:error, "File exceeds 10 MB limit"}
      {:error, :not_utf8} -> {:error, "File is not valid UTF-8"}
      {:error, reason} -> {:error, "Cannot read file: #{inspect(reason)}"}
    end
  end

  @doc """
  Lists directory entries scoped to the given workspace.

  Requires `workspace_slug`. `path` defaults to the workspace root when absent.
  Entries include `name`, `type` (file|directory), and `size` keys.
  """
  @spec list_directory(map()) :: {:ok, [map()]} | {:error, atom() | String.t()}
  def list_directory(args) do
    include_hidden = Map.get(args, "include_hidden", false)
    rel_path = Map.get(args, "path", "")

    with {:ok, slug} <- require_slug(args),
         {:ok, workspace} <- resolve_workspace(slug),
         {:ok, entries} <- Files.list_dir(workspace, rel_path) do
      results =
        entries
        |> Enum.reject(fn e ->
          not include_hidden and String.starts_with?(e.name, ".")
        end)
        |> Enum.map(fn e ->
          %{
            "name" => e.name,
            "type" => if(e.is_dir, do: "directory", else: "file"),
            "size" => e.size
          }
        end)
        |> Enum.sort_by(& &1["name"])

      {:ok, results}
    else
      {:error, :missing_workspace_slug} -> {:error, :missing_workspace_slug}
      {:error, :workspace_not_found} -> {:error, :workspace_not_found}
      {:error, :traversal} -> {:error, :path_traversal}
      {:error, :not_found} -> {:error, "Directory not found"}
      {:error, reason} -> {:error, "Cannot list directory: #{inspect(reason)}"}
    end
  end

  @doc "Searches workspace records by query string."
  @spec search_workspace(map()) :: {:ok, [map()]}
  def search_workspace(%{"query" => query} = args) do
    limit = Map.get(args, "limit", 10)
    {:ok, workspaces} = Canopy.Workspaces.list()

    q = String.downcase(query)

    results =
      workspaces
      |> Enum.filter(fn ws ->
        String.contains?(String.downcase(ws.name), q) or
          String.contains?(String.downcase(ws.slug), q) or
          (ws.root_path && String.contains?(String.downcase(ws.root_path), q))
      end)
      |> Enum.take(limit)
      |> Enum.map(fn ws ->
        %{"id" => ws.id, "slug" => ws.slug, "name" => ws.name, "root_path" => ws.root_path}
      end)

    {:ok, results}
  end

  @doc "Returns basic session context. Full impl is Week 3 scope."
  @spec get_session_context(map()) :: {:ok, map()} | {:error, :not_found}
  def get_session_context(%{"session_id" => session_id}) do
    case Canopy.Sessions.get(session_id) do
      {:ok, session} ->
        {:ok,
         %{
           "session_id" => session.id,
           "runtime_type" => session.runtime_type,
           "status" => session.status,
           "cwd" => session.cwd
         }}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc "Emits a structured log entry and returns a confirmation map."
  @spec log_message(map()) :: {:ok, map()}
  def log_message(%{"level" => level, "message" => message} = args) do
    metadata = Map.get(args, "metadata", %{})

    case level do
      "debug" ->
        require Logger
        Logger.debug(message, metadata: metadata)

      "info" ->
        require Logger
        Logger.info(message, metadata: metadata)

      "warning" ->
        require Logger
        Logger.warning(message, metadata: metadata)

      "error" ->
        require Logger
        Logger.error(message, metadata: metadata)

      _ ->
        require Logger
        Logger.info(message, metadata: metadata)
    end

    {:ok, %{"logged" => true, "level" => level, "message" => message}}
  end

  @doc "Creates a comment record (stub — returns the comment as confirmation)."
  @spec create_comment(map()) :: {:ok, map()}
  def create_comment(%{"resource_id" => resource_id, "body" => body}) do
    {:ok,
     %{
       "resource_id" => resource_id,
       "body" => body,
       "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()
     }}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Returns {:ok, slug} when "workspace_slug" is present and non-empty.
  @spec require_slug(map()) :: {:ok, String.t()} | {:error, :missing_workspace_slug}
  defp require_slug(args) do
    case Map.get(args, "workspace_slug") do
      slug when is_binary(slug) and slug != "" -> {:ok, slug}
      _ -> {:error, :missing_workspace_slug}
    end
  end

  # Resolves a workspace slug to a Workspace struct.
  @spec resolve_workspace(String.t()) ::
          {:ok, Canopy.Workspaces.Workspace.t()} | {:error, :workspace_not_found}
  defp resolve_workspace(slug) do
    case Workspaces.get_by_slug(slug) do
      {:ok, workspace} -> {:ok, workspace}
      {:error, :not_found} -> {:error, :workspace_not_found}
    end
  end
end
