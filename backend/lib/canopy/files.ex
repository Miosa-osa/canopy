defmodule Canopy.Files do
  @moduledoc """
  Public API for the file index — a metadata database layer on top of the
  workspace filesystem.

  Binary content always lives on disk at `workspace.root_path <> "/" <> path`.
  `Canopy.Workspaces.Files` is the low-level I/O API. This module adds:
  - A searchable `files` DB index (metadata, tags, sha256, owner)
  - An append-only `file_activity` log per file
  - A `file_embeddings` pgvector index for semantic search
  - Upload orchestration: write bytes → index metadata → log activity → broadcast

  ## Actor convention

  All write functions accept an `actor` map: `%{type: "user"|"agent"|"system", id: binary}`.

  ## Idempotency

  `index_file/3` and `index_workspace/1` are idempotent. Files whose sha256
  matches the stored value are skipped during workspace scan.
  """

  import Ecto.Query

  alias Canopy.Files.{Activity, FileRecord}
  alias Canopy.Repo
  alias Canopy.Workspaces.Workspace

  require Logger

  @read_throttle_seconds 3600

  # ---------------------------------------------------------------------------
  # Indexing
  # ---------------------------------------------------------------------------

  @doc """
  Indexes (or re-indexes) a single file at `rel_path` within workspace `workspace_id`.

  Steps:
  1. Fetch workspace and stat the file via `Workspaces.Files.stat/2` (guards traversal).
  2. Compute sha256 from disk content.
  3. Upsert the `files` row — insert on first call, update sha256/size/mime on change.
  4. Write a `file_activity` entry with action `"created"` (new) or `"updated"` (changed).
  5. Broadcast `:file_indexed` to the workspace realtime topic.

  Returns `{:ok, %FileRecord{}}` on success.
  """
  @spec index_file(Ecto.UUID.t(), String.t(), map()) ::
          {:ok, FileRecord.t()} | {:error, term()}
  def index_file(workspace_id, rel_path, attrs \\ %{}) do
    with {:ok, workspace} <- get_workspace(workspace_id),
         {:ok, file_stat} <- stat_file(workspace, rel_path),
         {:ok, sha256} <- compute_sha256(workspace, rel_path, file_stat) do
      name = Path.basename(rel_path)
      extension = extract_extension(name)
      mime = mime_from_extension(extension)

      file_attrs =
        Map.merge(
          %{
            workspace_id: workspace_id,
            path: rel_path,
            name: name,
            extension: extension,
            mime_type: mime,
            size_bytes: file_stat.size,
            sha256: sha256,
            last_indexed_at: DateTime.utc_now() |> DateTime.truncate(:second)
          },
          attrs
        )

      result =
        Repo.transaction(fn ->
          {file, action} = upsert_file(workspace_id, rel_path, file_attrs)
          actor = Map.get(attrs, :actor, %{type: "system", id: nil})
          _activity = insert_activity!(file.id, actor, action, %{})
          file
        end)

      case result do
        {:ok, file} ->
          broadcast_file_indexed(workspace, file)
          {:ok, file}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Walks the workspace tree and indexes every non-hidden file.

  Idempotent: files whose sha256 matches the stored value are skipped.
  Hidden files (names starting with `.`) are excluded.

  Returns `{:ok, count}` where count is the number of files newly indexed
  or updated (skipped files are not counted).
  """
  @spec index_workspace(Ecto.UUID.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def index_workspace(workspace_id) do
    with {:ok, workspace} <- get_workspace(workspace_id),
         {:ok, all_paths} <- list_all_paths(workspace, "") do
      {count, _} =
        Enum.reduce(all_paths, {0, []}, fn rel_path, {acc_count, acc_errors} ->
          case index_file_if_changed(workspace, workspace_id, rel_path) do
            :skipped -> {acc_count, acc_errors}
            :indexed -> {acc_count + 1, acc_errors}
            {:error, reason} -> {acc_count, [{rel_path, reason} | acc_errors]}
          end
        end)

      {:ok, count}
    end
  end

  # ---------------------------------------------------------------------------
  # Queries
  # ---------------------------------------------------------------------------

  @doc "Fetches a file by workspace + relative path."
  @spec get_by_path(Ecto.UUID.t(), String.t()) ::
          {:ok, FileRecord.t()} | {:error, :not_found}
  def get_by_path(workspace_id, path) do
    case Repo.one(
           from(f in FileRecord,
             where: f.workspace_id == ^workspace_id and f.path == ^path and is_nil(f.archived_at)
           )
         ) do
      nil -> {:error, :not_found}
      file -> {:ok, file}
    end
  end

  @doc """
  Lists files with optional filters.

  Accepts a map of filters:
  - `:workspace_id` — required
  - `:extension` — e.g. `"md"`
  - `:tag` — single tag string; matches files containing this tag
  - `:owner_type` / `:owner_id` — filter by actor
  - `:q` — ILIKE on path/name (delegates to Search.search_by_name)
  - `:include_archived` — boolean, default false
  - `:limit` — max results (default 50, max 200)
  """
  @spec list(map()) :: {:ok, [FileRecord.t()]}
  def list(filters \\ %{}) do
    workspace_id = Map.fetch!(filters, :workspace_id)
    limit = filters |> Map.get(:limit, 50) |> min(200)
    include_archived = Map.get(filters, :include_archived, false)

    if q = Map.get(filters, :q) do
      search_by_name(workspace_id, q, limit)
    else
      query =
        from(f in FileRecord,
          where: f.workspace_id == ^workspace_id,
          order_by: [asc: f.path],
          limit: ^limit
        )

      query =
        if include_archived, do: query, else: where(query, [f], is_nil(f.archived_at))

      query =
        case Map.get(filters, :extension) do
          nil -> query
          ext -> where(query, [f], f.extension == ^ext)
        end

      query =
        case Map.get(filters, :tag) do
          nil -> query
          tag -> where(query, [f], fragment("? @> ARRAY[?]::varchar[]", f.tags, ^tag))
        end

      query =
        case {Map.get(filters, :owner_type), Map.get(filters, :owner_id)} do
          {nil, _} -> query
          {ot, nil} -> where(query, [f], f.owner_type == ^ot)
          {ot, oid} -> where(query, [f], f.owner_type == ^ot and f.owner_id == ^oid)
        end

      {:ok, Repo.all(query)}
    end
  end

  @doc "Returns the file with the given id, or `{:error, :not_found}`."
  @spec get(Ecto.UUID.t()) :: {:ok, FileRecord.t()} | {:error, :not_found}
  def get(id) do
    case Repo.get(FileRecord, id) do
      nil -> {:error, :not_found}
      file -> {:ok, file}
    end
  end

  # ---------------------------------------------------------------------------
  # Mutations
  # ---------------------------------------------------------------------------

  @doc "Updates the tags list on a file. Logs a `\"tagged\"` activity entry."
  @spec update_tags(Ecto.UUID.t(), [String.t()], map()) ::
          {:ok, FileRecord.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_tags(file_id, new_tags, actor \\ %{type: "system", id: nil}) do
    with {:ok, file} <- get(file_id) do
      old_tags = file.tags
      added = new_tags -- old_tags
      removed = old_tags -- new_tags

      result =
        Repo.transaction(fn ->
          {:ok, updated} = file |> FileRecord.tags_changeset(new_tags) |> Repo.update()

          insert_activity!(file_id, actor, "tagged", %{
            added: added,
            removed: removed
          })

          updated
        end)

      case result do
        {:ok, updated} -> {:ok, updated}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc "Soft-archives a file (sets `archived_at`). Does NOT delete from disk."
  @spec archive(Ecto.UUID.t(), map()) ::
          {:ok, FileRecord.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def archive(file_id, actor \\ %{type: "system", id: nil}) do
    with {:ok, file} <- get(file_id) do
      result =
        Repo.transaction(fn ->
          {:ok, archived} = file |> FileRecord.archive_changeset() |> Repo.update()
          insert_activity!(file_id, actor, "deleted", %{})
          archived
        end)

      case result do
        {:ok, archived} -> {:ok, archived}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Activity helpers
  # ---------------------------------------------------------------------------

  @doc """
  Directly appends an activity entry for a file.

  Used by other modules when they perform file-touching operations (e.g. the
  WorkspaceFilesController write action calls this after a successful write).

  `actor` must be `%{type: "user"|"agent"|"system", id: binary | nil}`.
  `action` must be one of: `"created" | "updated" | "read" | "deleted" | "renamed" | "tagged"`.
  """
  @spec log_activity(Ecto.UUID.t(), map(), String.t(), map()) ::
          {:ok, Activity.t()} | {:error, Ecto.Changeset.t()}
  def log_activity(file_id, actor, action, metadata \\ %{}) do
    attrs = %{
      file_id: file_id,
      actor_type: Map.get(actor, :type, "system"),
      actor_id: to_string(Map.get(actor, :id, "")),
      action: action,
      metadata: metadata,
      occurred_at: DateTime.utc_now()
    }

    %Activity{}
    |> Activity.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Records a read event for a file by an actor.

  Throttled: only one read logged per (file_id, actor_type, actor_id) per hour.
  Subsequent reads within the same hour window are silently dropped.

  Returns `{:ok, :logged}` when the activity was inserted, `{:ok, :throttled}`
  when suppressed, or `{:error, reason}` on DB failure.
  """
  @spec record_read(Ecto.UUID.t(), map()) ::
          {:ok, :logged | :throttled} | {:error, term()}
  def record_read(file_id, actor) do
    actor_type = Map.get(actor, :type, "system")
    actor_id = to_string(Map.get(actor, :id, ""))
    threshold = DateTime.add(DateTime.utc_now(), -@read_throttle_seconds, :second)

    recent =
      Repo.exists?(
        from(a in Activity,
          where:
            a.file_id == ^file_id and
              a.actor_type == ^actor_type and
              a.actor_id == ^actor_id and
              a.action == "read" and
              a.occurred_at > ^threshold
        )
      )

    if recent do
      {:ok, :throttled}
    else
      case log_activity(file_id, actor, "read", %{}) do
        {:ok, _} -> {:ok, :logged}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Records a rename operation: updates the file row's path and logs activity.

  The `actor` map is used for the activity log entry. The actual filesystem
  move must have already succeeded (via `Workspaces.Files.move_file/3`) before
  calling this.
  """
  @spec record_rename(String.t(), String.t(), Ecto.UUID.t(), map()) ::
          {:ok, FileRecord.t()} | {:error, :not_found | term()}
  def record_rename(old_path, new_path, workspace_id, actor) do
    with {:ok, file} <- get_by_path(workspace_id, old_path) do
      new_name = Path.basename(new_path)
      new_ext = extract_extension(new_name)

      result =
        Repo.transaction(fn ->
          {:ok, updated} =
            file
            |> FileRecord.update_changeset(%{
              path: new_path,
              name: new_name,
              extension: new_ext,
              mime_type: mime_from_extension(new_ext)
            })
            |> Repo.update()

          insert_activity!(file.id, actor, "renamed", %{
            old_path: old_path,
            new_path: new_path
          })

          updated
        end)

      case result do
        {:ok, updated} -> {:ok, updated}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc "Returns the activity log for a file, newest first."
  @spec list_activity(Ecto.UUID.t(), pos_integer()) :: {:ok, [Activity.t()]}
  def list_activity(file_id, limit \\ 50) do
    activities =
      from(a in Activity,
        where: a.file_id == ^file_id,
        order_by: [desc: a.occurred_at],
        limit: ^min(limit, 200)
      )
      |> Repo.all()

    {:ok, activities}
  end

  # ---------------------------------------------------------------------------
  # Name search (inline — no separate Search module)
  # ---------------------------------------------------------------------------

  @doc "ILIKE name search for files within a workspace. Returns `{:ok, [FileRecord.t()]}`."
  @spec search_by_name(Ecto.UUID.t(), String.t(), pos_integer()) :: {:ok, [FileRecord.t()]}
  def search_by_name(workspace_id, query, limit \\ 20) when is_binary(query) do
    pattern = "%#{String.replace(query, ["%", "_"], fn c -> "\\#{c}" end)}%"
    cap = min(limit, 200)

    results =
      from(f in FileRecord,
        where:
          f.workspace_id == ^workspace_id and
            is_nil(f.archived_at) and
            ilike(f.name, ^pattern),
        order_by: [asc: f.path],
        limit: ^cap
      )
      |> Repo.all()

    {:ok, results}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec get_workspace(Ecto.UUID.t()) :: {:ok, Workspace.t()} | {:error, :not_found}
  defp get_workspace(workspace_id) do
    case Repo.get(Workspace, workspace_id) do
      nil -> {:error, :not_found}
      ws -> {:ok, ws}
    end
  end

  # Stat a file using Workspaces.Files.list_dir to verify it exists on disk.
  # Falls back to File.stat for the actual size — list_dir gives us enough info.
  @spec stat_file(Workspace.t(), String.t()) :: {:ok, map()} | {:error, term()}
  defp stat_file(workspace, rel_path) do
    abs_path = Path.join(workspace.root_path, rel_path)

    case File.stat(abs_path) do
      {:ok, stat} when stat.type != :directory -> {:ok, stat}
      {:ok, _} -> {:error, :is_directory}
      {:error, :enoent} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec compute_sha256(Workspace.t(), String.t(), map()) ::
          {:ok, String.t()} | {:error, term()}
  defp compute_sha256(workspace, rel_path, stat) when stat.size <= 50 * 1024 * 1024 do
    abs_path = Path.join(workspace.root_path, rel_path)

    case File.read(abs_path) do
      {:ok, bytes} ->
        hash = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
        {:ok, hash}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp compute_sha256(_workspace, _rel_path, _stat), do: {:ok, nil}

  # Upsert logic: insert if new, update sha256/size if content changed.
  # Returns `{file, action}` where action is "created" or "updated".
  @spec upsert_file(Ecto.UUID.t(), String.t(), map()) :: {FileRecord.t(), String.t()}
  defp upsert_file(workspace_id, rel_path, attrs) do
    existing =
      Repo.one(
        from(f in FileRecord,
          where: f.workspace_id == ^workspace_id and f.path == ^rel_path
        )
      )

    case existing do
      nil ->
        {:ok, file} =
          %FileRecord{}
          |> FileRecord.changeset(attrs)
          |> Repo.insert()

        {file, "created"}

      file ->
        {:ok, updated} =
          file
          |> FileRecord.update_changeset(attrs)
          |> Repo.update()

        {updated, "updated"}
    end
  end

  @spec insert_activity!(Ecto.UUID.t(), map(), String.t(), map()) :: Activity.t()
  defp insert_activity!(file_id, actor, action, metadata) do
    attrs = %{
      file_id: file_id,
      actor_type: Map.get(actor, :type, "system"),
      actor_id: to_string(Map.get(actor, :id, "")),
      action: action,
      metadata: metadata,
      occurred_at: DateTime.utc_now()
    }

    {:ok, activity} =
      %Activity{}
      |> Activity.changeset(attrs)
      |> Repo.insert()

    activity
  end

  @spec list_all_paths(Workspace.t(), String.t()) :: {:ok, [String.t()]} | {:error, term()}
  defp list_all_paths(workspace, rel_dir) do
    abs_dir = Path.join(workspace.root_path, rel_dir)

    case File.ls(abs_dir) do
      {:ok, entries} ->
        paths =
          entries
          |> Enum.reject(&String.starts_with?(&1, "."))
          |> Enum.flat_map(fn entry ->
            sub_rel = if rel_dir == "", do: entry, else: Path.join(rel_dir, entry)
            abs_entry = Path.join(workspace.root_path, sub_rel)

            if File.dir?(abs_entry) do
              case list_all_paths(workspace, sub_rel) do
                {:ok, sub_paths} -> sub_paths
                {:error, _} -> []
              end
            else
              [sub_rel]
            end
          end)

        {:ok, paths}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Index a file only if sha256 has changed (or file is new).
  @spec index_file_if_changed(Workspace.t(), Ecto.UUID.t(), String.t()) ::
          :skipped | :indexed | {:error, term()}
  defp index_file_if_changed(workspace, workspace_id, rel_path) do
    existing =
      Repo.one(
        from(f in FileRecord,
          where: f.workspace_id == ^workspace_id and f.path == ^rel_path,
          select: f.sha256
        )
      )

    abs_path = Path.join(workspace.root_path, rel_path)

    with {:ok, %{size: size}} when size <= 50 * 1024 * 1024 <- File.stat(abs_path),
         {:ok, bytes} <- File.read(abs_path) do
      new_sha256 = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

      if existing == new_sha256 do
        :skipped
      else
        case index_file(workspace_id, rel_path, %{}) do
          {:ok, _} -> :indexed
          {:error, reason} -> {:error, reason}
        end
      end
    else
      {:ok, _large_stat} -> :skipped
      {:error, reason} -> {:error, reason}
    end
  end

  @spec broadcast_file_indexed(Workspace.t(), FileRecord.t()) :: :ok
  defp broadcast_file_indexed(workspace, file) do
    Phoenix.PubSub.broadcast(
      Canopy.PubSub,
      "workspace:#{workspace.slug}",
      {:file_indexed, %{file_id: file.id, path: file.path}}
    )

    :ok
  end

  @spec extract_extension(String.t()) :: String.t() | nil
  defp extract_extension(name) do
    case Path.extname(name) do
      "" -> nil
      "." <> ext -> ext
    end
  end

  @spec mime_from_extension(String.t() | nil) :: String.t()
  defp mime_from_extension(nil), do: "application/octet-stream"

  defp mime_from_extension(ext) do
    case String.downcase(ext) do
      "md" -> "text/markdown"
      "txt" -> "text/plain"
      "html" -> "text/html"
      "htm" -> "text/html"
      "css" -> "text/css"
      "js" -> "application/javascript"
      "ts" -> "application/typescript"
      "json" -> "application/json"
      "yaml" -> "application/yaml"
      "yml" -> "application/yaml"
      "toml" -> "application/toml"
      "xml" -> "application/xml"
      "csv" -> "text/csv"
      "png" -> "image/png"
      "jpg" -> "image/jpeg"
      "jpeg" -> "image/jpeg"
      "gif" -> "image/gif"
      "svg" -> "image/svg+xml"
      "webp" -> "image/webp"
      "pdf" -> "application/pdf"
      "zip" -> "application/zip"
      "ex" -> "text/plain"
      "exs" -> "text/plain"
      "rs" -> "text/plain"
      "go" -> "text/plain"
      "py" -> "text/x-python"
      "sh" -> "application/x-sh"
      _ -> "application/octet-stream"
    end
  end
end
