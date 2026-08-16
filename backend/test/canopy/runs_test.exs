defmodule Canopy.RunsTest do
  @moduledoc "Unit tests for the Runs context."

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Runs

  # ---------------------------------------------------------------------------
  # start/1
  # ---------------------------------------------------------------------------

  describe "start/1" do
    test "inserts a run with queued status and generated short_id" do
      {:ok, run} = Runs.start(%{workspace_slug: "my-ws"})

      assert run.status == "queued"
      assert String.starts_with?(run.short_id, "R-")
      assert String.length(run.short_id) == 10
      assert run.workspace_slug == "my-ws"
      assert run.usage_json == %{}
    end

    test "accepts optional fields" do
      {:ok, run} =
        Runs.start(%{
          workspace_slug: "ws",
          agent_slug: "backend-engineer",
          issue_short_id: "I-00000001",
          wake_reason: "scheduled"
        })

      assert run.agent_slug == "backend-engineer"
      assert run.issue_short_id == "I-00000001"
      assert run.wake_reason == "scheduled"
    end

    test "returns error on missing required fields" do
      assert {:error, changeset} = Runs.start(%{})
      assert changeset.errors[:workspace_slug]
    end
  end

  # ---------------------------------------------------------------------------
  # mark_running/2
  # ---------------------------------------------------------------------------

  describe "mark_running/2" do
    test "transitions queued → running and stamps process_pid" do
      run = insert(:run)
      {:ok, updated} = Runs.mark_running(run.id, 99_999)

      assert updated.status == "running"
      assert updated.process_pid == 99_999
    end

    test "accepts short_id" do
      run = insert(:run)
      {:ok, updated} = Runs.mark_running(run.short_id)

      assert updated.status == "running"
    end

    test "returns not_found for unknown id" do
      assert {:error, :not_found} = Runs.mark_running(Ecto.UUID.generate())
    end
  end

  # ---------------------------------------------------------------------------
  # mark_paused/1 and mark_resumed/1
  # ---------------------------------------------------------------------------

  describe "mark_paused/1" do
    test "transitions run to paused" do
      run = insert(:run, status: "running")
      {:ok, updated} = Runs.mark_paused(run.id)
      assert updated.status == "paused"
    end
  end

  describe "mark_resumed/1" do
    test "transitions paused run back to running" do
      run = insert(:run, status: "paused")
      {:ok, updated} = Runs.mark_resumed(run.id)
      assert updated.status == "running"
    end
  end

  # ---------------------------------------------------------------------------
  # mark_finished/4
  # ---------------------------------------------------------------------------

  describe "mark_finished/4" do
    test "marks run succeeded with usage" do
      run = insert(:run, status: "running")

      {:ok, updated} =
        Runs.mark_finished(run.id, "succeeded", %{"tokens_in" => 500, "cost_usd" => "0.01"})

      assert updated.status == "succeeded"
      assert updated.finished_at != nil
      assert updated.usage_json["tokens_in"] == 500
    end

    test "marks run failed with error reason" do
      run = insert(:run, status: "running")
      {:ok, updated} = Runs.mark_finished(run.id, "failed", %{}, "timeout after 60s")

      assert updated.status == "failed"
      assert updated.error_reason == "timeout after 60s"
    end

    test "merges usage_json with existing" do
      run = insert(:run, usage_json: %{"tokens_in" => 200})
      {:ok, updated} = Runs.mark_finished(run.id, "succeeded", %{"tokens_in" => 300})

      # merge: existing + new = 500
      assert updated.usage_json["tokens_in"] == 500
    end
  end

  # ---------------------------------------------------------------------------
  # get/1
  # ---------------------------------------------------------------------------

  describe "get/1" do
    test "returns run by uuid" do
      run = insert(:run)
      {:ok, found} = Runs.get(run.id)
      assert found.id == run.id
    end

    test "returns run by short_id" do
      run = insert(:run)
      {:ok, found} = Runs.get(run.short_id)
      assert found.id == run.id
    end

    test "returns not_found for unknown uuid" do
      assert {:error, :not_found} = Runs.get(Ecto.UUID.generate())
    end

    test "returns not_found for unknown short_id" do
      assert {:error, :not_found} = Runs.get("R-XXXXXXXX")
    end
  end

  # ---------------------------------------------------------------------------
  # list/1
  # ---------------------------------------------------------------------------

  describe "list/1" do
    test "returns all runs for a workspace" do
      ws = "list-test-ws-#{System.unique_integer()}"
      insert(:run, workspace_slug: ws)
      insert(:run, workspace_slug: ws)
      insert(:run, workspace_slug: "other-ws")

      runs = Runs.list(%{workspace_slug: ws})
      assert length(runs) == 2
    end

    test "filters by status" do
      ws = "status-filter-ws-#{System.unique_integer()}"
      insert(:run, workspace_slug: ws, status: "running")
      insert(:run, workspace_slug: ws, status: "queued")

      runs = Runs.list(%{workspace_slug: ws, status: "running"})
      assert Enum.all?(runs, &(&1.status == "running"))
    end

    test "filters by agent_slug" do
      ws = "agent-filter-ws-#{System.unique_integer()}"
      insert(:run, workspace_slug: ws, agent_slug: "target-agent")
      insert(:run, workspace_slug: ws, agent_slug: "other-agent")

      runs = Runs.list(%{workspace_slug: ws, agent_slug: "target-agent"})
      assert length(runs) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # append_usage/2
  # ---------------------------------------------------------------------------

  describe "append_usage/2" do
    test "merges numeric token deltas" do
      run = insert(:run, usage_json: %{"tokens_in" => 100, "tokens_out" => 50})
      {:ok, updated} = Runs.append_usage(run.id, %{"tokens_in" => 200, "tokens_out" => 75})

      assert updated.usage_json["tokens_in"] == 300
      assert updated.usage_json["tokens_out"] == 125
    end

    test "accumulates cost_usd as decimal string" do
      run = insert(:run, usage_json: %{"cost_usd" => "0.010"})
      {:ok, updated} = Runs.append_usage(run.id, %{"cost_usd" => "0.005"})

      {total, ""} = Decimal.parse(updated.usage_json["cost_usd"])
      assert Decimal.compare(total, Decimal.new("0.015")) == :eq
    end
  end
end
