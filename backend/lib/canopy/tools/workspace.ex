defmodule Canopy.Tools.Workspace do
  @moduledoc """
  MCP tool surface for workspace filesystem and state access.

  Exposes `workspace.*` tools that let agents programmatically CRUD workspace
  state — files, sessions, Drive entries — turning every Canopy workspace into
  an agent-accessible knowledge base.

  ## Tool list

  - `workspace.list_files`        — list files in a workspace directory
  - `workspace.read_file`         — read a file's contents
  - `workspace.write_file`        — write / create a file
  - `workspace.search_files`      — ripgrep search across workspace
  - `workspace.list_sessions`     — list sessions in a workspace
  - `workspace.list_drive_entries`— list Drive entries (optionally filtered)
  - `workspace.create_drive_entry`— create a Drive entry
  - `workspace.get_workspace_info`— fetch workspace metadata
  """

  use Canopy.Tool

  alias Canopy.Drive
  alias Canopy.Search
  alias Canopy.Sessions
  alias Canopy.Workspaces
  alias Canopy.Workspaces.Files

  # ---------------------------------------------------------------------------
  # Tool declarations
  # ---------------------------------------------------------------------------

  tool("workspace.list_files",
    description: """
    List files and directories at a path inside a workspace. Returns entries
    ordered by name. Defaults to the workspace root when path is omitted.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string", "description" => "Slug of the workspace"},
        "path" => %{
          "type" => "string",
          "description" => "Relative path inside the workspace (default: root)"
        }
      },
      "required" => ["workspace_slug"]
    },
    handler: {__MODULE__, :list_files, []},
    requires: []
  )

  tool("workspace.read_file",
    description: "Read the UTF-8 contents of a file inside a workspace.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string"},
        "path" => %{"type" => "string", "description" => "Relative path to the file"}
      },
      "required" => ["workspace_slug", "path"]
    },
    handler: {__MODULE__, :read_file, []},
    requires: []
  )

  tool("workspace.write_file",
    description: """
    Write (create or overwrite) a file inside a workspace. Parent directories
    are created automatically. Write is atomic.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string"},
        "path" => %{"type" => "string", "description" => "Relative path for the file"},
        "contents" => %{"type" => "string", "description" => "UTF-8 file contents"}
      },
      "required" => ["workspace_slug", "path", "contents"]
    },
    handler: {__MODULE__, :write_file, []},
    requires: []
  )

  tool("workspace.search_files",
    description: """
    Search for a pattern across all files in a workspace. Uses ripgrep when
    available, falling back to a pure-Elixir backend.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string"},
        "query" => %{"type" => "string", "description" => "Search pattern"},
        "regex" => %{
          "type" => "boolean",
          "description" => "Treat query as a regular expression (default false)"
        }
      },
      "required" => ["workspace_slug", "query"]
    },
    handler: {__MODULE__, :search_files, []},
    requires: []
  )

  tool("workspace.list_sessions",
    description: "List sessions. Optionally filter by workspace_slug and/or status.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{
          "type" => "string",
          "description" => "Filter to a specific workspace"
        },
        "status" => %{
          "type" => "string",
          "description" => "Filter by session status (e.g. running, completed, failed)"
        },
        "limit" => %{"type" => "integer", "description" => "Max results (default 50)"}
      }
    },
    handler: {__MODULE__, :list_sessions, []},
    requires: []
  )

  tool("workspace.list_drive_entries",
    description: "List Drive entries. Optionally filter by workspace_slug and/or kind.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{
          "type" => "string",
          "description" => "Filter entries whose slug matches this workspace"
        },
        "kind" => %{
          "type" => "string",
          "description" => "Filter by entry kind (folder, workflow, prompt, notebook, rule, …)"
        }
      }
    },
    handler: {__MODULE__, :list_drive_entries, []},
    requires: [:drive]
  )

  tool("workspace.create_drive_entry",
    description: """
    Create a Drive entry. Supported kinds: workflow, prompt, notebook, rule.
    The entry is created in the personal scope with no parent (top-level).
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "kind" => %{
          "type" => "string",
          "enum" => ["workflow", "prompt", "notebook", "rule"],
          "description" => "Kind of Drive entry to create"
        },
        "title" => %{
          "type" => "string",
          "description" => "Human-readable title (becomes the entry name)"
        },
        "body" => %{"type" => "string", "description" => "Markdown body content"}
      },
      "required" => ["kind", "title", "body"]
    },
    handler: {__MODULE__, :create_drive_entry, []},
    requires: [:drive]
  )

  tool("workspace.get_workspace_info",
    description: "Fetch workspace metadata by slug.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string"}
      },
      "required" => ["workspace_slug"]
    },
    handler: {__MODULE__, :get_workspace_info, []},
    requires: []
  )

  # ---------------------------------------------------------------------------
  # Handlers
  # ---------------------------------------------------------------------------

  @doc false
  def list_files(%{"workspace_slug" => slug} = args) do
    path = args["path"] || ""

    with {:ok, workspace} <- Workspaces.get_by_slug(slug),
         {:ok, entries} <- Files.list_dir(workspace, path) do
      serialized =
        Enum.map(entries, fn e ->
          %{
            name: e.name,
            path: if(path == "", do: e.name, else: Path.join(path, e.name)),
            is_dir: e.is_dir,
            size: e.size
          }
        end)

      {:ok, %{count: length(serialized), entries: serialized}}
    else
      {:error, :not_found} -> {:error, :workspace_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  def read_file(%{"workspace_slug" => slug, "path" => path}) do
    with {:ok, workspace} <- Workspaces.get_by_slug(slug),
         {:ok, content} <- Files.read_file(workspace, path) do
      stat =
        case File.stat(Path.join(workspace.root_path, path)) do
          {:ok, s} -> s
          _ -> %{size: byte_size(content)}
        end

      mime =
        path
        |> Path.extname()
        |> ext_to_mime()

      {:ok, %{path: path, content: content, size: stat.size, mime_type: mime}}
    else
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  def write_file(%{"workspace_slug" => slug, "path" => path, "contents" => contents}) do
    with {:ok, workspace} <- Workspaces.get_by_slug(slug),
         :ok <- Files.write_file(workspace, path, contents) do
      abs = Path.join(workspace.root_path, path)

      size =
        case File.stat(abs) do
          {:ok, s} -> s.size
          _ -> byte_size(contents)
        end

      {:ok, %{path: path, size: size}}
    else
      {:error, :not_found} -> {:error, :workspace_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  def search_files(%{"workspace_slug" => slug, "query" => query} = args) do
    regex = !!args["regex"]

    case Search.search(query, slug, regex: regex) do
      {:ok, %{matches: matches}} ->
        results =
          Enum.map(matches, fn m ->
            %{file: m.file_path, line: m.line_number, text: m.line_text}
          end)

        {:ok, %{count: length(results), results: results}}

      {:error, :workspace_not_found} ->
        {:error, :workspace_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  def list_sessions(args) do
    opts =
      []
      |> put_opt(:workspace, args["workspace_slug"])
      |> put_opt(:status, args["status"])
      |> put_opt(:limit, args["limit"])

    {:ok, sessions} = Sessions.list(opts)

    {:ok,
     %{
       count: length(sessions),
       sessions: Enum.map(sessions, &serialize_session/1)
     }}
  end

  @doc false
  def list_drive_entries(args) do
    opts =
      []
      |> put_opt(:kind, args["kind"])

    entries = Drive.list(opts)

    {:ok,
     %{
       count: length(entries),
       entries: Enum.map(entries, &serialize_drive_entry/1)
     }}
  end

  @doc false
  def create_drive_entry(%{"kind" => kind, "title" => title, "body" => body}) do
    slug = title |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")

    # Build the body map in the shape each kind expects.
    # workflow/notebook/env_vars/mcp_server require foreign-key envelopes and
    # cannot be created with plain text bodies — only prompt and rule are
    # standalone body kinds; folder accepts an empty body.
    body_map =
      case kind do
        k when k in ["prompt", "rule"] -> %{"content" => body}
        "folder" -> %{}
        _ -> %{"content" => body}
      end

    attrs = %{
      slug: "#{slug}-#{System.unique_integer([:positive])}",
      name: title,
      kind: kind,
      scope: "personal",
      body: body_map
    }

    case Drive.create(attrs) do
      {:ok, entry} -> {:ok, serialize_drive_entry(entry)}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  @doc false
  def get_workspace_info(%{"workspace_slug" => slug}) do
    case Workspaces.get_by_slug(slug) do
      {:ok, workspace} ->
        {:ok,
         %{
           slug: workspace.slug,
           name: workspace.name,
           root_path: workspace.root_path,
           created_at: workspace.inserted_at
         }}

      {:error, :not_found} ->
        {:error, :workspace_not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp put_opt(opts, _key, nil), do: opts
  defp put_opt(opts, key, value), do: [{key, value} | opts]

  defp serialize_session(s) do
    %{
      id: s.id,
      status: s.status,
      runtime_type: s.runtime_type,
      agent_slug: s.agent_slug,
      workspace_slug: s.workspace_slug,
      cwd: s.cwd,
      inserted_at: s.inserted_at,
      completed_at: Map.get(s, :completed_at)
    }
  end

  defp serialize_drive_entry(e) do
    %{
      id: e.id,
      slug: e.slug,
      name: e.name,
      kind: e.kind,
      scope: e.scope,
      body: e.body,
      tags: e.tags,
      inserted_at: e.inserted_at
    }
  end

  defp format_errors(%Ecto.Changeset{} = cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc ->
        String.replace(acc, "%{#{k}}", to_string(v))
      end)
    end)
  end

  defp ext_to_mime(ext) do
    case String.downcase(ext) do
      ".md" -> "text/markdown"
      ".txt" -> "text/plain"
      ".json" -> "application/json"
      ".yaml" -> "application/yaml"
      ".yml" -> "application/yaml"
      ".ex" -> "text/plain"
      ".exs" -> "text/plain"
      ".js" -> "text/javascript"
      ".ts" -> "text/typescript"
      ".html" -> "text/html"
      ".css" -> "text/css"
      ".sh" -> "text/x-sh"
      _ -> "text/plain"
    end
  end
end
