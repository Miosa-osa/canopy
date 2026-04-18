defmodule Canopy.Sessions.ResumeTest do
  @moduledoc """
  Unit + integration tests for Canopy.Sessions.Resume.

  All tests run async against the SQL sandbox.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Sessions
  alias Canopy.Sessions.{Resume, Session}

  @cwd "/home/user/project"

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp insert_session(overrides \\ %{}) do
    base = %{
      runtime_type: "claude-local",
      cwd: @cwd,
      agent_slug: "senior-dev",
      workspace_slug: "my-workspace"
    }

    {:ok, session} = Sessions.create(Map.merge(base, overrides))
    session
  end

  defp complete_with_external_id(session, external_id) do
    # Finalize → completed, then write external_session_id
    {:ok, completed} = Sessions.finalize(session.id, %{})
    {:ok, updated} = Resume.persist(completed.id, external_id)
    updated
  end

  # ---------------------------------------------------------------------------
  # find_resumable/4
  # ---------------------------------------------------------------------------

  describe "find_resumable/4 — happy path" do
    test "returns external_session_id from most recent completed session" do
      session = insert_session()
      complete_with_external_id(session, "ext-session-abc")

      assert {:ok, "ext-session-abc"} =
               Resume.find_resumable("senior-dev", "my-workspace", @cwd)
    end

    test "returns most recent when multiple completed sessions exist" do
      session1 = insert_session()
      complete_with_external_id(session1, "ext-old-session")

      session2 = insert_session()
      complete_with_external_id(session2, "ext-new-session")

      assert {:ok, "ext-new-session"} =
               Resume.find_resumable("senior-dev", "my-workspace", @cwd)
    end

    test "matches cwd after Path.expand normalization" do
      session = insert_session(%{cwd: "/home/user/./project"})
      complete_with_external_id(session, "ext-session-norm")

      # Should match despite trailing dot
      assert {:ok, "ext-session-norm"} =
               Resume.find_resumable("senior-dev", "my-workspace", "/home/user/project")
    end

    test "nil workspace_slug uses default workspace key" do
      session = insert_session(%{workspace_slug: "default"})
      complete_with_external_id(session, "ext-session-default")

      assert {:ok, "ext-session-default"} =
               Resume.find_resumable("senior-dev", nil, @cwd)
    end

    test "prompt_bundle_key match succeeds when both sides equal" do
      bundle_key = String.duplicate("a", 64)
      session = insert_session(%{prompt_bundle_key: bundle_key})
      complete_with_external_id(session, "ext-session-keyed")

      assert {:ok, "ext-session-keyed"} =
               Resume.find_resumable("senior-dev", "my-workspace", @cwd, bundle_key)
    end

    test "prompt_bundle_key check skipped when stored key is absent" do
      # Session stored without a bundle_key — should still match any incoming key
      session = insert_session()
      complete_with_external_id(session, "ext-session-nokey")

      assert {:ok, "ext-session-nokey"} =
               Resume.find_resumable(
                 "senior-dev",
                 "my-workspace",
                 @cwd,
                 String.duplicate("b", 64)
               )
    end

    test "prompt_bundle_key check skipped when caller passes nil" do
      bundle_key = String.duplicate("c", 64)
      session = insert_session(%{prompt_bundle_key: bundle_key})
      complete_with_external_id(session, "ext-session-nilkey")

      # Caller passes nil → no key comparison, should find the session
      assert {:ok, "ext-session-nilkey"} =
               Resume.find_resumable("senior-dev", "my-workspace", @cwd, nil)
    end
  end

  describe "find_resumable/4 — no match cases" do
    test "returns error when no prior session exists" do
      assert {:error, :no_resume} =
               Resume.find_resumable("nonexistent-agent", "my-workspace", @cwd)
    end

    test "returns error when prior session is not completed" do
      # Session stays in pending status
      _session = insert_session()

      assert {:error, :no_resume} =
               Resume.find_resumable("senior-dev", "my-workspace", @cwd)
    end

    test "returns error when prior session has no external_session_id" do
      session = insert_session()
      # Finalize without setting external_session_id
      {:ok, _completed} = Sessions.finalize(session.id, %{})

      assert {:error, :no_resume} =
               Resume.find_resumable("senior-dev", "my-workspace", @cwd)
    end

    test "returns error when agent_slug differs" do
      session = insert_session()
      complete_with_external_id(session, "ext-session-abc")

      assert {:error, :no_resume} =
               Resume.find_resumable("other-agent", "my-workspace", @cwd)
    end

    test "returns error when workspace_slug differs" do
      session = insert_session()
      complete_with_external_id(session, "ext-session-abc")

      assert {:error, :no_resume} =
               Resume.find_resumable("senior-dev", "other-workspace", @cwd)
    end

    test "returns error when cwd differs" do
      session = insert_session()
      complete_with_external_id(session, "ext-session-abc")

      assert {:error, :no_resume} =
               Resume.find_resumable("senior-dev", "my-workspace", "/different/path")
    end

    test "returns error when prompt_bundle_key mismatches" do
      bundle_key = String.duplicate("a", 64)
      session = insert_session(%{prompt_bundle_key: bundle_key})
      complete_with_external_id(session, "ext-session-keyed")

      different_key = String.duplicate("b", 64)

      assert {:error, :no_resume} =
               Resume.find_resumable("senior-dev", "my-workspace", @cwd, different_key)
    end

    test "returns error when prior session status is cancelled" do
      session = insert_session()
      Sessions.update_status(session.id, "cancelled")

      assert {:error, :no_resume} =
               Resume.find_resumable("senior-dev", "my-workspace", @cwd)
    end

    test "returns error when prior session status is failed" do
      session = insert_session()
      Sessions.update_status(session.id, "failed")

      assert {:error, :no_resume} =
               Resume.find_resumable("senior-dev", "my-workspace", @cwd)
    end
  end

  # ---------------------------------------------------------------------------
  # persist/2
  # ---------------------------------------------------------------------------

  describe "persist/2" do
    test "writes external_session_id to the session row" do
      session = insert_session()

      assert {:ok, updated} = Resume.persist(session.id, "ext-abc-123")
      assert updated.external_session_id == "ext-abc-123"
    end

    test "overwrites an existing external_session_id" do
      session = insert_session()
      {:ok, _first} = Resume.persist(session.id, "ext-first")
      {:ok, updated} = Resume.persist(session.id, "ext-second")
      assert updated.external_session_id == "ext-second"
    end

    test "returns error for unknown session id" do
      assert {:error, :not_found} = Resume.persist(Ecto.UUID.generate(), "ext-abc")
    end

    test "returns error for empty external_session_id" do
      session = insert_session()
      assert {:error, :not_found} = Resume.persist(session.id, "")
    end

    test "returns error for nil external_session_id" do
      session = insert_session()
      assert {:error, :not_found} = Resume.persist(session.id, nil)
    end
  end

  # ---------------------------------------------------------------------------
  # expire/1
  # ---------------------------------------------------------------------------

  describe "expire/1" do
    test "clears external_session_id on matching session" do
      session = insert_session()
      {:ok, _} = Resume.persist(session.id, "ext-to-expire")

      assert :ok = Resume.expire("ext-to-expire")

      reloaded = Repo.get!(Session, session.id)
      assert reloaded.external_session_id == nil
    end

    test "returns :ok for unknown external_session_id (idempotent)" do
      assert :ok = Resume.expire("nonexistent-ext-id")
    end

    test "returns :ok for nil (guard clause)" do
      assert :ok = Resume.expire(nil)
    end

    test "clears all sessions sharing the same external_session_id" do
      session1 = insert_session()
      session2 = insert_session()

      # Both sessions somehow end up with the same external_session_id (edge case)
      Repo.update_all(
        from(s in Session, where: s.id in [^session1.id, ^session2.id]),
        set: [external_session_id: "shared-ext-id"]
      )

      assert :ok = Resume.expire("shared-ext-id")

      reloaded1 = Repo.get!(Session, session1.id)
      reloaded2 = Repo.get!(Session, session2.id)
      assert reloaded1.external_session_id == nil
      assert reloaded2.external_session_id == nil
    end
  end
end
