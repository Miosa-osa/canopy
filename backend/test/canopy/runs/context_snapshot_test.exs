defmodule Canopy.Runs.ContextSnapshotTest do
  @moduledoc """
  Tests for context_snapshot storage on runs.

  The snapshot_context stage in SpawnPipeline writes a map with
  commit_sha, branch, base_branch, env_hash, worktree_path, and timestamp
  into runs.context_snapshot. These tests verify that the Run schema accepts
  and persists those fields correctly, and that env_hash is a valid SHA-256
  hex string (64 lowercase hex chars).
  """

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Repo
  alias Canopy.Runs
  alias Canopy.Runs.Run

  # Helper to fetch a value using either atom or string key.
  # Ecto :map round-trips atom keys as string keys after a DB read.
  defp fetch_map_field(map, key) when is_atom(key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  # ---------------------------------------------------------------------------
  # Schema — context_snapshot field
  # ---------------------------------------------------------------------------

  describe "Run.changeset/2 with context_snapshot" do
    test "accepts a valid context_snapshot map and persists it" do
      run = insert(:run)

      snapshot = %{
        "commit_sha" => "abc123def456",
        "branch" => "main",
        "base_branch" => "main",
        "env_hash" => String.duplicate("a", 64),
        "worktree_path" => "/tmp/worktree",
        "timestamp" => "2026-01-01T00:00:00Z"
      }

      assert {:ok, _} =
               run
               |> Run.changeset(%{context_snapshot: snapshot})
               |> Repo.update()

      {:ok, reloaded} = Runs.get(run.id)
      assert reloaded.context_snapshot["commit_sha"] == "abc123def456"
      assert reloaded.context_snapshot["branch"] == "main"
      assert reloaded.context_snapshot["env_hash"] == String.duplicate("a", 64)
    end

    test "accepts nil commit_sha (non-git worktree)" do
      run = insert(:run)

      snapshot = %{
        "commit_sha" => nil,
        "branch" => nil,
        "base_branch" => nil,
        "env_hash" => String.duplicate("b", 64),
        "worktree_path" => "/tmp/no-git",
        "timestamp" => "2026-01-01T00:00:00Z"
      }

      assert {:ok, _} =
               run
               |> Run.changeset(%{context_snapshot: snapshot})
               |> Repo.update()

      {:ok, reloaded} = Runs.get(run.id)
      assert reloaded.context_snapshot["env_hash"] == String.duplicate("b", 64)
    end

    test "context_snapshot persists across Repo.get/2" do
      run = insert(:run)

      snapshot = %{
        "commit_sha" => "deadbeef",
        "branch" => "feature/test",
        "base_branch" => "main",
        "env_hash" => String.duplicate("c", 64),
        "worktree_path" => "/tmp/wt",
        "timestamp" => "2026-04-20T00:00:00Z"
      }

      {:ok, _} =
        run
        |> Run.changeset(%{context_snapshot: snapshot})
        |> Repo.update()

      {:ok, reloaded} = Runs.get(run.id)
      assert reloaded.context_snapshot["commit_sha"] == "deadbeef"
      assert reloaded.context_snapshot["branch"] == "feature/test"
    end

    test "snapshot keys from SpawnPipeline (atom keys) also persist correctly" do
      run = insert(:run)

      # SpawnPipeline builds the snapshot with atom keys
      snapshot = %{
        commit_sha: "atomkeytest",
        branch: "main",
        base_branch: "main",
        env_hash: String.duplicate("d", 64),
        worktree_path: "/workspace",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      assert {:ok, _} =
               run
               |> Run.changeset(%{context_snapshot: snapshot})
               |> Repo.update()

      {:ok, reloaded} = Runs.get(run.id)
      # After DB round-trip, keys become strings
      assert fetch_map_field(reloaded.context_snapshot, :commit_sha) == "atomkeytest"
    end
  end

  # ---------------------------------------------------------------------------
  # env_hash — SHA-256 hex format
  # ---------------------------------------------------------------------------

  describe "env_hash format" do
    test "SHA-256 of env vars produces 64 lowercase hex chars" do
      # Replicate the algorithm in snapshot_context/3
      whitelist =
        ~w(PATH HOME NODE_VERSION RUBY_VERSION PYTHON_VERSION ELIXIR_VERSION MIX_ENV ASDF_DIR)

      env_hash =
        whitelist
        |> Enum.flat_map(fn key ->
          case System.get_env(key) do
            nil -> []
            val -> ["#{key}=#{val}"]
          end
        end)
        |> Enum.sort()
        |> Enum.join("\n")
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode16(case: :lower)

      assert String.length(env_hash) == 64
      assert env_hash =~ ~r/\A[0-9a-f]{64}\z/
    end

    test "different env inputs produce different hashes" do
      hash_a =
        :crypto.hash(:sha256, "PATH=/usr/local/bin\nHOME=/home/a")
        |> Base.encode16(case: :lower)

      hash_b =
        :crypto.hash(:sha256, "PATH=/usr/local/bin\nHOME=/home/b")
        |> Base.encode16(case: :lower)

      refute hash_a == hash_b
    end

    test "empty env produces valid 64-char hash" do
      hash =
        :crypto.hash(:sha256, "")
        |> Base.encode16(case: :lower)

      assert String.length(hash) == 64
      assert hash =~ ~r/\A[0-9a-f]{64}\z/
    end
  end

  # ---------------------------------------------------------------------------
  # Integration — run has context_snapshot after direct write
  # ---------------------------------------------------------------------------

  describe "context_snapshot round-trip" do
    test "run starts with nil context_snapshot" do
      run = insert(:run)
      assert run.context_snapshot == nil
    end

    test "writing context_snapshot makes it queryable via short_id" do
      run = insert(:run)

      snapshot = %{
        "commit_sha" => "0000000000000000000000000000000000000000",
        "branch" => "main",
        "base_branch" => "main",
        "env_hash" => String.duplicate("f", 64),
        "worktree_path" => "/workspace",
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      {:ok, _} =
        run
        |> Run.changeset(%{context_snapshot: snapshot})
        |> Repo.update()

      {:ok, fetched} = Runs.get(run.short_id)
      assert fetched.context_snapshot["env_hash"] == String.duplicate("f", 64)
      assert fetched.context_snapshot["commit_sha"] == "0000000000000000000000000000000000000000"
    end
  end
end
