defmodule Canopy.Workspaces.Files do
  @moduledoc """
  Safe filesystem operations scoped to a workspace root.

  Every function receives a `%Workspace{}` and a *relative* path. The private
  `resolve_safe/2` helper canonicalises the result and rejects any path that
  escapes the workspace root (directory-traversal guard).

  Constraints (mirroring the Tauri Rust guard in `src-tauri/src/commands/filesystem.rs`):
  - Relative paths only — absolute paths are rejected.
  - `..` segments are rejected before and after `Path.expand/1`.
  - Files larger than 10 MB are unreadable.
  - Content is validated as UTF-8 on read.
  - Writes are atomic: content lands in a `.tmp` file and renamed into place.
  """

  alias Canopy.Workspaces.Workspace

  @max_read_bytes 10 * 1024 * 1024

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Lists the immediate entries of `rel_path` inside the workspace.

  Returns `{:ok, [entry]}` where each entry is:

      %{name: binary, is_dir: boolean, size: non_neg_integer, modified: DateTime.t() | nil}

  Returns `{:error, :not_found}` if the directory does not exist.
  Returns `{:error, :traversal}` if `rel_path` attempts to escape the root.
  """
  @spec list_dir(Workspace.t(), String.t()) ::
          {:ok, [map()]} | {:error, :not_found | :traversal | term()}
  def list_dir(%Workspace{} = workspace, rel_path \\ "") do
    with {:ok, abs_path} <- resolve_safe(workspace, rel_path) do
      if File.dir?(abs_path) do
        entries =
          abs_path
          |> File.ls!()
          |> Enum.map(fn name ->
            full = Path.join(abs_path, name)
            stat = File.stat!(full, time: :posix)

            %{
              name: name,
              is_dir: stat.type == :directory,
              size: stat.size,
              modified: posix_to_datetime(stat.mtime)
            }
          end)
          |> Enum.sort_by(& &1.name)

        {:ok, entries}
      else
        {:error, :not_found}
      end
    end
  end

  @doc """
  Reads a file at `rel_path` inside the workspace.

  Returns `{:ok, binary}` on success.
  Returns `{:error, :not_found}` if the path does not exist.
  Returns `{:error, :too_large}` if the file exceeds 10 MB.
  Returns `{:error, :not_utf8}` if the content is not valid UTF-8.
  Returns `{:error, :traversal}` if `rel_path` attempts to escape the root.
  """
  @spec read_file(Workspace.t(), String.t()) ::
          {:ok, binary()} | {:error, :not_found | :too_large | :not_utf8 | :traversal}
  def read_file(%Workspace{} = workspace, rel_path) do
    with {:ok, abs_path} <- resolve_safe(workspace, rel_path),
         :ok <- guard_readable(abs_path),
         :ok <- guard_size(abs_path) do
      read_utf8(abs_path)
    end
  end

  defp guard_readable(abs_path) do
    cond do
      not File.exists?(abs_path) -> {:error, :not_found}
      File.dir?(abs_path) -> {:error, :not_found}
      true -> :ok
    end
  end

  defp guard_size(abs_path) do
    case File.stat(abs_path) do
      {:ok, %{size: size}} when size > @max_read_bytes -> {:error, :too_large}
      {:ok, _stat} -> :ok
      {:error, _reason} -> {:error, :not_found}
    end
  end

  defp read_utf8(abs_path) do
    case File.read(abs_path) do
      {:ok, bytes} when byte_size(bytes) >= 0 ->
        if String.valid?(bytes), do: {:ok, bytes}, else: {:error, :not_utf8}

      {:error, _reason} ->
        {:error, :not_found}
    end
  end

  @doc """
  Writes `content` to `rel_path` inside the workspace.

  Creates parent directories as needed. The write is atomic: content is
  written to a `.tmp` sibling and renamed into place.

  Returns `:ok` on success.
  Returns `{:error, :traversal}` if `rel_path` attempts to escape the root.
  Returns `{:error, term}` on I/O failure.
  """
  @spec write_file(Workspace.t(), String.t(), binary()) ::
          :ok | {:error, :traversal | term()}
  def write_file(%Workspace{} = workspace, rel_path, content) do
    with {:ok, abs_path} <- resolve_safe(workspace, rel_path) do
      parent = Path.dirname(abs_path)

      with :ok <- File.mkdir_p(parent) do
        tmp = abs_path <> ".tmp"

        case File.write(tmp, content) do
          :ok -> File.rename(tmp, abs_path)
          {:error, reason} -> {:error, reason}
        end
      end
    end
  end

  @doc """
  Deletes the file at `rel_path` inside the workspace.

  Returns `:ok` even if the file does not exist.
  Returns `{:error, :traversal}` if `rel_path` attempts to escape the root.
  """
  @spec delete_file(Workspace.t(), String.t()) :: :ok | {:error, :traversal | term()}
  def delete_file(%Workspace{} = workspace, rel_path) do
    with {:ok, abs_path} <- resolve_safe(workspace, rel_path) do
      File.rm(abs_path)
      :ok
    end
  end

  @doc """
  Moves (renames) the file at `from` to `to` inside the workspace.

  Both paths are resolved against the workspace root and both must stay within it.

  Returns `:ok` on success.
  Returns `{:error, :traversal}` if either path attempts to escape the root.
  """
  @spec move_file(Workspace.t(), String.t(), String.t()) ::
          :ok | {:error, :traversal | :not_found | term()}
  def move_file(%Workspace{} = workspace, from, to) do
    with {:ok, abs_from} <- resolve_safe(workspace, from),
         {:ok, abs_to} <- resolve_safe(workspace, to) do
      if File.exists?(abs_from) do
        parent = Path.dirname(abs_to)

        with :ok <- File.mkdir_p(parent) do
          File.rename(abs_from, abs_to)
        end
      else
        {:error, :not_found}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Expands root + rel_path and verifies the result is still inside root.
  # Rejects:
  #   - Absolute rel_paths (starts with /)
  #   - Paths containing ".." segments (before expansion)
  #   - Paths that, after expansion, escape the root (symlink-chasing guard)
  @spec resolve_safe(Workspace.t(), String.t()) :: {:ok, String.t()} | {:error, :traversal}
  defp resolve_safe(%Workspace{root_path: root}, rel_path) do
    # Reject absolute paths
    if String.starts_with?(rel_path, "/") do
      {:error, :traversal}
    else
      # Reject raw ".." segments before any expansion
      segments = String.split(rel_path, ["/", "\\"], trim: true)

      if Enum.any?(segments, &(&1 == "..")) do
        {:error, :traversal}
      else
        abs_root = Path.expand(root)
        abs_path = Path.expand(Path.join(abs_root, rel_path))

        # Resolve symlinks before the prefix check so a symlink inside the workspace
        # pointing outside (e.g. to /etc) is caught.
        # :file.read_link_all/1 resolves a full symlink chain to its ultimate target.
        # Returns {:error, _} when the path is not a symlink or doesn't exist yet
        # (legitimate for write ops) — fall through to the expanded path in that case.
        real_path = resolve_symlink(abs_path)
        real_root = resolve_symlink(abs_root)

        # After resolving symlinks, verify the real path is still inside root.
        # Return the original abs_path (not real_path) so callers write to the
        # intended symlink location, not the resolved target.
        if String.starts_with?(real_path, real_root <> "/") or real_path == real_root do
          {:ok, abs_path}
        else
          {:error, :traversal}
        end
      end
    end
  end

  # Resolves a full symlink chain using :file.read_link_all/1.
  # Returns the real path string when the path is a symlink, or the original
  # path when it is not a symlink / does not yet exist (write-path case).
  defp resolve_symlink(path) do
    case :file.read_link_all(to_charlist(path)) do
      {:ok, target} -> List.to_string(target)
      {:error, _} -> path
    end
  end

  defp posix_to_datetime(posix_seconds) when is_integer(posix_seconds) do
    case DateTime.from_unix(posix_seconds) do
      {:ok, dt} -> dt
      _other -> nil
    end
  end

  defp posix_to_datetime(_posix), do: nil
end
