defmodule Canopy.Sessions.WorktreeManagerTest do
  @moduledoc """
  Tests for WorktreeManager.

  Integration tests spin up a real git repo in a tmp directory so we exercise
  actual `git worktree` calls. Unit tests cover utility functions in isolation.
  """

  use ExUnit.Case, async: true

  alias Canopy.Sessions.WorktreeManager

  # ---------------------------------------------------------------------------
  # Setup helpers
  # ---------------------------------------------------------------------------

  # Creates an initialized bare git repo in a tmp dir and returns its path.
  defp init_git_repo do
    path = Path.join(System.tmp_dir!(), "canopy-test-repo-#{System.unique_integer([:positive])}")
    File.mkdir_p!(path)
    {_, 0} = System.cmd("git", ["init"], cd: path, stderr_to_stdout: true)
    {_, 0} = System.cmd("git", ["config", "user.email", "test@canopy.test"], cd: path)
    {_, 0} = System.cmd("git", ["config", "user.name", "Canopy Test"], cd: path)

    # Need at least one commit so worktree add has a HEAD to branch from
    File.write!(Path.join(path, "README.md"), "# test repo")
    {_, 0} = System.cmd("git", ["add", "."], cd: path)
    {_, 0} = System.cmd("git", ["commit", "-m", "init"], cd: path, stderr_to_stdout: true)

    path
  end

  # Cleans up a repo and any worktree paths created in the test.
  defp cleanup_paths(paths) do
    Enum.each(paths, fn p -> File.rm_rf(p) end)
  end

  # ---------------------------------------------------------------------------
  # is_git_repo?/1
  # ---------------------------------------------------------------------------

  describe "is_git_repo?/1" do
    test "returns true for an initialized git repo" do
      repo = init_git_repo()

      try do
        assert WorktreeManager.is_git_repo?(repo)
      after
        cleanup_paths([repo])
      end
    end

    test "returns false for a plain directory" do
      dir = Path.join(System.tmp_dir!(), "not-a-repo-#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)

      try do
        refute WorktreeManager.is_git_repo?(dir)
      after
        cleanup_paths([dir])
      end
    end

    test "returns false for a non-existent path" do
      refute WorktreeManager.is_git_repo?(
               "/tmp/definitely-does-not-exist-#{System.unique_integer()}"
             )
    end
  end

  # ---------------------------------------------------------------------------
  # detect_base_branch/1
  # ---------------------------------------------------------------------------

  describe "detect_base_branch/1" do
    test "returns a branch name string for a git repo" do
      repo = init_git_repo()

      try do
        result = WorktreeManager.detect_base_branch(repo)
        assert is_binary(result)
        assert String.length(result) > 0
      after
        cleanup_paths([repo])
      end
    end

    test "returns 'main' or 'master' as fallback when no remote" do
      repo = init_git_repo()

      try do
        result = WorktreeManager.detect_base_branch(repo)
        assert result in ["main", "master"]
      after
        cleanup_paths([repo])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # branch_name/1
  # ---------------------------------------------------------------------------

  describe "branch_name/1" do
    test "returns session/<first 8 chars> format" do
      id = "abcd1234-5678-90ef-ghij-klmnopqrstuv"
      assert WorktreeManager.branch_name(id) == "session/abcd1234"
    end

    test "handles short IDs gracefully" do
      id = "abc"
      assert WorktreeManager.branch_name(id) == "session/abc"
    end
  end

  # ---------------------------------------------------------------------------
  # worktree_path/1
  # ---------------------------------------------------------------------------

  describe "worktree_path/1" do
    test "returns a path ending in the session_id under the worktree base dir" do
      id = "test-session-id"
      path = WorktreeManager.worktree_path(id)
      # Path ends with the session_id regardless of where the base dir is configured
      assert Path.basename(path) == id
      assert String.contains?(path, "worktrees")
    end
  end

  # ---------------------------------------------------------------------------
  # create_worktree/3 + cleanup_worktree/1 (integration)
  # ---------------------------------------------------------------------------

  describe "create_worktree/3" do
    test "creates a worktree directory and branch" do
      repo = init_git_repo()
      session_id = "wt-test-#{System.unique_integer([:positive])}"
      branch = WorktreeManager.branch_name(session_id)
      worktree_path = WorktreeManager.worktree_path(session_id)

      try do
        {:ok, result} = WorktreeManager.create_worktree(session_id, repo, branch)

        assert result.path == worktree_path
        assert result.branch == branch
        assert is_binary(result.base_branch)
        assert File.dir?(worktree_path)
      after
        # Remove worktree before cleaning up repo
        WorktreeManager.cleanup_worktree(session_id)
        cleanup_paths([repo])
      end
    end

    test "returns error for non-git workspace" do
      dir = Path.join(System.tmp_dir!(), "plain-#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      session_id = "wt-nogit-#{System.unique_integer([:positive])}"
      branch = WorktreeManager.branch_name(session_id)

      try do
        assert {:error, _reason} = WorktreeManager.create_worktree(session_id, dir, branch)
      after
        cleanup_paths([dir])
      end
    end

    test "handles branch already exists by using -B flag on retry" do
      repo = init_git_repo()
      session_id = "wt-retry-#{System.unique_integer([:positive])}"
      branch = WorktreeManager.branch_name(session_id)
      worktree_path = WorktreeManager.worktree_path(session_id)

      try do
        # Create the branch manually so the first attempt with -b fails
        {_, 0} = System.cmd("git", ["branch", branch], cd: repo)

        {:ok, result} = WorktreeManager.create_worktree(session_id, repo, branch)
        assert result.path == worktree_path
        assert File.dir?(worktree_path)
      after
        WorktreeManager.cleanup_worktree(session_id)
        cleanup_paths([repo])
      end
    end
  end

  describe "cleanup_worktree/1" do
    test "removes the worktree directory" do
      repo = init_git_repo()
      session_id = "wt-cleanup-#{System.unique_integer([:positive])}"
      branch = WorktreeManager.branch_name(session_id)
      worktree_path = WorktreeManager.worktree_path(session_id)

      try do
        {:ok, _} = WorktreeManager.create_worktree(session_id, repo, branch)
        assert File.dir?(worktree_path)

        assert :ok = WorktreeManager.cleanup_worktree(session_id)
        refute File.dir?(worktree_path)
      after
        cleanup_paths([repo, worktree_path])
      end
    end

    test "returns :ok (idempotent) when worktree path does not exist" do
      session_id = "wt-missing-#{System.unique_integer([:positive])}"
      # cleanup/2 is idempotent — no worktree at path → :ok, nothing to remove
      assert :ok = WorktreeManager.cleanup_worktree(session_id)
    end
  end

  # ---------------------------------------------------------------------------
  # list_worktrees/1 (smoke test)
  # ---------------------------------------------------------------------------

  describe "list_worktrees/1" do
    test "returns list including main worktree" do
      repo = init_git_repo()

      try do
        {:ok, worktrees} = WorktreeManager.list_worktrees(repo)
        assert is_list(worktrees)
        assert length(worktrees) >= 1
        # Normalize both sides: macOS /tmp is a symlink to /private/tmp so
        # git reports the real path, while init_git_repo uses System.tmp_dir!().
        {real_repo, 0} = System.cmd("realpath", [repo])
        real_repo = String.trim(real_repo)
        assert Enum.any?(worktrees, &(&1.path == real_repo))
      after
        cleanup_paths([repo])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # ensure_for/1
  # ---------------------------------------------------------------------------

  describe "ensure_for/1" do
    test "returns {:ok, info} when worktree_path is already set on session" do
      result =
        WorktreeManager.ensure_for(%{
          id: "some-id",
          worktree_path: "/tmp/some/path",
          branch: "session/abcd1234",
          base_branch: "main"
        })

      assert {:ok, %{path: "/tmp/some/path", branch: "session/abcd1234", base_branch: "main"}} =
               result
    end

    test "returns {:skip, :not_git_repo} when root_path is not a git repo" do
      plain_dir =
        Path.join(System.tmp_dir!(), "plain-ensure-#{System.unique_integer([:positive])}")

      File.mkdir_p!(plain_dir)

      try do
        result =
          WorktreeManager.ensure_for(%{
            id: "session-#{System.unique_integer([:positive])}",
            worktree_path: nil,
            branch: nil,
            base_branch: nil,
            root_path: plain_dir
          })

        assert {:skip, :not_git_repo} = result
      after
        cleanup_paths([plain_dir])
      end
    end

    test "returns {:skip, :not_git_repo} when no root_path given" do
      result =
        WorktreeManager.ensure_for(%{
          id: "session-noop",
          worktree_path: nil,
          branch: nil,
          base_branch: nil
        })

      assert {:skip, :not_git_repo} = result
    end

    test "creates worktree when root_path is a git repo" do
      repo = init_git_repo()
      session_id = "ensure-#{System.unique_integer([:positive])}"
      worktree_path = WorktreeManager.worktree_path(session_id)

      try do
        result =
          WorktreeManager.ensure_for(%{
            id: session_id,
            worktree_path: nil,
            branch: nil,
            base_branch: nil,
            root_path: repo
          })

        assert {:ok, %{path: ^worktree_path, branch: branch}} = result
        assert String.starts_with?(branch, "session/")
        assert File.dir?(worktree_path)
      after
        WorktreeManager.cleanup(session_id)
        cleanup_paths([repo])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # status/2
  # ---------------------------------------------------------------------------

  describe "status/2" do
    test "returns exists: false and nil path when session has no worktree" do
      st =
        WorktreeManager.status("irrelevant-id", %{
          worktree_path: nil,
          branch: nil,
          base_branch: nil
        })

      assert st.exists == false
      assert is_nil(st.path)
      assert st.changes_count == 0
      assert st.ahead == 0
      assert st.behind == 0
    end

    test "returns exists: true and changes_count when worktree has changes" do
      repo = init_git_repo()
      session_id = "status-#{System.unique_integer([:positive])}"
      branch = WorktreeManager.branch_name(session_id)
      worktree_path = WorktreeManager.worktree_path(session_id)

      try do
        {:ok, %{path: path, base_branch: base}} =
          WorktreeManager.create_worktree(session_id, repo, branch)

        # Modify a tracked file to produce a change visible to git status
        File.write!(Path.join(path, "README.md"), "# modified")

        session = %{worktree_path: path, branch: branch, base_branch: base}
        st = WorktreeManager.status(session_id, session)

        assert st.exists == true
        assert st.has_changes == true
        assert st.changes_count >= 1
        assert st.path == path
      after
        WorktreeManager.cleanup(session_id)
        cleanup_paths([repo, worktree_path])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # diff/2
  # ---------------------------------------------------------------------------

  describe "diff/2" do
    test "returns {:ok, binary} for an existing worktree with staged changes" do
      repo = init_git_repo()
      session_id = "diff-#{System.unique_integer([:positive])}"
      branch = WorktreeManager.branch_name(session_id)
      worktree_path = WorktreeManager.worktree_path(session_id)

      try do
        {:ok, %{path: path}} = WorktreeManager.create_worktree(session_id, repo, branch)
        # Modify the existing tracked README.md file so git diff HEAD shows it
        File.write!(Path.join(path, "README.md"), "# modified by agent")

        assert {:ok, diff} = WorktreeManager.diff(session_id)
        assert is_binary(diff)
        # When file is modified but not staged, diff HEAD vs working tree shows changes
        assert String.contains?(diff, "README")
      after
        WorktreeManager.cleanup(session_id)
        cleanup_paths([repo, worktree_path])
      end
    end

    test "returns {:error, :no_worktree} when path does not exist" do
      assert {:error, :no_worktree} =
               WorktreeManager.diff("no-such-session-#{System.unique_integer()}")
    end

    test "caps output at max_bytes" do
      repo = init_git_repo()
      session_id = "diff-cap-#{System.unique_integer([:positive])}"
      branch = WorktreeManager.branch_name(session_id)
      worktree_path = WorktreeManager.worktree_path(session_id)

      try do
        {:ok, %{path: path}} = WorktreeManager.create_worktree(session_id, repo, branch)
        # Modify a tracked file with enough content to generate a sizeable diff
        File.write!(Path.join(path, "README.md"), String.duplicate("changed line\n", 100))

        assert {:ok, diff} = WorktreeManager.diff(session_id, max_bytes: 10)
        assert byte_size(diff) <= 10
      after
        WorktreeManager.cleanup(session_id)
        cleanup_paths([repo, worktree_path])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # commit/3
  # ---------------------------------------------------------------------------

  describe "commit/3" do
    test "commits staged changes and returns {:ok, sha}" do
      repo = init_git_repo()
      session_id = "commit-#{System.unique_integer([:positive])}"
      branch = WorktreeManager.branch_name(session_id)
      worktree_path = WorktreeManager.worktree_path(session_id)

      try do
        {:ok, %{path: path}} = WorktreeManager.create_worktree(session_id, repo, branch)
        File.write!(Path.join(path, "work.txt"), "agent output")

        assert {:ok, sha} = WorktreeManager.commit(session_id, "feat: agent work")
        assert is_binary(sha)
        assert String.length(sha) == 40
      after
        WorktreeManager.cleanup(session_id)
        cleanup_paths([repo, worktree_path])
      end
    end

    test "returns {:error, _} when no staged changes" do
      repo = init_git_repo()
      session_id = "commit-empty-#{System.unique_integer([:positive])}"
      branch = WorktreeManager.branch_name(session_id)
      worktree_path = WorktreeManager.worktree_path(session_id)

      try do
        {:ok, _} = WorktreeManager.create_worktree(session_id, repo, branch)
        # Nothing changed — commit should fail
        assert {:error, _} = WorktreeManager.commit(session_id, "empty commit")
      after
        WorktreeManager.cleanup(session_id)
        cleanup_paths([repo, worktree_path])
      end
    end

    test "returns {:error, :no_worktree} when worktree path missing" do
      assert {:error, :no_worktree} =
               WorktreeManager.commit("ghost-#{System.unique_integer()}", "msg")
    end
  end

  # ---------------------------------------------------------------------------
  # merge_to_base/2 — conflict path
  # ---------------------------------------------------------------------------

  describe "merge_to_base/2" do
    test "returns {:error, {:conflict, files}} on merge conflict" do
      repo = init_git_repo()
      session_id = "merge-conflict-#{System.unique_integer([:positive])}"
      branch = WorktreeManager.branch_name(session_id)
      worktree_path = WorktreeManager.worktree_path(session_id)

      try do
        # Create worktree on a new branch
        {:ok, %{path: path, base_branch: base}} =
          WorktreeManager.create_worktree(session_id, repo, branch)

        # Write conflicting change in the worktree branch
        File.write!(Path.join(path, "conflict.txt"), "session version\n")
        {_, 0} = System.cmd("git", ["add", "conflict.txt"], cd: path)

        {_, 0} =
          System.cmd("git", ["commit", "-m", "session change"], cd: path, stderr_to_stdout: true)

        # Write conflicting change in the base branch
        File.write!(Path.join(repo, "conflict.txt"), "base version\n")
        {_, 0} = System.cmd("git", ["add", "conflict.txt"], cd: repo)

        {_, 0} =
          System.cmd("git", ["commit", "-m", "base change"], cd: repo, stderr_to_stdout: true)

        # Now merge — should conflict
        result = WorktreeManager.merge_to_base(session_id)
        assert {:error, {:conflict, files}} = result
        assert is_list(files)
        assert length(files) > 0
      after
        WorktreeManager.cleanup(session_id)
        cleanup_paths([repo, worktree_path])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # list_all/0
  # ---------------------------------------------------------------------------

  describe "list_all/0" do
    test "returns a list (may be empty when no worktrees present)" do
      result = WorktreeManager.list_all()
      assert is_list(result)
    end
  end

  # ---------------------------------------------------------------------------
  # stage/2
  # ---------------------------------------------------------------------------

  describe "stage/2" do
    test "stages files via git add --" do
      repo = init_git_repo()
      session_id = "wt-stage-#{System.unique_integer([:positive])}"
      branch = WorktreeManager.branch_name(session_id)
      worktree_path = WorktreeManager.worktree_path(session_id)

      try do
        {:ok, _} = WorktreeManager.create_worktree(session_id, repo, branch)
        File.write!(Path.join(worktree_path, "new.txt"), "hi\n")

        assert {:ok, ["new.txt"]} = WorktreeManager.stage(session_id, ["new.txt"])

        # Verify it landed in the index
        {output, 0} =
          System.cmd("git", ["diff", "--cached", "--name-only"],
            cd: worktree_path,
            stderr_to_stdout: true
          )

        assert String.contains?(output, "new.txt")
      after
        WorktreeManager.cleanup(session_id)
        cleanup_paths([repo])
      end
    end

    test "rejects path traversal" do
      repo = init_git_repo()
      session_id = "wt-stage-bad-#{System.unique_integer([:positive])}"
      branch = WorktreeManager.branch_name(session_id)

      try do
        {:ok, _} = WorktreeManager.create_worktree(session_id, repo, branch)
        assert {:error, :invalid_path} = WorktreeManager.stage(session_id, ["../etc/passwd"])
        assert {:error, :invalid_path} = WorktreeManager.stage(session_id, ["/etc/passwd"])
      after
        WorktreeManager.cleanup(session_id)
        cleanup_paths([repo])
      end
    end

    test "returns ok with empty list when no files passed" do
      assert {:ok, []} = WorktreeManager.stage("any-session", [])
    end

    test "returns no_worktree when worktree missing" do
      assert {:error, :no_worktree} =
               WorktreeManager.stage("nonexistent-#{System.unique_integer([:positive])}", [
                 "a.txt"
               ])
    end
  end

  # ---------------------------------------------------------------------------
  # discard_hunk/4
  # ---------------------------------------------------------------------------

  describe "discard_hunk/4" do
    test "reverts a single hunk in the worktree" do
      repo = init_git_repo()
      session_id = "wt-discard-#{System.unique_integer([:positive])}"
      branch = WorktreeManager.branch_name(session_id)
      worktree_path = WorktreeManager.worktree_path(session_id)

      try do
        {:ok, _} = WorktreeManager.create_worktree(session_id, repo, branch)

        # Seed file with two lines, commit
        target = Path.join(worktree_path, "data.txt")
        File.write!(target, "line1\nline2\n")
        {_, 0} = System.cmd("git", ["add", "data.txt"], cd: worktree_path)

        {_, 0} =
          System.cmd("git", ["commit", "-m", "seed"], cd: worktree_path, stderr_to_stdout: true)

        # Modify: append "line3"
        File.write!(target, "line1\nline2\nline3\n")

        # Build the hunk that represents the change
        header = "@@ -1,2 +1,3 @@"
        content = " line1\n line2\n+line3\n"

        assert :ok = WorktreeManager.discard_hunk(session_id, "data.txt", header, content)

        # File should be back to two lines
        assert File.read!(target) == "line1\nline2\n"
      after
        WorktreeManager.cleanup(session_id)
        cleanup_paths([repo])
      end
    end

    test "rejects path traversal" do
      repo = init_git_repo()
      session_id = "wt-discard-bad-#{System.unique_integer([:positive])}"
      branch = WorktreeManager.branch_name(session_id)

      try do
        {:ok, _} = WorktreeManager.create_worktree(session_id, repo, branch)

        assert {:error, :invalid_path} =
                 WorktreeManager.discard_hunk(
                   session_id,
                   "../escape.txt",
                   "@@ -1,1 +1,1 @@",
                   "-x\n+y\n"
                 )
      after
        WorktreeManager.cleanup(session_id)
        cleanup_paths([repo])
      end
    end

    test "rejects malformed hunk header" do
      repo = init_git_repo()
      session_id = "wt-discard-hh-#{System.unique_integer([:positive])}"
      branch = WorktreeManager.branch_name(session_id)

      try do
        {:ok, _} = WorktreeManager.create_worktree(session_id, repo, branch)

        assert {:error, :invalid_hunk_header} =
                 WorktreeManager.discard_hunk(session_id, "x.txt", "not a hunk header", "+y\n")
      after
        WorktreeManager.cleanup(session_id)
        cleanup_paths([repo])
      end
    end

    test "returns no_worktree when worktree missing" do
      assert {:error, :no_worktree} =
               WorktreeManager.discard_hunk(
                 "ghost-#{System.unique_integer([:positive])}",
                 "x.txt",
                 "@@ -1,1 +1,1 @@",
                 "-a\n+b\n"
               )
    end
  end
end
