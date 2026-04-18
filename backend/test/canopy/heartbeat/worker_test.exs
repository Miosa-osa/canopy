defmodule Canopy.Heartbeat.WorkerTest do
  @moduledoc """
  Tests for Canopy.Heartbeat.Worker.

  Oban is configured with `testing: :inline` in the test environment, so
  `Oban.insert/1` executes the job synchronously and returns the result.
  We test perform/1 directly to avoid the inline-execution side-effect of
  immediately creating sessions via the real Sessions.create pipeline.
  """

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Heartbeat.Worker
  alias Oban.Job

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp job_for(slug, reason \\ "heartbeat") do
    %Job{args: %{"agent_slug" => slug, "wake_reason" => reason}}
  end

  # ---------------------------------------------------------------------------
  # perform/1 — happy path
  # ---------------------------------------------------------------------------

  describe "perform/1 with a valid hired agent" do
    test "creates a session and returns {:ok, session_id}" do
      agent = insert(:agent, slug: "worker-happy", hired: true, default_runtime: "claude-local")

      assert {:ok, session_id} = Worker.perform(job_for(agent.slug))
      assert is_binary(session_id)

      # Verify the session row was persisted
      assert {:ok, session} = Canopy.Sessions.get(session_id)
      assert session.agent_slug == "worker-happy"
      assert session.wake_reason == "heartbeat"
    end

    test "passes wake_reason from job args into the session" do
      agent = insert(:agent, slug: "worker-reason", hired: true, default_runtime: "claude-local")

      assert {:ok, session_id} = Worker.perform(job_for(agent.slug, "timer"))
      assert {:ok, session} = Canopy.Sessions.get(session_id)
      assert session.wake_reason == "timer"
    end

    test "defaults runtime to claude-local when agent has no default_runtime" do
      agent =
        insert(:agent,
          slug: "worker-no-runtime",
          hired: true,
          default_runtime: nil
        )

      assert {:ok, session_id} = Worker.perform(job_for(agent.slug))
      assert {:ok, session} = Canopy.Sessions.get(session_id)
      assert session.runtime_type == "claude-local"
    end
  end

  # ---------------------------------------------------------------------------
  # perform/1 — cancel paths
  # ---------------------------------------------------------------------------

  describe "perform/1 cancel semantics" do
    test "returns {:cancel, :agent_not_hired} for an unhired agent" do
      agent = insert(:agent, slug: "worker-unhired", hired: false)
      assert {:cancel, :agent_not_hired} = Worker.perform(job_for(agent.slug))
    end

    test "returns {:cancel, :agent_not_found} for a nonexistent agent" do
      assert {:cancel, :agent_not_found} = Worker.perform(job_for("ghost-slug-9999"))
    end
  end

  # ---------------------------------------------------------------------------
  # Self-rescheduling via schedule_next (indirect — through Oban.insert)
  # ---------------------------------------------------------------------------

  describe "self-rescheduling" do
    test "does not raise when agent has a valid heartbeat_cron" do
      agent =
        insert(:agent,
          slug: "worker-reschedule",
          hired: true,
          default_runtime: "claude-local",
          heartbeat_cron: "*/5 * * * *"
        )

      # With inline testing mode, perform/1 succeeds and schedule_next runs
      # synchronously inside the same process. We just verify no exception.
      assert {:ok, _session_id} = Worker.perform(job_for(agent.slug))
    end

    test "does not raise when agent has no heartbeat_cron" do
      agent =
        insert(:agent,
          slug: "worker-no-cron",
          hired: true,
          default_runtime: "claude-local",
          heartbeat_cron: nil
        )

      assert {:ok, _session_id} = Worker.perform(job_for(agent.slug))
    end
  end
end
