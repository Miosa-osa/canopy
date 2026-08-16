defmodule Canopy.Sessions.PauseResumeStopTest do
  @moduledoc """
  Integration tests for Sessions.pause/1, Sessions.resume/1, and Sessions.stop/1.

  No pty is running in the test environment, so these tests verify only the DB-side
  effects (status transitions). The PtyBridge calls are no-ops when no bridge is
  registered (Registry lookup returns []).
  """

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Sessions

  defp running_session do
    insert(:session, status: "running")
  end

  # ---------------------------------------------------------------------------
  # pause/1
  # ---------------------------------------------------------------------------

  describe "pause/1" do
    test "transitions a running session to paused" do
      session = running_session()
      assert {:ok, paused} = Sessions.pause(session.id)
      assert paused.status == "paused"
    end

    test "returns {:error, :not_found} for unknown id" do
      assert {:error, :not_found} = Sessions.pause(Ecto.UUID.generate())
    end

    test "paused status is persisted in DB" do
      session = running_session()
      {:ok, _} = Sessions.pause(session.id)
      {:ok, reloaded} = Sessions.get(session.id)
      assert reloaded.status == "paused"
    end
  end

  # ---------------------------------------------------------------------------
  # resume/1
  # ---------------------------------------------------------------------------

  describe "resume/1" do
    test "transitions a paused session back to running" do
      session = insert(:session, status: "paused")
      assert {:ok, resumed} = Sessions.resume(session.id)
      assert resumed.status == "running"
    end

    test "returns {:error, :not_found} for unknown id" do
      assert {:error, :not_found} = Sessions.resume(Ecto.UUID.generate())
    end

    test "running status is persisted in DB after resume" do
      session = insert(:session, status: "paused")
      {:ok, _} = Sessions.resume(session.id)
      {:ok, reloaded} = Sessions.get(session.id)
      assert reloaded.status == "running"
    end
  end

  # ---------------------------------------------------------------------------
  # stop/1
  # ---------------------------------------------------------------------------

  describe "stop/1" do
    test "transitions a running session to cancelled" do
      session = running_session()
      assert {:ok, stopped} = Sessions.stop(session.id)
      assert stopped.status == "cancelled"
    end

    test "is a no-op on already-completed sessions" do
      session = insert(:session, status: "completed")
      assert {:ok, s} = Sessions.stop(session.id)
      assert s.status == "completed"
    end

    test "is a no-op on already-cancelled sessions" do
      session = insert(:session, status: "cancelled")
      assert {:ok, s} = Sessions.stop(session.id)
      assert s.status == "cancelled"
    end

    test "returns {:error, :not_found} for unknown id" do
      assert {:error, :not_found} = Sessions.stop(Ecto.UUID.generate())
    end
  end
end
