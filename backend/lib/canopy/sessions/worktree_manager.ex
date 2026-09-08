defmodule Canopy.Sessions.WorktreeManager do
  @moduledoc """
  Pure functions for managing git worktrees scoped to a session.

  Each session gets its own worktree at `~/.canopy/worktrees/<session_id>`
  on a branch named `session/<short_id>`. This isolates parallel agent executions
  so they cannot step on each other's working tree state.

  All functions delegate to `System.cmd("git", ...)` — no GenServer needed
  because git worktree operations are safe to run concurrently per session.

  If the workspace is not a git repo, `ensure_for/1` returns `{:skip, :not_git_repo}`
  and callers must fall back to the plain `root_path` as the pty cwd.
  """

  require Logger

  @worktree_base_dir Path.join([System.user_home!(), ".canopy", "worktrees"])

  # ---------------------------------------------------------------------------
  # Public API — Session-level
  # ---------------------------------------------------------------------------

  @doc """
  Ensures a worktree exists for the given session.

  - If the session's workspace is not a git repo → `{:skip, :not_git_repo}`
  - If a worktree is already registered (session.worktree_path set) → `{:ok, info}`
  - Otherwise creates one → `{:ok, info}` or `{:error, reason}`

  Called by SpawnPipeline (#174). Signature is stable.
  """
  @spec ensure_for(map()) ::
          {:ok, %{path: String.t(), branch: String.t(), base_branch: String.t()}}
          | {:skip, :not_git_repo}
          | {:error, term()}
  def ensure_for(%{id: _session_id, worktree_path: path, branch: branch, base_branch: base})
      when is_binary(path) and is_binary(branch) and is_binary(base) do
    {:ok, %{path: path, branch: branch, base_branch: base}}
  end

  def ensure_for(%{id: session_id} = session) do
    root_path = Map.get(session, :root_path) || Map.get(session, :cwd)

    cond do
      is_nil(root_path) ->
        {:skip, :not_git_repo}

      not is_git_repo?(root_path) ->
        {:skip, :not_git_repo}

      true ->
        branch = branch_name(session_id)
        create_worktree(session_id, root_path, branch)
    end
  end

  @doc """
  Returns live status for the worktree associated with `session_id`.

  Queries git for changed file count, commits ahead/behind base branch.
  """
  @spec status(String.t(), map() | nil) :: map()
  def status(_session_id, session \\ nil) do
    db_path = session && Map.get(session, :worktree_path)
    branch = session && Map.get(session, :branch)
    base_branch = session && Map.get(session, :base_branch)

    # Prefer path from DB; compute from session_id only if DB says worktree exists
    path =
      if is_binary(db_path) and db_path != "" do
        db_path
      else
        nil
      end

    exists = is_binary(path) and File.dir?(path)

    base = %{
      path: path,
      branch: branch,
      base_branch: base_branch,
      exists: exists,
      has_changes: false,
      changes_count: 0,
      ahead: 0,
      behind: 0
    }

    if exists do
      changes_count = count_changes(path)

      {ahead, behind} =
        if is_binary(base_branch) do
          ahead_behind(path, base_branch)
        else
          {0, 0}
        end

      %{
        base
        | has_changes: changes_count > 0,
          changes_count: changes_count,
          ahead: ahead,
          behind: behind
      }
    else
      base
    end
  end

  @doc """
  Returns the unified git diff for the session worktree.

  Options:
  - `:file` — path relative to worktree root (diff only that file)
  - `:max_bytes` — cap response size, default 512 KB
  """
  @spec diff(String.t(), keyword()) :: {:ok, binary()} | {:error, term()}
  def diff(session_id, opts \\ []) do
    path = worktree_path(session_id)
    max_bytes = Keyword.get(opts, :max_bytes, 512_000)

    unless File.dir?(path) do
      {:error, :no_worktree}
    else
      args =
        case Keyword.get(opts, :file) do
          nil -> ["diff", "HEAD"]
          file -> ["diff", "HEAD", "--", file]
        end

      case System.cmd("git", args, cd: path, stderr_to_stdout: true) do
        {output, 0} ->
          capped =
            if byte_size(output) > max_bytes do
              binary_part(output, 0, max_bytes)
            else
              output
            end

          {:ok, capped}

        {output, code} ->
          {:error, {:git_error, code, String.trim(output)}}
      end
    end
  end

  @doc """
  Commits changes in the session worktree.

  Runs `git add -A && git commit -m message` by default.
  With `opts[:files]` list, stages only those paths instead.
  Returns `{:ok, sha}` or `{:error, reason}`.
  """
  @spec commit(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def commit(session_id, message, opts \\ []) do
    path = worktree_path(session_id)

    unless File.dir?(path) do
      {:error, :no_worktree}
    else
      add_args =
        case Keyword.get(opts, :files) do
          nil -> ["add", "-A"]
          files when is_list(files) -> ["add", "--"] ++ files
        end

      with {_, 0} <- System.cmd("git", add_args, cd: path, stderr_to_stdout: true),
           {_, 0} <-
             System.cmd("git", ["commit", "-m", message], cd: path, stderr_to_stdout: true),
           {sha, 0} <-
             System.cmd("git", ["rev-parse", "HEAD"], cd: path, stderr_to_stdout: true) do
        {:ok, String.trim(sha)}
      else
        {output, code} -> {:error, {:git_error, code, String.trim(output)}}
      end
    end
  end

  @doc """
  Stages the given file paths via `git add --` in the session worktree.

  Validates that every path is inside the worktree (no traversal). Returns
  `{:ok, [file_path...]}` for the staged set or `{:error, reason}`.
  """
  @spec stage(String.t(), [String.t()]) :: {:ok, [String.t()]} | {:error, term()}
  def stage(_session_id, []), do: {:ok, []}

  def stage(session_id, files) when is_list(files) do
    path = worktree_path(session_id)

    cond do
      not File.dir?(path) ->
        {:error, :no_worktree}

      Enum.any?(files, &(not safe_relative_path?(&1))) ->
        {:error, :invalid_path}

      true ->
        case System.cmd("git", ["add", "--"] ++ files, cd: path, stderr_to_stdout: true) do
          {_, 0} -> {:ok, files}
          {output, code} -> {:error, {:git_error, code, String.trim(output)}}
        end
    end
  end

  @doc """
  Reverts a single hunk in the worktree by applying its diff in reverse.

  Builds a minimal unified-diff patch from the hunk_header (e.g. `@@ -10,5 +10,7 @@`)
  and hunk_content (the body lines including +/-/space prefixes), then runs
  `git apply --reverse --unidiff-zero` against the working tree. The file_path
  must be inside the worktree (no traversal). Returns `:ok` or `{:error, reason}`.
  """
  @spec discard_hunk(String.t(), String.t(), String.t(), String.t()) ::
          :ok | {:error, term()}
  def discard_hunk(session_id, file_path, hunk_header, hunk_content)
      when is_binary(file_path) and is_binary(hunk_header) and is_binary(hunk_content) do
    path = worktree_path(session_id)

    cond do
      not File.dir?(path) ->
        {:error, :no_worktree}

      not safe_relative_path?(file_path) ->
        {:error, :invalid_path}

      not String.starts_with?(hunk_header, "@@ ") ->
        {:error, :invalid_hunk_header}

      true ->
        patch = build_minimal_patch(file_path, hunk_header, hunk_content)
        apply_patch_reverse(path, patch)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers — discard / stage support
  # ---------------------------------------------------------------------------

  @spec safe_relative_path?(String.t()) :: boolean()
  defp safe_relative_path?(p) when is_binary(p) do
    p != "" and
      not String.starts_with?(p, "/") and
      not String.contains?(p, "..") and
      not String.contains?(p, "\0")
  end

  defp safe_relative_path?(_), do: false

  @spec build_minimal_patch(String.t(), String.t(), String.t()) :: String.t()
  defp build_minimal_patch(file_path, hunk_header, hunk_content) do
    body = if String.ends_with?(hunk_content, "\n"), do: hunk_content, else: hunk_content <> "\n"

    [
      "diff --git a/#{file_path} b/#{file_path}\n",
      "--- a/#{file_path}\n",
      "+++ b/#{file_path}\n",
      String.trim_trailing(hunk_header) <> "\n",
      body
    ]
    |> IO.iodata_to_binary()
  end

  @spec apply_patch_reverse(String.t(), String.t()) :: :ok | {:error, term()}
  defp apply_patch_reverse(worktree_dir, patch) do
    tmp =
      Path.join(System.tmp_dir!(), "canopy-discard-#{System.unique_integer([:positive])}.patch")

    File.write!(tmp, patch)

    try do
      case System.cmd(
             "git",
             ["apply", "--reverse", "--unidiff-zero", "--whitespace=nowarn", tmp],
             cd: worktree_dir,
             stderr_to_stdout: true
           ) do
        {_, 0} ->
          :ok

        {output, code} ->
          Logger.warning(
            "[WorktreeManager] discard_hunk failed code=#{code}: #{String.trim(output)}"
          )

          {:error, {:git_error, code, String.trim(output)}}
      end
    after
      File.rm(tmp)
    end
  end

  @doc """
  Pushes the session branch to the given remote (default: "origin").
  Never uses --force. Returns `{:ok, ref}` or `{:error, reason}`.
  """
  @spec push(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def push(session_id, remote \\ "origin") do
    path = worktree_path(session_id)

    unless File.dir?(path) do
      {:error, :no_worktree}
    else
      branch = branch_name(session_id)

      case System.cmd("git", ["push", remote, branch], cd: path, stderr_to_stdout: true) do
        {_, 0} ->
          {:ok, "#{remote}/#{branch}"}

        {output, code} ->
          {:error, {:git_error, code, String.trim(output)}}
      end
    end
  end

  @doc """
  Merges the session branch back into its base branch.

  Checks out base branch in the main worktree (workspace root), merges the
  session branch, then checks back out. Returns `{:ok, base_branch}` on success,
  `{:error, {:conflict, files}}` on merge conflicts, or `{:error, reason}`.

  The workspace root is resolved from the git worktree metadata so no extra
  argument is required.
  """
  @spec merge_to_base(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, {:conflict, [String.t()]}} | {:error, term()}
  def merge_to_base(session_id, _opts \\ []) do
    path = worktree_path(session_id)

    unless File.dir?(path) do
      {:error, :no_worktree}
    else
      branch = branch_name(session_id)

      # Resolve the main worktree (where base branch lives)
      case resolve_main_worktree(path) do
        {:error, _} = err ->
          err

        {:ok, main_root} ->
          base = detect_base_branch(main_root)

          with {_, 0} <-
                 System.cmd("git", ["checkout", base], cd: main_root, stderr_to_stdout: true),
               {merge_out, merge_code} <-
                 System.cmd("git", ["merge", "--no-ff", branch],
                   cd: main_root,
                   stderr_to_stdout: true
                 ) do
            if merge_code == 0 do
              {:ok, base}
            else
              conflicts = parse_conflict_files(main_root)

              System.cmd("git", ["merge", "--abort"],
                cd: main_root,
                stderr_to_stdout: true
              )

              Logger.warning(
                "[WorktreeManager] merge conflict session=#{session_id} conflicts=#{inspect(conflicts)}: #{String.trim(merge_out)}"
              )

              {:error, {:conflict, conflicts}}
            end
          else
            {output, code} -> {:error, {:git_error, code, String.trim(output)}}
          end
      end
    end
  end

  @doc """
  Removes the worktree for `session_id` from disk.

  Options:
  - `:keep_branch` — when true, keeps the git branch after removing the worktree dir (default false)

  Returns `:ok` or `{:error, reason}`.
  """
  @spec cleanup(String.t(), keyword()) :: :ok | {:error, term()}
  def cleanup(session_id, opts \\ []) do
    path = worktree_path(session_id)
    keep_branch = Keyword.get(opts, :keep_branch, false)

    unless File.dir?(path) do
      Logger.debug("[WorktreeManager] worktree already absent session_id=#{session_id}")
      :ok
    else
      result =
        System.cmd("git", ["worktree", "remove", "--force", path],
          cd: path,
          stderr_to_stdout: true
        )

      case result do
        {_, 0} ->
          Logger.info("[WorktreeManager] removed worktree session_id=#{session_id} path=#{path}")

          unless keep_branch do
            # Branch deletion requires the main worktree path, which we don't have here.
            # cleanup/2 removes the worktree dir; branch remains until merge or manual deletion.
            :ok
          end

          :ok

        {output, code} ->
          Logger.warning(
            "[WorktreeManager] worktree remove failed session_id=#{session_id} code=#{code}: #{output}"
          )

          {:error, {:git_error, code, String.trim(output)}}
      end
    end
  end

  @doc """
  Lists all registered Canopy worktrees (admin/debug).
  Scans the worktree base dir and reports existence + branch per session_id dir.
  """
  @spec list_all() :: [
          %{session_id: String.t(), path: String.t(), branch: String.t() | nil, exists: boolean()}
        ]
  def list_all do
    base = worktree_base()

    case File.ls(base) do
      {:ok, entries} ->
        Enum.map(entries, fn session_id ->
          path = Path.join(base, session_id)
          exists = File.dir?(path)
          branch = if exists, do: current_branch(path), else: nil
          %{session_id: session_id, path: path, branch: branch, exists: exists}
        end)

      {:error, _} ->
        []
    end
  end

  # ---------------------------------------------------------------------------
  # Legacy API (used by Sessions context + SpawnPipeline)
  # ---------------------------------------------------------------------------

  @doc """
  Returns true if `path` is inside a git repository.

  Checks for a `.git` entry first (fast), then falls back to `git rev-parse`.
  """
  @spec is_git_repo?(String.t()) :: boolean()
  def is_git_repo?(path) do
    File.exists?(Path.join(path, ".git")) or git_rev_parse_check(path)
  end

  @doc """
  Detects the default base branch for `workspace_root`.

  Tries `git symbolic-ref refs/remotes/origin/HEAD`, then falls back to
  checking for a `main` branch, then `master`.
  """
  @spec detect_base_branch(String.t()) :: String.t()
  def detect_base_branch(workspace_root) do
    case System.cmd("git", ["symbolic-ref", "refs/remotes/origin/HEAD", "--short"],
           cd: workspace_root,
           stderr_to_stdout: false
         ) do
      {output, 0} ->
        output
        |> String.trim()
        |> String.replace_prefix("origin/", "")

      _ ->
        case System.cmd("git", ["branch", "--list", "main"], cd: workspace_root) do
          {out, 0} when out != "" -> "main"
          _ -> "master"
        end
    end
  end

  @doc """
  Creates a git worktree for `session_id` at `~/.canopy/worktrees/<session_id>`.

  Branch name: `session/<short_id>` where `short_id` is the first 8 chars of `session_id`.
  Returns `{:ok, %{path, branch, base_branch}}` or `{:error, reason}`.
  """
  @spec create_worktree(String.t(), String.t(), String.t()) ::
          {:ok, %{path: String.t(), branch: String.t(), base_branch: String.t()}}
          | {:error, term()}
  def create_worktree(session_id, workspace_root, branch_name) do
    path = worktree_path(session_id)
    base_branch = detect_base_branch(workspace_root)

    File.mkdir_p!(worktree_base())

    result = try_create_worktree(workspace_root, path, branch_name)

    case result do
      {:ok, _} ->
        Logger.info(
          "[WorktreeManager] created worktree session_id=#{session_id} path=#{path} branch=#{branch_name}"
        )

        {:ok, %{path: path, branch: branch_name, base_branch: base_branch}}

      {:error, _reason} ->
        retry_result = try_create_worktree_force(workspace_root, path, branch_name)

        case retry_result do
          {:ok, _} ->
            Logger.info(
              "[WorktreeManager] created worktree (retry) session_id=#{session_id} path=#{path} branch=#{branch_name}"
            )

            {:ok, %{path: path, branch: branch_name, base_branch: base_branch}}

          {:error, reason} ->
            Logger.warning(
              "[WorktreeManager] failed to create worktree session_id=#{session_id}: #{inspect(reason)}"
            )

            {:error, reason}
        end
    end
  end

  @doc """
  Removes the worktree for `session_id` using `git worktree remove --force`.

  Returns `:ok` or `{:error, reason}`.
  """
  @spec cleanup_worktree(String.t()) :: :ok | {:error, term()}
  def cleanup_worktree(session_id), do: cleanup(session_id)

  @doc """
  Lists all registered worktrees for `workspace_root`. For debugging.
  """
  @spec list_worktrees(String.t()) :: {:ok, [map()]} | {:error, term()}
  def list_worktrees(workspace_root) do
    case System.cmd("git", ["worktree", "list", "--porcelain"],
           cd: workspace_root,
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        {:ok, parse_worktree_list(output)}

      {output, code} ->
        {:error, {:git_error, code, String.trim(output)}}
    end
  end

  @doc """
  Returns the canonical worktree path for a session_id.

  Ensures the base directory exists and resolves symlinks so that the path
  matches what `git worktree list` reports (important on macOS where /tmp is a
  symlink to /private/tmp).
  """
  @spec worktree_path(String.t()) :: String.t()
  def worktree_path(session_id) do
    File.mkdir_p!(worktree_base())
    base = worktree_base() |> Path.expand() |> real_path()
    Path.join(base, session_id)
  end

  @doc "Returns the branch name for a session_id."
  @spec branch_name(String.t()) :: String.t()
  def branch_name(session_id) do
    short_id = String.slice(session_id, 0, 8)
    "session/#{short_id}"
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec worktree_base() :: String.t()
  defp worktree_base do
    path = Application.get_env(:canopy, :worktree_base_dir, @worktree_base_dir)
    File.mkdir_p!(path)
    path
  end

  @spec count_changes(String.t()) :: non_neg_integer()
  defp count_changes(path) do
    case System.cmd("git", ["status", "--porcelain"], cd: path, stderr_to_stdout: true) do
      {output, 0} -> output |> String.split("\n", trim: true) |> length()
      _ -> 0
    end
  end

  @spec ahead_behind(String.t(), String.t()) :: {non_neg_integer(), non_neg_integer()}
  defp ahead_behind(path, base_branch) do
    case System.cmd(
           "git",
           ["rev-list", "--left-right", "--count", "HEAD...#{base_branch}"],
           cd: path,
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        case String.split(String.trim(output)) do
          [ahead_str, behind_str] ->
            {String.to_integer(ahead_str), String.to_integer(behind_str)}

          _ ->
            {0, 0}
        end

      _ ->
        {0, 0}
    end
  end

  @spec current_branch(String.t()) :: String.t() | nil
  defp current_branch(path) do
    case System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"],
           cd: path,
           stderr_to_stdout: true
         ) do
      {output, 0} -> String.trim(output)
      _ -> nil
    end
  end

  @spec resolve_main_worktree(String.t()) :: {:ok, String.t()} | {:error, term()}
  defp resolve_main_worktree(worktree_path) do
    case System.cmd("git", ["worktree", "list", "--porcelain"],
           cd: worktree_path,
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        worktrees = parse_worktree_list(output)

        case Enum.find(worktrees, &(not Map.has_key?(&1, :bare) and &1.path != worktree_path)) do
          nil ->
            # First worktree is always the main one
            case worktrees do
              [main | _] -> {:ok, main.path}
              _ -> {:error, :no_main_worktree}
            end

          main ->
            {:ok, main.path}
        end

      {output, code} ->
        {:error, {:git_error, code, String.trim(output)}}
    end
  end

  @spec parse_conflict_files(String.t()) :: [String.t()]
  defp parse_conflict_files(path) do
    case System.cmd("git", ["diff", "--name-only", "--diff-filter=U"],
           cd: path,
           stderr_to_stdout: true
         ) do
      {output, 0} -> String.split(String.trim(output), "\n", trim: true)
      _ -> []
    end
  end

  @spec real_path(String.t()) :: String.t()
  defp real_path(path) do
    case System.cmd("realpath", [path], stderr_to_stdout: true) do
      {output, 0} -> String.trim(output)
      _ -> path
    end
  end

  @spec git_rev_parse_check(String.t()) :: boolean()
  defp git_rev_parse_check(path) do
    case System.cmd("git", ["-C", path, "rev-parse", "--is-inside-work-tree"],
           stderr_to_stdout: true
         ) do
      {"true\n", 0} -> true
      _ -> false
    end
  end

  @spec try_create_worktree(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  defp try_create_worktree(workspace_root, path, branch_name) do
    case System.cmd("git", ["worktree", "add", path, "-b", branch_name],
           cd: workspace_root,
           stderr_to_stdout: true
         ) do
      {output, 0} -> {:ok, output}
      {output, code} -> {:error, {:git_error, code, String.trim(output)}}
    end
  end

  @spec try_create_worktree_force(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  defp try_create_worktree_force(workspace_root, path, branch_name) do
    case System.cmd("git", ["worktree", "add", path, "-B", branch_name],
           cd: workspace_root,
           stderr_to_stdout: true
         ) do
      {output, 0} -> {:ok, output}
      {output, code} -> {:error, {:git_error, code, String.trim(output)}}
    end
  end

  @spec parse_worktree_list(String.t()) :: [map()]
  defp parse_worktree_list(output) do
    output
    |> String.split("\n\n", trim: true)
    |> Enum.map(fn block ->
      block
      |> String.split("\n", trim: true)
      |> Enum.reduce(%{}, fn line, acc ->
        case String.split(line, " ", parts: 2) do
          ["worktree", path] -> Map.put(acc, :path, path)
          ["HEAD", sha] -> Map.put(acc, :head, sha)
          ["branch", ref] -> Map.put(acc, :branch, ref)
          ["bare"] -> Map.put(acc, :bare, true)
          _ -> acc
        end
      end)
    end)
  end
end
