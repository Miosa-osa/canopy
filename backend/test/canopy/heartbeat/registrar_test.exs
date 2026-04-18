defmodule Canopy.Heartbeat.RegistrarTest do
  @moduledoc """
  Tests for Canopy.Heartbeat.Registrar.

  Uses Oban's inline testing mode — Oban.insert/1 is available but jobs
  are not executed. We verify that jobs are enqueued (or not) and that
  cancellation flips job state correctly.
  """

  use Canopy.DataCase, async: false

  import Canopy.Factory

  alias Canopy.Heartbeat.Registrar

  # ---------------------------------------------------------------------------
  # valid_cron?/1
  # ---------------------------------------------------------------------------

  describe "valid_cron?/1" do
    test "returns true for standard 5-field expression" do
      assert Registrar.valid_cron?("*/5 * * * *")
      assert Registrar.valid_cron?("0 * * * *")
      assert Registrar.valid_cron?("0 9 * * MON")
      assert Registrar.valid_cron?("* * * * *")
    end

    test "returns true for Oban-supported cron aliases" do
      assert Registrar.valid_cron?("@hourly")
      assert Registrar.valid_cron?("@daily")
      assert Registrar.valid_cron?("@weekly")
      assert Registrar.valid_cron?("@monthly")
      assert Registrar.valid_cron?("@reboot")
    end

    test "returns false for invalid expressions" do
      refute Registrar.valid_cron?("not-a-cron")
      refute Registrar.valid_cron?("99 99 99 99 99")
      refute Registrar.valid_cron?("")
      refute Registrar.valid_cron?("* * * *")
    end

    test "returns false for non-string input" do
      refute Registrar.valid_cron?(nil)
      refute Registrar.valid_cron?(42)
    end
  end

  # ---------------------------------------------------------------------------
  # register/1
  # ---------------------------------------------------------------------------

  describe "register/1" do
    test "returns :ok for agent with no heartbeat_cron" do
      agent = build(:agent, heartbeat_cron: nil)
      assert :ok = Registrar.register(agent)
    end

    test "returns :ok and enqueues a job for a valid cron expression" do
      agent =
        insert(:agent,
          slug: "reg-valid-cron",
          hired: true,
          heartbeat_cron: "*/15 * * * *"
        )

      assert :ok = Registrar.register(agent)

      # Verify an Oban job was inserted for this agent
      jobs = pending_jobs_for("reg-valid-cron")
      assert length(jobs) >= 1
    end

    test "returns {:error, {:invalid_cron_expression, expr}} for bad cron" do
      agent = build(:agent, slug: "reg-bad-cron", heartbeat_cron: "not-valid-cron")
      assert {:error, {:invalid_cron_expression, "not-valid-cron"}} = Registrar.register(agent)
    end

    test "job scheduled_at is in the future" do
      agent =
        insert(:agent,
          slug: "reg-future-at",
          hired: true,
          heartbeat_cron: "*/5 * * * *"
        )

      :ok = Registrar.register(agent)
      [job | _] = pending_jobs_for("reg-future-at")
      assert DateTime.compare(job.scheduled_at, DateTime.utc_now()) == :gt
    end
  end

  # ---------------------------------------------------------------------------
  # unregister/1
  # ---------------------------------------------------------------------------

  describe "unregister/1" do
    test "cancels pending heartbeat jobs for the agent" do
      agent =
        insert(:agent,
          slug: "unreg-target",
          hired: true,
          heartbeat_cron: "*/5 * * * *"
        )

      :ok = Registrar.register(agent)
      assert pending_jobs_for("unreg-target") != []

      :ok = Registrar.unregister("unreg-target")
      assert pending_jobs_for("unreg-target") == []
    end

    test "returns :ok even when no jobs exist" do
      assert :ok = Registrar.unregister("never-registered-slug")
    end
  end

  # ---------------------------------------------------------------------------
  # register_all_hired/0
  # ---------------------------------------------------------------------------

  describe "register_all_hired/0" do
    test "returns {:ok, 0} when no hired agents have a cron expression" do
      insert(:agent, slug: "rall-no-cron-1", hired: true, heartbeat_cron: nil)
      insert(:agent, slug: "rall-no-cron-2", hired: false, heartbeat_cron: "*/5 * * * *")

      assert {:ok, 0} = Registrar.register_all_hired()
    end

    test "returns {:ok, count} equal to number of hired agents with cron" do
      insert(:agent, slug: "rall-a", hired: true, heartbeat_cron: "*/5 * * * *")
      insert(:agent, slug: "rall-b", hired: true, heartbeat_cron: "0 * * * *")
      insert(:agent, slug: "rall-c", hired: true, heartbeat_cron: nil)
      insert(:agent, slug: "rall-d", hired: false, heartbeat_cron: "*/5 * * * *")

      assert {:ok, 2} = Registrar.register_all_hired()
    end

    test "enqueues jobs for each qualifying agent" do
      insert(:agent, slug: "rall-enq-x", hired: true, heartbeat_cron: "*/10 * * * *")
      insert(:agent, slug: "rall-enq-y", hired: true, heartbeat_cron: "*/20 * * * *")

      :ok =
        case Registrar.register_all_hired() do
          {:ok, _} -> :ok
        end

      assert pending_jobs_for("rall-enq-x") != []
      assert pending_jobs_for("rall-enq-y") != []
    end
  end

  # ---------------------------------------------------------------------------
  # schedule_next_job/2
  # ---------------------------------------------------------------------------

  describe "schedule_next_job/2" do
    test "inserts a job with scheduled_at in the future" do
      insert(:agent, slug: "snj-agent", hired: true, heartbeat_cron: "*/5 * * * *")
      assert {:ok, job} = Registrar.schedule_next_job("snj-agent", "*/5 * * * *")
      assert DateTime.compare(job.scheduled_at, DateTime.utc_now()) == :gt
    end

    test "returns {:error, :invalid_cron_expression} for bad expression" do
      assert {:error, :invalid_cron_expression} =
               Registrar.schedule_next_job("snj-bad", "not-valid")
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp pending_jobs_for(slug) do
    import Ecto.Query

    Canopy.Repo.all(
      from(j in Oban.Job,
        where:
          j.queue == "heartbeats" and
            j.state in ["scheduled", "available"] and
            fragment("?->>'agent_slug' = ?", j.args, ^slug)
      )
    )
  end
end
