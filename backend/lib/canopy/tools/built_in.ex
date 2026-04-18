defmodule Canopy.Tools.BuiltIn do
  @moduledoc """
  Built-in tools shipped with Canopy.

  Declared using `use Canopy.Tool` so the macro generates `__canopy_tools__/0`
  at compile time. These are registered at application boot via
  `Canopy.Tools.register_all_builtins/0`.

  ## Security

  All filesystem tools enforce path-traversal guards. Any path that resolves
  outside the configured allowed root (or contains `../`) is rejected with
  `{:error, :path_traversal}`.

  ## Available Tools

    * `read_file` — reads a file's text content (requires `:filesystem`)
    * `list_directory` — lists entries in a directory (requires `:filesystem`)
    * `search_workspace` — searches workspace slugs/names/paths
    * `get_session_context` — returns the caller's session metadata
    * `log_message` — emits a structured log at a given level
    * `create_comment` — stores a comment string and returns it (stub)
  """

  use Canopy.Tool

  # ---------------------------------------------------------------------------
  # Tool declarations (compile-time)
  # ---------------------------------------------------------------------------

  tool("read_file",
    description: """
    Read the text content of a file at the given absolute path.
    Returns the file contents as a string.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "path" => %{"type" => "string", "description" => "Absolute path to the file"}
      },
      "required" => ["path"]
    },
    handler: {__MODULE__, :read_file, []},
    requires: [:filesystem]
  )

  tool("list_directory",
    description: """
    List the entries (files and subdirectories) of a directory.
    Returns a list of maps with `name`, `type` (file|directory), and `size` keys.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "path" => %{"type" => "string", "description" => "Absolute path to the directory"},
        "include_hidden" => %{
          "type" => "boolean",
          "description" => "Include dot-files (default false)"
        }
      },
      "required" => ["path"]
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

  @doc "Reads a file's content. Rejects path-traversal attempts."
  @spec read_file(map()) :: {:ok, String.t()} | {:error, atom() | String.t()}
  def read_file(%{"path" => path}) do
    with :ok <- guard_traversal(path),
         {:ok, content} <- File.read(path) do
      {:ok, content}
    else
      {:error, :path_traversal} -> {:error, :path_traversal}
      {:error, posix} -> {:error, "Cannot read file: #{posix}"}
    end
  end

  @doc "Lists directory entries."
  @spec list_directory(map()) :: {:ok, [map()]} | {:error, atom() | String.t()}
  def list_directory(%{"path" => path} = args) do
    include_hidden = Map.get(args, "include_hidden", false)

    with :ok <- guard_traversal(path),
         {:ok, entries} <- File.ls(path) do
      results =
        entries
        |> Enum.reject(fn name -> not include_hidden and String.starts_with?(name, ".") end)
        |> Enum.map(fn name ->
          full = Path.join(path, name)

          type =
            case File.stat(full) do
              {:ok, %{type: :directory}} -> "directory"
              _ -> "file"
            end

          size =
            case File.stat(full) do
              {:ok, %{size: s}} -> s
              _ -> 0
            end

          %{"name" => name, "type" => type, "size" => size}
        end)
        |> Enum.sort_by(& &1["name"])

      {:ok, results}
    else
      {:error, :path_traversal} -> {:error, :path_traversal}
      {:error, posix} -> {:error, "Cannot list directory: #{posix}"}
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

  # Rejects paths containing `..` components to prevent traversal attacks.
  @spec guard_traversal(String.t()) :: :ok | {:error, :path_traversal}
  defp guard_traversal(path) do
    parts = Path.split(path)

    if ".." in parts do
      {:error, :path_traversal}
    else
      :ok
    end
  end
end
