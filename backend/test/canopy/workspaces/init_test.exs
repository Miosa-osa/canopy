defmodule Canopy.Workspaces.InitTest do
  @moduledoc """
  Unit + integration tests for Canopy.Workspaces.Init context.
  """

  use Canopy.DataCase, async: false

  alias Canopy.Repo
  alias Canopy.Workspaces.Init
  alias Canopy.Workspaces.Workspace

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp tmp_dir do
    dir =
      System.tmp_dir!()
      |> Path.join("canopy-init-test-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    dir
  end

  defp insert_workspace(overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          slug: "ws-init-#{System.unique_integer([:positive])}",
          name: "Init Test Workspace",
          root_path: tmp_dir()
        },
        overrides
      )

    {:ok, ws} = Repo.insert(Workspace.changeset(%Workspace{}, attrs))
    ws
  end

  defp wait_for_terminal(job_id, timeout_ms \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    Stream.repeatedly(fn ->
      Process.sleep(50)

      case Init.get(job_id) do
        {:ok, %{status: s} = job} when s in ["succeeded", "failed", "cancelled"] -> {:done, job}
        {:ok, _job} -> :waiting
        {:error, _} -> :waiting
      end
    end)
    |> Enum.find_value(fn
      {:done, job} ->
        job

      :waiting ->
        if System.monotonic_time(:millisecond) > deadline do
          raise "Timeout waiting for job #{job_id} to reach terminal state"
        end

        nil
    end)
  end

  # ---------------------------------------------------------------------------
  # Unit: start/2 inserts job and returns it
  # ---------------------------------------------------------------------------

  describe "start/2" do
    test "creates a job in :running status for a valid workspace" do
      ws = insert_workspace()
      assert {:ok, job} = Init.start(ws.slug)
      assert job.workspace_slug == ws.slug
      assert job.status == "running"
      assert job.progress_pct == 0
      refute is_nil(job.started_at)
    end

    test "returns {:error, :not_found} for a nonexistent workspace" do
      assert {:error, :not_found} = Init.start("does-not-exist-xyzzy")
    end
  end

  # ---------------------------------------------------------------------------
  # Unit: get/1 and list_for_workspace/1
  # ---------------------------------------------------------------------------

  describe "get/1" do
    test "returns the job by id" do
      ws = insert_workspace()
      {:ok, job} = Init.start(ws.slug)
      assert {:ok, fetched} = Init.get(job.id)
      assert fetched.id == job.id
    end

    test "returns {:error, :not_found} for unknown id" do
      assert {:error, :not_found} = Init.get(Ecto.UUID.generate())
    end
  end

  describe "list_for_workspace/1" do
    test "returns jobs newest first" do
      ws = insert_workspace()
      {:ok, j1} = Init.start(ws.slug)
      {:ok, j2} = Init.start(ws.slug)

      {:ok, jobs} = Init.list_for_workspace(ws.slug)
      ids = Enum.map(jobs, & &1.id)
      assert j2.id in ids
      assert j1.id in ids
      # newest first — works with usec timestamps even within the same test
      j1_idx = Enum.find_index(ids, &(&1 == j1.id))
      j2_idx = Enum.find_index(ids, &(&1 == j2.id))
      # j2 was inserted after j1, so in desc order j2 should come first
      assert j2_idx <= j1_idx
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: step transitions happen in order, final status :succeeded
  # ---------------------------------------------------------------------------

  describe "step transitions" do
    test "succeeds when workspace has no setup_script" do
      ws = insert_workspace()
      {:ok, job} = Init.start(ws.slug)

      finished = wait_for_terminal(job.id)
      assert finished.status == "succeeded"
      assert finished.progress_pct == 100
      assert finished.current_step == "done"
    end

    test "runs setup_script and captures output" do
      ws = insert_workspace(%{setup_script: "echo hello_from_setup"})
      {:ok, job} = Init.start(ws.slug)

      finished = wait_for_terminal(job.id)
      assert finished.status == "succeeded"
      assert finished.output =~ "hello_from_setup"
    end

    test "fails when setup_script exits nonzero" do
      ws = insert_workspace(%{setup_script: "exit 1"})
      {:ok, job} = Init.start(ws.slug)

      finished = wait_for_terminal(job.id)
      assert finished.status == "failed"
      assert is_binary(finished.error)
    end
  end

  # ---------------------------------------------------------------------------
  # Cancel: kills task, subsequent steps do not advance
  # ---------------------------------------------------------------------------

  describe "cancel/1" do
    test "cancels a running job" do
      # Use a long-running setup_script so the task is still alive when we cancel
      ws = insert_workspace(%{setup_script: "sleep 30"})
      {:ok, job} = Init.start(ws.slug)

      # Give the task a moment to start
      Process.sleep(100)

      assert {:ok, cancelled_job} = Init.cancel(job.id)
      assert cancelled_job.status == "cancelled"

      # Re-fetch to confirm DB was updated
      {:ok, refetched} = Init.get(job.id)
      assert refetched.status == "cancelled"
    end

    test "returns :already_terminal when job is already done" do
      ws = insert_workspace()
      {:ok, job} = Init.start(ws.slug)

      finished = wait_for_terminal(job.id)
      assert finished.status == "succeeded"

      assert {:error, :already_terminal} = Init.cancel(job.id)
    end

    test "returns :not_found for unknown job" do
      assert {:error, :not_found} = Init.cancel(Ecto.UUID.generate())
    end
  end
end
