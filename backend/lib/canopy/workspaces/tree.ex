defmodule Canopy.Workspaces.Tree do
  @moduledoc """
  Builds a nested file-tree for a workspace.

  The tree is computed on demand (no caching layer — a full walk of a typical
  workspace takes well under 10ms on local disk). If future profiling shows a
  bottleneck, an ETS cache with a TTL can be added behind this module without
  changing the public API.

  The returned `%FileTree{}` struct is JSON-encodable via `Jason.Encoder`.
  """

  alias Canopy.Workspaces.Workspace

  @default_max_depth 10

  defmodule FileTree do
    @moduledoc "A node in the workspace file tree."

    @derive Jason.Encoder
    defstruct [:name, :path, :is_dir, :size, :modified, children: []]

    @type t :: %__MODULE__{
            name: String.t(),
            path: String.t(),
            is_dir: boolean(),
            size: non_neg_integer(),
            modified: DateTime.t() | nil,
            children: [t()]
          }
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Builds a nested `%FileTree{}` rooted at the workspace's `root_path`.

  `max_depth` limits recursion; directories at the depth limit are included as
  leaf nodes with an empty `children` list.

  Returns `{:ok, %FileTree{}}` or `{:error, :not_found}` if the root does not exist.
  """
  @spec build(Workspace.t(), non_neg_integer()) ::
          {:ok, FileTree.t()} | {:error, :not_found}
  def build(
        %Workspace{root_path: root_path, slug: slug} = _workspace,
        max_depth \\ @default_max_depth
      ) do
    abs_root = Path.expand(root_path)

    if File.dir?(abs_root) do
      node = build_node(abs_root, abs_root, slug, max_depth)
      {:ok, node}
    else
      {:error, :not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_node(abs_root, abs_path, rel_label, depth_remaining) do
    stat = File.stat!(abs_path, time: :posix)
    is_dir = stat.type == :directory

    children =
      if is_dir and depth_remaining > 0 do
        case File.ls(abs_path) do
          {:ok, names} ->
            names
            |> Enum.sort()
            |> Enum.map(fn name ->
              child_abs = Path.join(abs_path, name)
              child_rel = relative_path(abs_root, child_abs)
              build_node(abs_root, child_abs, child_rel, depth_remaining - 1)
            end)

          {:error, _reason} ->
            []
        end
      else
        []
      end

    %FileTree{
      name: Path.basename(abs_path),
      path: rel_label,
      is_dir: is_dir,
      size: stat.size,
      modified: posix_to_datetime(stat.mtime),
      children: children
    }
  end

  # Returns the path of `abs_path` relative to `abs_root`, or the basename if
  # they are the same (root node).
  defp relative_path(abs_root, abs_path) do
    case String.replace_prefix(abs_path, abs_root <> "/", "") do
      ^abs_path -> Path.basename(abs_path)
      rel -> rel
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
